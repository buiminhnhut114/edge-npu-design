"""
EdgeNPU Compiler - Scheduler
Schedule operations for optimal execution
"""

from typing import List, Dict, Set, Optional, Tuple
from dataclasses import dataclass, field
from enum import Enum, auto

import sys
sys.path.append('..')
from frontend.ir_builder import IRGraph, IRNode, IROpType


class ResourceType(Enum):
    """NPU resource types"""
    PE_ARRAY = auto()
    DMA_ENGINE = auto()
    ACTIVATION_UNIT = auto()
    POOLING_UNIT = auto()


@dataclass
class ScheduleSlot:
    """A scheduled operation"""
    node: IRNode
    start_cycle: int
    end_cycle: int
    resources: List[ResourceType]
    
    @property
    def duration(self) -> int:
        return self.end_cycle - self.start_cycle


@dataclass
class Schedule:
    """Complete execution schedule"""
    slots: List[ScheduleSlot] = field(default_factory=list)
    total_cycles: int = 0
    
    def add_slot(self, slot: ScheduleSlot):
        self.slots.append(slot)
        self.total_cycles = max(self.total_cycles, slot.end_cycle)
    
    def get_node_order(self) -> List[IRNode]:
        """Get nodes in scheduled order"""
        sorted_slots = sorted(self.slots, key=lambda s: s.start_cycle)
        return [s.node for s in sorted_slots]


class CostModel:
    """Cost model for estimating operation latency"""
    
    def __init__(self, pe_rows: int = 16, pe_cols: int = 16, 
                 clock_mhz: int = 500):
        self.pe_rows = pe_rows
        self.pe_cols = pe_cols
        self.clock_mhz = clock_mhz
        
        # Latency estimates (in cycles)
        self.dma_latency_per_byte = 0.1
        self.pe_compute_latency = 1
        self.activation_latency = 4
        self.pooling_latency = 8
    
    def estimate_conv_cycles(self, out_ch: int, in_ch: int, 
                             out_h: int, out_w: int,
                             kernel_h: int, kernel_w: int) -> int:
        """Estimate convolution cycles"""
        # MACs = out_ch * in_ch * out_h * out_w * kernel_h * kernel_w
        macs = out_ch * in_ch * out_h * out_w * kernel_h * kernel_w
        
        # PE array can do pe_rows * pe_cols MACs per cycle
        macs_per_cycle = self.pe_rows * self.pe_cols
        
        # Account for tiling overhead
        oc_tiles = (out_ch + self.pe_cols - 1) // self.pe_cols
        ic_tiles = (in_ch + self.pe_rows - 1) // self.pe_rows
        
        compute_cycles = (macs + macs_per_cycle - 1) // macs_per_cycle
        overhead = oc_tiles * ic_tiles * 10  # Tile switching overhead
        
        return compute_cycles + overhead
    
    def estimate_fc_cycles(self, in_features: int, out_features: int) -> int:
        """Estimate FC cycles"""
        macs = in_features * out_features
        macs_per_cycle = self.pe_rows * self.pe_cols
        return (macs + macs_per_cycle - 1) // macs_per_cycle + 10
    
    def estimate_pool_cycles(self, h: int, w: int, 
                             kernel_h: int, kernel_w: int) -> int:
        """Estimate pooling cycles"""
        out_h = h // kernel_h
        out_w = w // kernel_w
        return out_h * out_w * self.pooling_latency
    
    def estimate_activation_cycles(self, size: int) -> int:
        """Estimate activation cycles"""
        return (size + 15) // 16 * self.activation_latency
    
    def estimate_dma_cycles(self, bytes: int) -> int:
        """Estimate DMA transfer cycles"""
        return int(bytes * self.dma_latency_per_byte) + 50  # Base latency
    
    def estimate_node_cycles(self, graph: IRGraph, node: IRNode) -> int:
        """Estimate cycles for a node"""
        if node.op_type == IROpType.CONV2D:
            weight = graph.get_tensor(node.inputs[1])
            output = graph.get_tensor(node.outputs[0])
            if weight and output:
                out_ch, in_ch, kh, kw = weight.shape
                _, _, out_h, out_w = output.shape
                return self.estimate_conv_cycles(out_ch, in_ch, out_h, out_w, kh, kw)
        
        elif node.op_type == IROpType.FULLY_CONNECTED:
            weight = graph.get_tensor(node.inputs[1])
            if weight:
                out_f, in_f = weight.shape[:2]
                return self.estimate_fc_cycles(in_f, out_f)
        
        elif node.op_type in [IROpType.MAX_POOL2D, IROpType.AVG_POOL2D]:
            input_tensor = graph.get_tensor(node.inputs[0])
            kernel = node.get_attr('kernel_size', (2, 2))
            if input_tensor:
                _, _, h, w = input_tensor.shape
                return self.estimate_pool_cycles(h, w, kernel[0], kernel[1])
        
        elif node.op_type in [IROpType.RELU, IROpType.RELU6, IROpType.SIGMOID]:
            input_tensor = graph.get_tensor(node.inputs[0])
            if input_tensor:
                return self.estimate_activation_cycles(input_tensor.size)
        
        # Default estimate
        return 100


