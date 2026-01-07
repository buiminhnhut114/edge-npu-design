#!/usr/bin/env python3
"""
EdgeNPU Model Compiler
Converts ONNX/TFLite models to NPU instructions and quantized weights
"""

import numpy as np
import struct
from dataclasses import dataclass
from enum import IntEnum
from typing import List, Dict, Tuple, Optional
import json

# =============================================================================
# NPU Instruction Set (matching npu_pkg.sv)
# =============================================================================

class OpCode(IntEnum):
    NOP     = 0x0
    CONV    = 0x1
    FC      = 0x2
    POOL    = 0x3
    ACT     = 0x4
    LOAD    = 0x5
    STORE   = 0x6
    SYNC    = 0x7
    ADD     = 0x8
    MUL     = 0x9
    CONCAT  = 0xA
    SPLIT   = 0xB

class ActivationType(IntEnum):
    NONE    = 0
    RELU    = 1
    RELU6   = 2
    SIGMOID = 3
    TANH    = 4
    SWISH   = 5
    GELU    = 6

class PoolingType(IntEnum):
    MAX     = 0
    AVG     = 1
    GLOBAL  = 2

# =============================================================================
# Data Structures
# =============================================================================

@dataclass
class NPUInstruction:
    """64-bit NPU instruction format"""
    opcode: OpCode
    flags: int = 0
    dst_addr: int = 0
    src0_addr: int = 0
    src1_addr: int = 0
    immediate: int = 0
    
    def to_bytes(self) -> bytes:
        """Pack instruction to 64-bit binary"""
        # [63:60] opcode, [59:56] flags, [55:48] dst, [47:40] src0, [39:32] src1, [31:0] imm
        word = (self.opcode & 0xF) << 60
        word |= (self.flags & 0xF) << 56
        word |= (self.dst_addr & 0xFF) << 48
        word |= (self.src0_addr & 0xFF) << 40
        word |= (self.src1_addr & 0xFF) << 32
        word |= (self.immediate & 0xFFFFFFFF)
        return struct.pack('<Q', word)
    
    def __repr__(self):
        return f"NPUInst({OpCode(self.opcode).name}, dst={self.dst_addr}, src0={self.src0_addr}, imm=0x{self.immediate:08X})"

@dataclass
class ConvParams:
    """Convolution parameters packed into immediate field"""
    kernel_size: int
    stride: int
    padding: int
    activation: ActivationType = ActivationType.NONE
    
    def to_immediate(self) -> int:
        """Pack to 32-bit immediate"""
        # [31:28] kernel, [27:24] stride, [23:20] padding, [19:17] activation
        imm = (self.kernel_size & 0xF) << 28
        imm |= (self.stride & 0xF) << 24
        imm |= (self.padding & 0xF) << 20
        imm |= (self.activation & 0x7) << 17
        return imm

@dataclass 
class QuantParams:
    """Quantization parameters"""
    scale: float
    zero_point: int
    
    def quantize(self, data: np.ndarray) -> np.ndarray:
        """Quantize float32 to int8"""
        return np.clip(np.round(data / self.scale + self.zero_point), -128, 127).astype(np.int8)
    
    def dequantize(self, data: np.ndarray) -> np.ndarray:
        """Dequantize int8 to float32"""
        return (data.astype(np.float32) - self.zero_point) * self.scale

# =============================================================================
# Layer Compilers
# =============================================================================

class LayerCompiler:
    """Base class for layer compilers"""
    
    def __init__(self, weight_offset: int = 0, act_offset: int = 0):
        self.weight_offset = weight_offset
        self.act_offset = act_offset
        
    def compile(self, layer_info: dict) -> Tuple[List[NPUInstruction], bytes, bytes]:
        """Returns (instructions, weights, bias)"""
        raise NotImplementedError

