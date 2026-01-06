"""
EdgeNPU Compiler - Code Generator
Generate NPU binary from optimized IR
"""

from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass
import struct
import numpy as np

from ..frontend.ir_builder import IRGraph, IRNode, IRTensor, IROpType

from .instruction_emitter import InstructionEmitter
from .memory_allocator import MemoryAllocator
from .scheduler import Scheduler, Schedule


# Model binary format magic number
MODEL_MAGIC = 0x4E505545  # "NPUE" in little endian
MODEL_VERSION = 0x0100


@dataclass
class CompiledModel:
    """Compiled model ready for NPU execution"""
    name: str
    version: int
    
    # Binary data
    instructions: bytes
    weights: bytes
    bias: bytes
    
    # Metadata
    num_instructions: int
    num_layers: int
    input_size: int
    output_size: int
    weight_size: int
    
    # Memory map
    weight_offsets: Dict[str, int]
    activation_offsets: Dict[str, int]
    
    # Schedule info
    estimated_cycles: int
    
    def get_header(self) -> bytes:
        """Generate binary header"""
        header = struct.pack('<I', MODEL_MAGIC)
        header += struct.pack('<H', self.version)
        header += struct.pack('<H', self.num_layers)
        header += struct.pack('<I', self.weight_size)
        header += struct.pack('<I', self.num_instructions)
        header += struct.pack('<I', self.input_size)
        header += struct.pack('<I', self.output_size)
        header += struct.pack('<I', len(self.instructions) + len(self.weights))
        header += struct.pack('<I', 0)  # Checksum placeholder
        
        # Pad to 64 bytes
        header += b'\x00' * (64 - len(header))
        return header
    
    def to_binary(self) -> bytes:
        """Generate complete binary"""
        header = self.get_header()
        return header + self.instructions + self.weights + self.bias
    
    def save(self, path: str):
        """Save to file"""
        with open(path, 'wb') as f:
            f.write(self.to_binary())
    
    def save_c_header(self, path: str):
        """Generate C header file"""
        with open(path, 'w') as f:
            f.write(f"// Auto-generated NPU model: {self.name}\n")
            f.write(f"// Instructions: {self.num_instructions}\n")
            f.write(f"// Weights: {self.weight_size} bytes\n\n")
            
            f.write("#ifndef NPU_MODEL_H\n")
            f.write("#define NPU_MODEL_H\n\n")
            f.write("#include <stdint.h>\n\n")
            
            # Instructions
            f.write(f"#define NPU_NUM_INSTRUCTIONS {self.num_instructions}\n")
            f.write("static const uint64_t npu_instructions[] = {\n")
            for i in range(0, len(self.instructions), 8):
                val = struct.unpack('<Q', self.instructions[i:i+8])[0]
                f.write(f"    0x{val:016X}ULL,\n")
            f.write("};\n\n")
            
            # Weights
            f.write(f"#define NPU_WEIGHTS_SIZE {len(self.weights)}\n")
            f.write("static const int8_t npu_weights[] = {\n")
            for i in range(0, len(self.weights), 16):
                chunk = self.weights[i:i+16]
                vals = ", ".join(f"{b:4d}" for b in chunk)
                f.write(f"    {vals},\n")
            f.write("};\n\n")
            
            f.write("#endif // NPU_MODEL_H\n")


