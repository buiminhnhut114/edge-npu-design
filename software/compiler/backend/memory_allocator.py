"""
EdgeNPU Compiler - Memory Allocator
Allocate buffers for weights and activations
"""

from typing import Dict, List, Tuple, Optional, Set
from dataclasses import dataclass, field
from enum import Enum, auto

from ..frontend.ir_builder import IRGraph, IRNode, IRTensor, IROpType


class MemoryRegion(Enum):
    """Memory regions on NPU"""
    WEIGHT_BUFFER = auto()
    ACTIVATION_BUFFER = auto()
    INSTRUCTION_BUFFER = auto()


@dataclass
class MemoryBlock:
    """A block of allocated memory"""
    name: str
    region: MemoryRegion
    offset: int
    size: int
    tensor_name: str
    
    @property
    def end(self) -> int:
        return self.offset + self.size


@dataclass
class MemoryPool:
    """Memory pool for a region"""
    region: MemoryRegion
    total_size: int
    alignment: int = 16
    
    blocks: List[MemoryBlock] = field(default_factory=list)
    free_offset: int = 0
    peak_usage: int = 0
    
    def allocate(self, name: str, size: int, tensor_name: str) -> MemoryBlock:
        """Allocate a block of memory"""
        # Align offset
        aligned_offset = (self.free_offset + self.alignment - 1) & ~(self.alignment - 1)
        
        if aligned_offset + size > self.total_size:
            raise MemoryError(f"Out of memory in {self.region.name}: "
                            f"need {size} bytes at offset {aligned_offset}, "
                            f"total {self.total_size}")
        
        block = MemoryBlock(
            name=name,
            region=self.region,
            offset=aligned_offset,
            size=size,
            tensor_name=tensor_name
        )
        
        self.blocks.append(block)
        self.free_offset = aligned_offset + size
        self.peak_usage = max(self.peak_usage, self.free_offset)
        
        return block
    
    def free(self, block: MemoryBlock):
        """Free a memory block (for reuse)"""
        if block in self.blocks:
            self.blocks.remove(block)
    
    def reset(self):
        """Reset pool for reuse"""
        self.blocks = []
        self.free_offset = 0
    
    def get_usage(self) -> Tuple[int, int]:
        """Get (current_usage, peak_usage)"""
        return self.free_offset, self.peak_usage


class MemoryAllocator:
    """
    Memory allocator for NPU
    Manages weight and activation buffers
    """
    
    def __init__(self, weight_buf_kb: int = 256, act_buf_kb: int = 256,
                 inst_buf_entries: int = 1024):
        self.weight_pool = MemoryPool(
            region=MemoryRegion.WEIGHT_BUFFER,
            total_size=weight_buf_kb * 1024
        )
        self.activation_pool = MemoryPool(
            region=MemoryRegion.ACTIVATION_BUFFER,
            total_size=act_buf_kb * 1024
        )
        self.inst_buf_size = inst_buf_entries * 8  # 64-bit instructions
        
        # Allocation maps
        self.weight_offsets: Dict[str, int] = {}
        self.activation_offsets: Dict[str, int] = {}
        
        # Liveness analysis
        self.tensor_liveness: Dict[str, Tuple[int, int]] = {}  # tensor -> (first_use, last_use)
    
    def analyze_liveness(self, graph: IRGraph):
        """Analyze tensor liveness for memory reuse"""
        sorted_nodes = graph.topological_sort()
        
        for i, node in enumerate(sorted_nodes):
            node.schedule_order = i
            
            # Mark input tensors as live
            for inp in node.inputs:
                if inp not in self.tensor_liveness:
                    self.tensor_liveness[inp] = (i, i)
                else:
                    first, last = self.tensor_liveness[inp]
                    self.tensor_liveness[inp] = (first, i)
            
            # Mark output tensors
            for out in node.outputs:
                if out not in self.tensor_liveness:
                    self.tensor_liveness[out] = (i, i)
    
    def allocate_weights(self, graph: IRGraph):
        """Allocate memory for all weights"""
        for name, tensor in graph.tensors.items():
            if tensor.data is not None:  # It's a weight/constant
                size = tensor.nbytes
                block = self.weight_pool.allocate(
                    name=f"weight_{name}",
                    size=size,
                    tensor_name=name
                )
                self.weight_offsets[name] = block.offset
    
    def allocate_activations(self, graph: IRGraph):
        """Allocate memory for activations with reuse"""
        self.analyze_liveness(graph)
        
        sorted_nodes = graph.topological_sort()
        active_tensors: Dict[str, MemoryBlock] = {}
        
        for i, node in enumerate(sorted_nodes):
            # Free tensors that are no longer needed
            tensors_to_free = []
            for tensor_name, block in active_tensors.items():
                if tensor_name in self.tensor_liveness:
                    _, last_use = self.tensor_liveness[tensor_name]
                    if last_use < i:
                        tensors_to_free.append(tensor_name)
            
            for tensor_name in tensors_to_free:
                block = active_tensors.pop(tensor_name)
                self.activation_pool.free(block)
            
            # Allocate output tensors
            for out in node.outputs:
                tensor = graph.get_tensor(out)
                if tensor and tensor.data is None:  # Activation tensor
                    size = tensor.nbytes
                    
                    # Try to reuse freed memory
                    block = self.activation_pool.allocate(
                        name=f"act_{out}",
                        size=size,
                        tensor_name=out
                    )
                    
                    active_tensors[out] = block
                    self.activation_offsets[out] = block.offset
    
    def allocate(self, graph: IRGraph):
        """Allocate all memory"""
        self.allocate_weights(graph)
        self.allocate_activations(graph)
    
    def get_weight_offset(self, tensor_name: str) -> int:
        """Get weight buffer offset for tensor"""
        return self.weight_offsets.get(tensor_name, 0)
    
    def get_activation_offset(self, tensor_name: str) -> int:
        """Get activation buffer offset for tensor"""
        return self.activation_offsets.get(tensor_name, 0)
    
    def get_memory_usage(self) -> Dict[str, Tuple[int, int]]:
        """Get memory usage for each region"""
        return {
            'weights': self.weight_pool.get_usage(),
            'activations': self.activation_pool.get_usage(),
        }
    
    def print_allocation(self):
        """Print memory allocation info"""
        print("\nMemory Allocation:")
        
        print("\n  Weight Buffer:")
        for block in self.weight_pool.blocks:
            print(f"    {block.tensor_name}: offset={block.offset}, size={block.size}")
        
        print("\n  Activation Buffer:")
        for block in self.activation_pool.blocks:
            print(f"    {block.tensor_name}: offset={block.offset}, size={block.size}")
        
        usage = self.get_memory_usage()
        print(f"\n  Weight usage: {usage['weights'][1]} / {self.weight_pool.total_size} bytes")
        print(f"  Activation usage: {usage['activations'][1]} / {self.activation_pool.total_size} bytes")
    
    def get_allocation_map(self) -> Dict:
        """Get complete allocation map"""
        return {
            'weight_offsets': self.weight_offsets,
            'activation_offsets': self.activation_offsets,
            'weight_usage': self.weight_pool.get_usage(),
            'activation_usage': self.activation_pool.get_usage(),
        }