class ConvCompiler(LayerCompiler):
    """Compile Conv2D layer"""
    
    def compile(self, layer_info: dict) -> Tuple[List[NPUInstruction], bytes, bytes]:
        instructions = []
        
        # Extract parameters
        kernel_h = layer_info.get('kernel_h', 3)
        kernel_w = layer_info.get('kernel_w', 3)
        stride = layer_info.get('stride', 1)
        padding = layer_info.get('padding', 1)
        activation = ActivationType[layer_info.get('activation', 'NONE').upper()]
        
        in_channels = layer_info['in_channels']
        out_channels = layer_info['out_channels']
        
        # Get weights and quantize
        weights = np.array(layer_info['weights'], dtype=np.float32)
        bias = np.array(layer_info.get('bias', np.zeros(out_channels)), dtype=np.float32)
        
        # Calculate quantization params
        w_scale = np.max(np.abs(weights)) / 127.0 if np.max(np.abs(weights)) > 0 else 1.0
        w_qparams = QuantParams(scale=w_scale, zero_point=0)
        weights_q = w_qparams.quantize(weights)
        
        b_scale = np.max(np.abs(bias)) / 127.0 if np.max(np.abs(bias)) > 0 else 1.0
        b_qparams = QuantParams(scale=b_scale, zero_point=0)
        bias_q = b_qparams.quantize(bias)
        
        # Generate instructions
        conv_params = ConvParams(
            kernel_size=kernel_h,
            stride=stride,
            padding=padding,
            activation=activation
        )
        
        # 1. Load weights
        instructions.append(NPUInstruction(
            opcode=OpCode.LOAD,
            dst_addr=0,  # Weight buffer
            immediate=self.weight_offset
        ))
        
        # 2. Execute convolution
        instructions.append(NPUInstruction(
            opcode=OpCode.CONV,
            dst_addr=self.act_offset,
            src0_addr=0,  # Input activation
            src1_addr=0,  # Weight buffer
            immediate=conv_params.to_immediate()
        ))
        
        # 3. Sync
        instructions.append(NPUInstruction(opcode=OpCode.SYNC))
        
        return instructions, weights_q.tobytes(), bias_q.tobytes()

class PoolCompiler(LayerCompiler):
    """Compile Pooling layer"""
    
    def compile(self, layer_info: dict) -> Tuple[List[NPUInstruction], bytes, bytes]:
        instructions = []
        
        pool_type = PoolingType[layer_info.get('pool_type', 'MAX').upper()]
        kernel_size = layer_info.get('kernel_size', 2)
        stride = layer_info.get('stride', 2)
        
        # Pack immediate: [31:28] kernel, [27:24] stride, [1:0] pool_type
        immediate = (kernel_size & 0xF) << 28
        immediate |= (stride & 0xF) << 24
        immediate |= (pool_type & 0x3)
        
        instructions.append(NPUInstruction(
            opcode=OpCode.POOL,
            dst_addr=self.act_offset,
            src0_addr=self.act_offset,
            immediate=immediate
        ))
        
        return instructions, b'', b''

class FCCompiler(LayerCompiler):
    """Compile Fully Connected layer"""
    
    def compile(self, layer_info: dict) -> Tuple[List[NPUInstruction], bytes, bytes]:
        instructions = []
        
        in_features = layer_info['in_features']
        out_features = layer_info['out_features']
        activation = ActivationType[layer_info.get('activation', 'NONE').upper()]
        
        weights = np.array(layer_info['weights'], dtype=np.float32)
        bias = np.array(layer_info.get('bias', np.zeros(out_features)), dtype=np.float32)
        
        # Quantize
        w_scale = np.max(np.abs(weights)) / 127.0 if np.max(np.abs(weights)) > 0 else 1.0
        weights_q = np.clip(np.round(weights / w_scale), -128, 127).astype(np.int8)
        
        b_scale = np.max(np.abs(bias)) / 127.0 if np.max(np.abs(bias)) > 0 else 1.0
        bias_q = np.clip(np.round(bias / b_scale), -128, 127).astype(np.int8)
        
        # Generate instructions
        immediate = (activation & 0x7) << 17
        
        instructions.append(NPUInstruction(
            opcode=OpCode.LOAD,
            dst_addr=0,
            immediate=self.weight_offset
        ))
        
        instructions.append(NPUInstruction(
            opcode=OpCode.FC,
            dst_addr=self.act_offset,
            src0_addr=0,
            immediate=immediate
        ))
        
        return instructions, weights_q.tobytes(), bias_q.tobytes()

class ActivationCompiler(LayerCompiler):
    """Compile Activation layer"""
    
    def compile(self, layer_info: dict) -> Tuple[List[NPUInstruction], bytes, bytes]:
        act_type = ActivationType[layer_info.get('activation', 'RELU').upper()]
        
        instructions = [NPUInstruction(
            opcode=OpCode.ACT,
            dst_addr=self.act_offset,
            src0_addr=self.act_offset,
            immediate=act_type
        )]
        
        return instructions, b'', b''


