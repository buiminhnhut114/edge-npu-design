"""
EdgeNPU Compiler - Instruction Emitter
Emit NPU instructions from IR
"""

from typing import List, Dict, Optional, Tuple
from dataclasses import dataclass
from enum import IntEnum
import struct

from ..frontend.ir_builder import IRGraph, IRNode, IROpType


class NPUOpCode(IntEnum):
    """NPU instruction opcodes (matching firmware)"""
    # Control
    NOP = 0x00
    HALT = 0x01
    SYNC = 0x02
    WAIT_DMA = 0x03
    WAIT_PE = 0x04
    IRQ = 0x05
    LOOP_START = 0x06
    LOOP_END = 0x07
    
    # DMA
    DMA_LOAD_W = 0x10
    DMA_LOAD_A = 0x11
    DMA_STORE = 0x12
    
    # Compute
    CONV = 0x20
    DWCONV = 0x21
    GEMM = 0x22
    FC = 0x23
    CLEAR_ACC = 0x26
    LOAD_WEIGHT = 0x27
    COMPUTE = 0x28
    DRAIN = 0x29
    
    # Activation
    RELU = 0x40
    RELU6 = 0x41
    SIGMOID = 0x42
    TANH = 0x43
    
    # Pooling
    MAXPOOL = 0x50
    AVGPOOL = 0x51
    GLOBAL_AVGPOOL = 0x52
    
    # Element-wise
    ADD = 0x60
    SUB = 0x61
    MUL = 0x62
    
    # Normalization
    BATCHNORM = 0x70
    SOFTMAX = 0x72
    
    # Quantization
    QUANTIZE = 0x80
    REQUANTIZE = 0x82
    BIAS_ADD = 0x84


class NPUFlags(IntEnum):
    """Instruction flags"""
    LAST = 0x01
    IRQ = 0x02
    CHAIN = 0x04
    ASYNC = 0x08
    RELU = 0x10
    BIAS = 0x20
    QUANT = 0x40
    ACCUM = 0x80


@dataclass
class NPUInstruction:
    """64-bit NPU instruction"""
    opcode: NPUOpCode
    flags: int = 0
    operands: int = 0
    
    def encode(self) -> bytes:
        """Encode to 64-bit binary"""
        # [63:56] opcode, [55:48] flags, [47:0] operands
        word = (int(self.opcode) & 0xFF) << 56
        word |= (self.flags & 0xFF) << 48
        word |= (self.operands & 0xFFFFFFFFFFFF)
        return struct.pack('<Q', word)
    
    def __repr__(self):
        return f"NPUInst({self.opcode.name}, flags=0x{self.flags:02X}, ops=0x{self.operands:012X})"