class CodeGenerator:
    """
    Main code generator
    Converts optimized IR to NPU binary
    """
    
    def __init__(self, pe_rows: int = 16, pe_cols: int = 16,
                 weight_buf_kb: int = 256, act_buf_kb: int = 256):
        self.pe_rows = pe_rows
        self.pe_cols = pe_cols
        
        self.emitter = InstructionEmitter()
        self.allocator = MemoryAllocator(weight_buf_kb, act_buf_kb)
        self.scheduler = Scheduler(pe_rows, pe_cols)
    
    def generate(self, graph: IRGraph, verbose: bool = False) -> CompiledModel:
        """
        Generate NPU binary from IR graph
        
        Args:
            graph: Optimized IR graph
            verbose: Print progress
            
        Returns:
            Compiled model
        """
        if verbose:
            print("Code Generation:")
        
        # Step 1: Memory allocation
        if verbose:
            print("  Allocating memory...")
        self.allocator.allocate(graph)
        
        # Step 2: Schedule operations
        if verbose:
            print("  Scheduling operations...")
        schedule = self.scheduler.schedule(graph)
        
        # Step 3: Emit instructions
        if verbose:
            print("  Emitting instructions...")
        self._emit_instructions(graph, schedule)
        
        # Step 4: Pack weights
        if verbose:
            print("  Packing weights...")
        weights_data, bias_data = self._pack_weights(graph)
        
        # Step 5: Create compiled model
        instructions = self.emitter.get_binary()
        
        # Calculate input/output sizes
        input_size = sum(graph.get_tensor(inp).nbytes 
                        for inp in graph.inputs 
                        if graph.get_tensor(inp))
        output_size = sum(graph.get_tensor(out).nbytes 
                         for out in graph.outputs 
                         if graph.get_tensor(out))
        
        model = CompiledModel(
            name=graph.name,
            version=MODEL_VERSION,
            instructions=instructions,
            weights=weights_data,
            bias=bias_data,
            num_instructions=self.emitter.get_instruction_count(),
            num_layers=len([n for n in graph.nodes 
                           if n.op_type in [IROpType.CONV2D, IROpType.FULLY_CONNECTED]]),
            input_size=input_size,
            output_size=output_size,
            weight_size=len(weights_data),
            weight_offsets=self.allocator.weight_offsets,
            activation_offsets=self.allocator.activation_offsets,
            estimated_cycles=schedule.total_cycles
        )
        
        if verbose:
            print(f"  Generated {model.num_instructions} instructions")
            print(f"  Weight size: {model.weight_size} bytes")
            print(f"  Estimated cycles: {model.estimated_cycles}")
        
        return model
    
    def _emit_instructions(self, graph: IRGraph, schedule: Schedule):
        """Emit instructions for scheduled operations"""
        # Set memory map in emitter
        self.emitter.set_memory_map(
            self.allocator.weight_offsets,
            self.allocator.activation_offsets
        )
        
        # Get nodes in scheduled order
        ordered_nodes = schedule.get_node_order()
        
        # Emit prologue
        self.emitter.emit_sync()
        
        # Emit instructions for each node
        for node in ordered_nodes:
            self.emitter.emit_node(graph, node)
        
        # Emit epilogue
        self.emitter.emit_sync()
        self.emitter.emit_halt()
    
    def _pack_weights(self, graph: IRGraph) -> Tuple[bytes, bytes]:
        """Pack weights into binary format"""
        weights_data = bytearray()
        bias_data = bytearray()
        
        # Sort by offset for sequential packing
        sorted_weights = sorted(
            self.allocator.weight_offsets.items(),
            key=lambda x: x[1]
        )
        
        for tensor_name, offset in sorted_weights:
            tensor = graph.get_tensor(tensor_name)
            if tensor and tensor.data is not None:
                # Pad to offset
                while len(weights_data) < offset:
                    weights_data.append(0)
                
                # Add weight data
                if tensor.is_quantized:
                    weights_data.extend(tensor.data.tobytes())
                else:
                    # Quantize on the fly
                    quantized = tensor.quantize()
                    weights_data.extend(quantized.data.tobytes())
        
        return bytes(weights_data), bytes(bias_data)
    
    def get_stats(self) -> Dict:
        """Get code generation statistics"""
        return {
            'num_instructions': self.emitter.get_instruction_count(),
            'memory_usage': self.allocator.get_memory_usage(),
        }


def compile_graph(graph: IRGraph, 
                  pe_rows: int = 16, pe_cols: int = 16,
                  verbose: bool = False) -> CompiledModel:
    """
    Convenience function to compile a graph
    
    Args:
        graph: IR graph to compile
        pe_rows: PE array rows
        pe_cols: PE array columns
        verbose: Print progress
        
    Returns:
        Compiled model
    """
    generator = CodeGenerator(pe_rows=pe_rows, pe_cols=pe_cols)
    return generator.generate(graph, verbose=verbose)