# =============================================================================
# Main Compiler Class
# =============================================================================

class NPUCompiler:
    """
    Main compiler class for EdgeNPU
    Converts neural network models to NPU binary format
    """
    
    def __init__(self):
        self.instructions: List[NPUInstruction] = []
        self.weights_data = bytearray()
        self.bias_data = bytearray()
        self.weight_offset = 0
        self.act_offset = 0
        
        # Layer compilers
        self.compilers = {
            'conv': ConvCompiler,
            'conv2d': ConvCompiler,
            'pool': PoolCompiler,
            'maxpool': PoolCompiler,
            'avgpool': PoolCompiler,
            'fc': FCCompiler,
            'linear': FCCompiler,
            'dense': FCCompiler,
            'relu': ActivationCompiler,
            'activation': ActivationCompiler,
        }
        
    def compile_layer(self, layer_type: str, layer_info: dict):
        """Compile a single layer"""
        layer_type = layer_type.lower()
        
        if layer_type not in self.compilers:
            print(f"Warning: Unknown layer type '{layer_type}', skipping")
            return
            
        compiler_class = self.compilers[layer_type]
        compiler = compiler_class(self.weight_offset, self.act_offset)
        
        insts, weights, bias = compiler.compile(layer_info)
        
        self.instructions.extend(insts)
        
        if weights:
            self.weights_data.extend(weights)
            self.weight_offset += len(weights)
            
        if bias:
            self.bias_data.extend(bias)
    
    def compile_model(self, model_def: dict) -> dict:
        """
        Compile entire model from definition
        
        Args:
            model_def: Dictionary with model definition
            
        Returns:
            Compiled model dictionary
        """
        self.instructions = []
        self.weights_data = bytearray()
        self.bias_data = bytearray()
        self.weight_offset = 0
        self.act_offset = 0
        
        model_name = model_def.get('name', 'unnamed_model')
        layers = model_def.get('layers', [])
        
        print(f"Compiling model: {model_name}")
        print(f"Number of layers: {len(layers)}")
        
        for i, layer in enumerate(layers):
            layer_type = layer.get('type', 'unknown')
            print(f"  Compiling layer {i}: {layer_type}")
            self.compile_layer(layer_type, layer)
        
        # Add final sync
        self.instructions.append(NPUInstruction(opcode=OpCode.SYNC))
        
        # Generate binary
        inst_binary = b''.join(inst.to_bytes() for inst in self.instructions)
        
        compiled = {
            'name': model_name,
            'version': '1.0',
            'num_instructions': len(self.instructions),
            'instructions_size': len(inst_binary),
            'weights_size': len(self.weights_data),
            'bias_size': len(self.bias_data),
            'instructions': inst_binary,
            'weights': bytes(self.weights_data),
            'bias': bytes(self.bias_data),
        }
        
        print(f"Compilation complete:")
        print(f"  Instructions: {len(self.instructions)}")
        print(f"  Weights: {len(self.weights_data)} bytes")
        print(f"  Bias: {len(self.bias_data)} bytes")
        
        return compiled
    
    def save_binary(self, compiled: dict, output_path: str):
        """Save compiled model to binary file"""
        with open(output_path, 'wb') as f:
            # Header (64 bytes)
            header = struct.pack('<4s', b'ENPU')  # Magic
            header += struct.pack('<I', 0x0100)   # Version 1.0
            header += struct.pack('<I', compiled['num_instructions'])
            header += struct.pack('<I', compiled['instructions_size'])
            header += struct.pack('<I', compiled['weights_size'])
            header += struct.pack('<I', compiled['bias_size'])
            header += b'\x00' * (64 - len(header))  # Padding
            
            f.write(header)
            f.write(compiled['instructions'])
            f.write(compiled['weights'])
            f.write(compiled['bias'])
            
        print(f"Saved to: {output_path}")
    
    def save_c_header(self, compiled: dict, output_path: str):
        """Generate C header file with model data"""
        with open(output_path, 'w') as f:
            f.write(f"// Auto-generated by EdgeNPU Compiler\n")
            f.write(f"// Model: {compiled['name']}\n\n")
            f.write(f"#ifndef NPU_MODEL_H\n")
            f.write(f"#define NPU_MODEL_H\n\n")
            f.write(f"#include <stdint.h>\n\n")
            
            # Instructions
            f.write(f"#define NPU_NUM_INSTRUCTIONS {compiled['num_instructions']}\n")
            f.write(f"static const uint64_t npu_instructions[NPU_NUM_INSTRUCTIONS] = {{\n")
            inst_data = compiled['instructions']
            for i in range(0, len(inst_data), 8):
                val = struct.unpack('<Q', inst_data[i:i+8])[0]
                f.write(f"    0x{val:016X}ULL,\n")
            f.write(f"}};\n\n")
            
            # Weights
            f.write(f"#define NPU_WEIGHTS_SIZE {compiled['weights_size']}\n")
            f.write(f"static const int8_t npu_weights[NPU_WEIGHTS_SIZE] = {{\n")
            weights = compiled['weights']
            for i in range(0, len(weights), 16):
                chunk = weights[i:i+16]
                f.write("    " + ", ".join(f"{b:4d}" for b in chunk) + ",\n")
            f.write(f"}};\n\n")
            
            # Bias
            f.write(f"#define NPU_BIAS_SIZE {compiled['bias_size']}\n")
            f.write(f"static const int8_t npu_bias[NPU_BIAS_SIZE] = {{\n")
            bias = compiled['bias']
            for i in range(0, len(bias), 16):
                chunk = bias[i:i+16]
                f.write("    " + ", ".join(f"{b:4d}" for b in chunk) + ",\n")
            f.write(f"}};\n\n")
            
            f.write(f"#endif // NPU_MODEL_H\n")
            
        print(f"Generated C header: {output_path}")