class InstructionEmitter:
    """
    Emit NPU instructions from IR nodes
    """
    
    def __init__(self):
        self.instructions: List[NPUInstruction] = []
        self.labels: Dict[str, int] = {}
        
        # Memory allocation info (set by MemoryAllocator)
        self.weight_offsets: Dict[str, int] = {}
        self.activation_offsets: Dict[str, int] = {}
    
    def set_memory_map(self, weight_offsets: Dict[str, int], 
                       activation_offsets: Dict[str, int]):
        """Set memory allocation info"""
        self.weight_offsets = weight_offsets
        self.activation_offsets = activation_offsets
    
    def emit(self, inst: NPUInstruction):
        """Emit single instruction"""
        self.instructions.append(inst)
    
    def emit_nop(self):
        """Emit NOP"""
        self.emit(NPUInstruction(NPUOpCode.NOP))
    
    def emit_halt(self):
        """Emit HALT"""
        self.emit(NPUInstruction(NPUOpCode.HALT, flags=NPUFlags.LAST))
    
    def emit_sync(self):
        """Emit SYNC"""
        self.emit(NPUInstruction(NPUOpCode.SYNC))
    
    def emit_wait_dma(self):
        """Emit WAIT_DMA"""
        self.emit(NPUInstruction(NPUOpCode.WAIT_DMA))
    
    def emit_dma_load_weight(self, src_addr: int, dst_addr: int, length: int):
        """Emit DMA load for weights"""
        operands = (src_addr & 0xFFFFFF) | ((dst_addr & 0xFFFF) << 24) | ((length & 0xFF) << 40)
        self.emit(NPUInstruction(NPUOpCode.DMA_LOAD_W, operands=operands))
    
    def emit_dma_load_activation(self, src_addr: int, dst_addr: int, length: int):
        """Emit DMA load for activations"""
        operands = (src_addr & 0xFFFFFF) | ((dst_addr & 0xFFFF) << 24) | ((length & 0xFF) << 40)
        self.emit(NPUInstruction(NPUOpCode.DMA_LOAD_A, operands=operands))
    
    def emit_dma_store(self, src_addr: int, dst_addr: int, length: int):
        """Emit DMA store"""
        operands = (src_addr & 0xFFFFFF) | ((dst_addr & 0xFFFF) << 24) | ((length & 0xFF) << 40)
        self.emit(NPUInstruction(NPUOpCode.DMA_STORE, operands=operands))
    
    def emit_clear_acc(self):
        """Emit clear accumulators"""
        self.emit(NPUInstruction(NPUOpCode.CLEAR_ACC))
    
    def emit_load_weight(self, addr: int, count: int):
        """Emit load weights to PE array"""
        operands = (addr & 0xFFFFFF) | ((count & 0xFFFF) << 24)
        self.emit(NPUInstruction(NPUOpCode.LOAD_WEIGHT, operands=operands))
    
    def emit_compute(self, flags: int = 0):
        """Emit compute instruction"""
        self.emit(NPUInstruction(NPUOpCode.COMPUTE, flags=flags))
    
    def emit_drain(self, addr: int):
        """Emit drain results"""
        self.emit(NPUInstruction(NPUOpCode.DRAIN, operands=addr))
    
    def emit_conv(self, kernel_h: int, kernel_w: int, stride_h: int, stride_w: int,
                  pad_h: int, pad_w: int, flags: int = 0):
        """Emit convolution config"""
        operands = (kernel_h & 0xF) | ((kernel_w & 0xF) << 4)
        operands |= ((stride_h & 0xF) << 8) | ((stride_w & 0xF) << 12)
        operands |= ((pad_h & 0xF) << 16) | ((pad_w & 0xF) << 20)
        self.emit(NPUInstruction(NPUOpCode.CONV, flags=flags, operands=operands))
    
    def emit_fc(self, in_features: int, out_features: int, flags: int = 0):
        """Emit fully connected config"""
        operands = (in_features & 0xFFFF) | ((out_features & 0xFFFF) << 16)
        self.emit(NPUInstruction(NPUOpCode.FC, flags=flags, operands=operands))
    
    def emit_relu(self):
        """Emit ReLU activation"""
        self.emit(NPUInstruction(NPUOpCode.RELU))
    
    def emit_relu6(self):
        """Emit ReLU6 activation"""
        self.emit(NPUInstruction(NPUOpCode.RELU6))
    
    def emit_maxpool(self, kernel_h: int, kernel_w: int, stride_h: int, stride_w: int):
        """Emit max pooling"""
        operands = (kernel_h & 0xF) | ((kernel_w & 0xF) << 4)
        operands |= ((stride_h & 0xF) << 8) | ((stride_w & 0xF) << 12)
        self.emit(NPUInstruction(NPUOpCode.MAXPOOL, operands=operands))
    
    def emit_avgpool(self, kernel_h: int, kernel_w: int, stride_h: int, stride_w: int):
        """Emit average pooling"""
        operands = (kernel_h & 0xF) | ((kernel_w & 0xF) << 4)
        operands |= ((stride_h & 0xF) << 8) | ((stride_w & 0xF) << 12)
        self.emit(NPUInstruction(NPUOpCode.AVGPOOL, operands=operands))
    
    def emit_global_avgpool(self):
        """Emit global average pooling"""
        self.emit(NPUInstruction(NPUOpCode.GLOBAL_AVGPOOL))
    
    def emit_add(self):
        """Emit element-wise add"""
        self.emit(NPUInstruction(NPUOpCode.ADD))
    
    def emit_mul(self):
        """Emit element-wise multiply"""
        self.emit(NPUInstruction(NPUOpCode.MUL))
    
    def emit_softmax(self, axis: int = -1):
        """Emit softmax"""
        self.emit(NPUInstruction(NPUOpCode.SOFTMAX, operands=axis & 0xFF))
    
    def emit_loop_start(self, count: int):
        """Emit loop start"""
        self.emit(NPUInstruction(NPUOpCode.LOOP_START, operands=count))
    
    def emit_loop_end(self, target: int):
        """Emit loop end"""
        self.emit(NPUInstruction(NPUOpCode.LOOP_END, operands=target))
    
    def emit_node(self, graph: IRGraph, node: IRNode):
        """Emit instructions for IR node"""
        if node.op_type == IROpType.CONV2D:
            self._emit_conv2d(graph, node)
        elif node.op_type == IROpType.DEPTHWISE_CONV2D:
            self._emit_dwconv(graph, node)
        elif node.op_type == IROpType.FULLY_CONNECTED:
            self._emit_fc(graph, node)
        elif node.op_type == IROpType.RELU:
            self.emit_relu()
        elif node.op_type == IROpType.RELU6:
            self.emit_relu6()
        elif node.op_type == IROpType.MAX_POOL2D:
            self._emit_maxpool(graph, node)
        elif node.op_type == IROpType.AVG_POOL2D:
            self._emit_avgpool(graph, node)
        elif node.op_type == IROpType.GLOBAL_AVG_POOL:
            self.emit_global_avgpool()
        elif node.op_type == IROpType.ADD:
            self.emit_add()
        elif node.op_type == IROpType.MUL:
            self.emit_mul()
        elif node.op_type == IROpType.SOFTMAX:
            axis = node.get_attr('axis', -1)
            self.emit_softmax(axis)
    
    def _emit_conv2d(self, graph: IRGraph, node: IRNode):
        """Emit Conv2D instructions"""
        kernel_size = node.get_attr('kernel_size', (3, 3))
        stride = node.get_attr('stride', (1, 1))
        padding = node.get_attr('padding', (0, 0))
        activation = node.get_attr('activation')
        
        # Get memory offsets
        weight_name = node.inputs[1]
        weight_offset = self.weight_offsets.get(weight_name, 0)
        
        # Load weights
        weight_tensor = graph.get_tensor(weight_name)
        if weight_tensor:
            weight_size = weight_tensor.nbytes
            self.emit_dma_load_weight(weight_offset, 0, weight_size // 16)
            self.emit_wait_dma()
        
        # Configure and execute conv
        flags = 0
        if activation == 'relu':
            flags |= NPUFlags.RELU
        
        self.emit_clear_acc()
        self.emit_conv(kernel_size[0], kernel_size[1], 
                       stride[0], stride[1],
                       padding[0], padding[1], flags)
        self.emit_compute(flags)
        self.emit_sync()
    
    def _emit_dwconv(self, graph: IRGraph, node: IRNode):
        """Emit depthwise conv instructions"""
        # Similar to conv2d but with DWCONV opcode
        kernel_size = node.get_attr('kernel_size', (3, 3))
        stride = node.get_attr('stride', (1, 1))
        padding = node.get_attr('padding', (0, 0))
        
        operands = (kernel_size[0] & 0xF) | ((kernel_size[1] & 0xF) << 4)
        operands |= ((stride[0] & 0xF) << 8) | ((stride[1] & 0xF) << 12)
        operands |= ((padding[0] & 0xF) << 16) | ((padding[1] & 0xF) << 20)
        
        self.emit(NPUInstruction(NPUOpCode.DWCONV, operands=operands))
        self.emit_sync()
    
    def _emit_fc(self, graph: IRGraph, node: IRNode):
        """Emit FC instructions"""
        weight_name = node.inputs[1]
        weight_tensor = graph.get_tensor(weight_name)
        
        if weight_tensor:
            out_features, in_features = weight_tensor.shape[:2]
        else:
            in_features, out_features = 1, 1
        
        activation = node.get_attr('activation')
        flags = NPUFlags.RELU if activation == 'relu' else 0
        
        self.emit_clear_acc()
        self.emit_fc(in_features, out_features, flags)
        self.emit_compute(flags)
        self.emit_sync()
    
    def _emit_maxpool(self, graph: IRGraph, node: IRNode):
        """Emit maxpool instructions"""
        kernel_size = node.get_attr('kernel_size', (2, 2))
        stride = node.get_attr('stride', (2, 2))
        self.emit_maxpool(kernel_size[0], kernel_size[1], stride[0], stride[1])
    
    def _emit_avgpool(self, graph: IRGraph, node: IRNode):
        """Emit avgpool instructions"""
        kernel_size = node.get_attr('kernel_size', (2, 2))
        stride = node.get_attr('stride', (2, 2))
        self.emit_avgpool(kernel_size[0], kernel_size[1], stride[0], stride[1])
    
    def get_binary(self) -> bytes:
        """Get binary instruction stream"""
        return b''.join(inst.encode() for inst in self.instructions)
    
    def get_instruction_count(self) -> int:
        """Get number of instructions"""
        return len(self.instructions)
    
    def dump(self) -> str:
        """Dump instructions as text"""
        lines = []
        for i, inst in enumerate(self.instructions):
            lines.append(f"{i:4d}: {inst}")
        return "\n".join(lines)