class Scheduler:
    """
    Operation scheduler for NPU
    Schedules operations to maximize throughput
    """
    
    def __init__(self, pe_rows: int = 16, pe_cols: int = 16):
        self.pe_rows = pe_rows
        self.pe_cols = pe_cols
        self.cost_model = CostModel(pe_rows, pe_cols)
        
        # Resource availability (cycle when resource becomes free)
        self.resource_free: Dict[ResourceType, int] = {
            ResourceType.PE_ARRAY: 0,
            ResourceType.DMA_ENGINE: 0,
            ResourceType.ACTIVATION_UNIT: 0,
            ResourceType.POOLING_UNIT: 0,
        }
    
    def get_required_resources(self, node: IRNode) -> List[ResourceType]:
        """Get resources required by node"""
        if node.op_type in [IROpType.CONV2D, IROpType.DEPTHWISE_CONV2D, 
                            IROpType.FULLY_CONNECTED, IROpType.MATMUL]:
            return [ResourceType.PE_ARRAY]
        
        elif node.op_type in [IROpType.RELU, IROpType.RELU6, IROpType.SIGMOID,
                              IROpType.TANH, IROpType.SOFTMAX]:
            return [ResourceType.ACTIVATION_UNIT]
        
        elif node.op_type in [IROpType.MAX_POOL2D, IROpType.AVG_POOL2D,
                              IROpType.GLOBAL_AVG_POOL]:
            return [ResourceType.POOLING_UNIT]
        
        return []
    
    def schedule(self, graph: IRGraph) -> Schedule:
        """
        Schedule graph operations
        Uses list scheduling with resource constraints
        """
        schedule = Schedule()
        
        # Reset resource availability
        for r in self.resource_free:
            self.resource_free[r] = 0
        
        # Get topologically sorted nodes
        sorted_nodes = graph.topological_sort()
        
        # Track when each tensor is ready
        tensor_ready: Dict[str, int] = {}
        
        # Initialize graph inputs as ready at cycle 0
        for inp in graph.inputs:
            tensor_ready[inp] = 0
        
        # Initialize constants as ready
        for name, tensor in graph.tensors.items():
            if tensor.data is not None:
                tensor_ready[name] = 0
        
        # Schedule each node
        for node in sorted_nodes:
            # Find earliest start time based on data dependencies
            earliest_start = 0
            for inp in node.inputs:
                if inp in tensor_ready:
                    earliest_start = max(earliest_start, tensor_ready[inp])
            
            # Find earliest start based on resource availability
            resources = self.get_required_resources(node)
            for r in resources:
                earliest_start = max(earliest_start, self.resource_free[r])
            
            # Estimate duration
            duration = self.cost_model.estimate_node_cycles(graph, node)
            
            # Create schedule slot
            slot = ScheduleSlot(
                node=node,
                start_cycle=earliest_start,
                end_cycle=earliest_start + duration,
                resources=resources
            )
            schedule.add_slot(slot)
            
            # Update resource availability
            for r in resources:
                self.resource_free[r] = slot.end_cycle
            
            # Update tensor ready times
            for out in node.outputs:
                tensor_ready[out] = slot.end_cycle
        
        return schedule
    
    def print_schedule(self, schedule: Schedule):
        """Print schedule information"""
        print("\nExecution Schedule:")
        print(f"  Total cycles: {schedule.total_cycles}")
        print(f"  Estimated time @ 500MHz: {schedule.total_cycles / 500e6 * 1000:.3f} ms")
        print("\n  Operations:")
        
        for slot in sorted(schedule.slots, key=lambda s: s.start_cycle):
            resources = ", ".join(r.name for r in slot.resources)
            print(f"    [{slot.start_cycle:6d} - {slot.end_cycle:6d}] "
                  f"{slot.node.name} ({slot.node.op_type.name}) "
                  f"[{resources}]")
    
    def get_schedule_stats(self, schedule: Schedule) -> Dict:
        """Get schedule statistics"""
        # Calculate resource utilization
        pe_busy = sum(s.duration for s in schedule.slots 
                      if ResourceType.PE_ARRAY in s.resources)
        
        return {
            'total_cycles': schedule.total_cycles,
            'num_operations': len(schedule.slots),
            'pe_utilization': pe_busy / schedule.total_cycles if schedule.total_cycles > 0 else 0,
            'estimated_time_ms': schedule.total_cycles / 500e6 * 1000,
        }