# =============================================================================
# ONNX Model Loader
# =============================================================================

def load_onnx_model(onnx_path: str) -> dict:
    """Load ONNX model and convert to compiler format"""
    try:
        import onnx
        from onnx import numpy_helper
    except ImportError:
        print("Error: onnx package not installed. Run: pip install onnx")
        return None
    
    model = onnx.load(onnx_path)
    graph = model.graph
    
    # Extract weights
    weights_dict = {}
    for init in graph.initializer:
        weights_dict[init.name] = numpy_helper.to_array(init)
    
    layers = []
    
    for node in graph.node:
        layer = {'type': node.op_type.lower()}
        
        if node.op_type == 'Conv':
            # Get attributes
            for attr in node.attribute:
                if attr.name == 'kernel_shape':
                    layer['kernel_h'] = attr.ints[0]
                    layer['kernel_w'] = attr.ints[1]
                elif attr.name == 'strides':
                    layer['stride'] = attr.ints[0]
                elif attr.name == 'pads':
                    layer['padding'] = attr.ints[0]
            
            # Get weights
            if len(node.input) > 1 and node.input[1] in weights_dict:
                w = weights_dict[node.input[1]]
                layer['out_channels'] = w.shape[0]
                layer['in_channels'] = w.shape[1]
                layer['weights'] = w.flatten().tolist()
                
            if len(node.input) > 2 and node.input[2] in weights_dict:
                layer['bias'] = weights_dict[node.input[2]].tolist()
                
        elif node.op_type in ['Relu', 'Sigmoid', 'Tanh']:
            layer['type'] = 'activation'
            layer['activation'] = node.op_type
            
        elif node.op_type == 'MaxPool':
            layer['type'] = 'pool'
            layer['pool_type'] = 'MAX'
            for attr in node.attribute:
                if attr.name == 'kernel_shape':
                    layer['kernel_size'] = attr.ints[0]
                elif attr.name == 'strides':
                    layer['stride'] = attr.ints[0]
                    
        elif node.op_type == 'Gemm':  # Fully connected
            layer['type'] = 'fc'
            if len(node.input) > 1 and node.input[1] in weights_dict:
                w = weights_dict[node.input[1]]
                layer['out_features'] = w.shape[0]
                layer['in_features'] = w.shape[1]
                layer['weights'] = w.flatten().tolist()
            if len(node.input) > 2 and node.input[2] in weights_dict:
                layer['bias'] = weights_dict[node.input[2]].tolist()
        
        layers.append(layer)
    
    return {
        'name': graph.name or 'onnx_model',
        'layers': layers
    }


# =============================================================================
# PyTorch Model Loader
# =============================================================================

def load_pytorch_model(model_path: str, input_shape: tuple = (1, 3, 224, 224)) -> dict:
    """
    Load PyTorch model and convert to compiler format
    Uses the new frontend parser for full support
    """
    try:
        from .frontend import parse_model
        from .optimizer import optimize_graph
        from .optimizer.quantizer import quantize_graph
        from .backend import compile_graph
        
        # Parse using new frontend
        ir_graph = parse_model(model_path, input_shape)
        
        # Optimize
        ir_graph = optimize_graph(ir_graph, opt_level=2)
        
        # Quantize
        ir_graph = quantize_graph(ir_graph)
        
        # Compile
        compiled = compile_graph(ir_graph)
        
        return compiled
        
    except ImportError as e:
        print(f"Error loading PyTorch model: {e}")
        print("Make sure PyTorch is installed: pip install torch")
        return None


# =============================================================================
# CLI Interface
# =============================================================================

def main():
    import argparse
    
    parser = argparse.ArgumentParser(
        description='EdgeNPU Model Compiler',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Compile ONNX model
  python npu_compiler.py model.onnx -o model.npu
  
  # Compile PyTorch TorchScript model
  python npu_compiler.py model.pt -o model.npu --input-shape 1,3,224,224
  
  # Compile with C header output
  python npu_compiler.py model.onnx -o model.npu --header model.h
  
  # Compile JSON model definition
  python npu_compiler.py model.json -o model.npu

Supported formats:
  .onnx   - ONNX models
  .pt     - PyTorch TorchScript models
  .pth    - PyTorch state dict (requires --model-class)
  .json   - JSON model definition
        """
    )
    parser.add_argument('input', help='Input model file')
    parser.add_argument('-o', '--output', default='model.npu', help='Output binary file')
    parser.add_argument('--header', help='Generate C header file')
    parser.add_argument('--input-shape', default='1,3,224,224',
                        help='Input shape for PyTorch models (N,C,H,W)')
    parser.add_argument('--model-class', help='Model class for PyTorch state_dict')
    parser.add_argument('--opt-level', type=int, default=2, choices=[0,1,2,3],
                        help='Optimization level (default: 2)')
    parser.add_argument('-v', '--verbose', action='store_true', help='Verbose output')
    
    args = parser.parse_args()
    
    input_file = args.input
    
    # Parse input shape
    input_shape = tuple(int(x) for x in args.input_shape.split(','))
    
    print(f"EdgeNPU Compiler v1.0")
    print(f"Input: {input_file}")
    
    # Determine format and compile
    if input_file.endswith('.onnx'):
        print("Format: ONNX")
        model_def = load_onnx_model(input_file)
        if model_def is None:
            return 1
        compiler = NPUCompiler()
        compiled = compiler.compile_model(model_def)
        compiler.save_binary(compiled, args.output)
        if args.header:
            compiler.save_c_header(compiled, args.header)
            
    elif input_file.endswith('.pt') or input_file.endswith('.pth'):
        print(f"Format: PyTorch")
        print(f"Input shape: {input_shape}")
        
        # Use new frontend pipeline
        try:
            from .frontend import parse_model
            from .optimizer import optimize_graph
            from .optimizer.quantizer import quantize_graph
            from .backend import compile_graph
            
            ir_graph = parse_model(input_file, input_shape)
            if args.verbose:
                print(ir_graph.summary())
            
            ir_graph = optimize_graph(ir_graph, opt_level=args.opt_level, 
                                      verbose=args.verbose)
            ir_graph = quantize_graph(ir_graph)
            compiled = compile_graph(ir_graph, verbose=args.verbose)
            
            compiled.save(args.output)
            if args.header:
                compiled.save_c_header(args.header)
                
            print(f"\nCompilation complete!")
            print(f"  Output: {args.output}")
            print(f"  Instructions: {compiled.num_instructions}")
            print(f"  Weights: {compiled.weight_size} bytes")
            
        except ImportError as e:
            print(f"Error: {e}")
            print("Install PyTorch: pip install torch")
            return 1
            
    elif input_file.endswith('.json'):
        print("Format: JSON")
        with open(input_file) as f:
            model_def = json.load(f)
        compiler = NPUCompiler()
        compiled = compiler.compile_model(model_def)
        compiler.save_binary(compiled, args.output)
        if args.header:
            compiler.save_c_header(compiled, args.header)
    else:
        print(f"Error: Unsupported file format: {input_file}")
        print("Supported: .onnx, .pt, .pth, .json")
        return 1
    
    print(f"\nSaved: {args.output}")
    if args.header:
        print(f"Header: {args.header}")
    
    return 0


if __name__ == '__main__':
    exit(main())
