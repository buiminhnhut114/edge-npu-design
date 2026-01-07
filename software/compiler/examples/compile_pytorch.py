#!/usr/bin/env python3
"""
Example: Compile PyTorch model to NPU binary

Usage:
    # From TorchScript file
    python compile_pytorch.py model.pt -o model.npu
    
    # From state dict (requires model class)
    python compile_pytorch.py model.pth --model-class torchvision.models.resnet18
    
    # With custom input shape
    python compile_pytorch.py model.pt --input-shape 1,3,224,224
"""

import argparse
import sys
from pathlib import Path

# Add parent to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from compiler.frontend import parse_model, parse_pytorch_module
from compiler.optimizer import optimize_graph, QuantizationConfig, quantize_graph
from compiler.backend import compile_graph


def main():
    parser = argparse.ArgumentParser(description='Compile PyTorch model to NPU')
    parser.add_argument('model', help='Path to PyTorch model (.pt or .pth)')
    parser.add_argument('-o', '--output', default='model.npu', help='Output file')
    parser.add_argument('--input-shape', default='1,3,224,224', 
                        help='Input shape (N,C,H,W)')
    parser.add_argument('--model-class', help='Model class for state_dict loading')
    parser.add_argument('--header', help='Generate C header file')
    parser.add_argument('--opt-level', type=int, default=2, choices=[0,1,2,3],
                        help='Optimization level')
    parser.add_argument('--no-quantize', action='store_true', 
                        help='Skip quantization')
    parser.add_argument('-v', '--verbose', action='store_true')
    
    args = parser.parse_args()
    
    # Parse input shape
    input_shape = tuple(int(x) for x in args.input_shape.split(','))
    
    # Load model class if specified
    model_class = None
    if args.model_class:
        parts = args.model_class.rsplit('.', 1)
        if len(parts) == 2:
            import importlib
            module = importlib.import_module(parts[0])
            model_class = getattr(module, parts[1])
    
    print(f"Compiling: {args.model}")
    print(f"Input shape: {input_shape}")
    
    # Step 1: Parse model
    print("\n[1/4] Parsing model...")
    ir_graph = parse_model(args.model, input_shape, model_class)
    
    if args.verbose:
        print(ir_graph.summary())
    
    # Step 2: Optimize
    print("[2/4] Optimizing graph...")
    ir_graph = optimize_graph(ir_graph, opt_level=args.opt_level, verbose=args.verbose)
    
    # Step 3: Quantize
    if not args.no_quantize:
        print("[3/4] Quantizing to INT8...")
        ir_graph = quantize_graph(ir_graph)
    else:
        print("[3/4] Skipping quantization")
    
    # Step 4: Generate code
    print("[4/4] Generating NPU binary...")
    compiled = compile_graph(ir_graph, verbose=args.verbose)
    
    # Save outputs
    compiled.save(args.output)
    print(f"\nSaved: {args.output}")
    print(f"  Instructions: {compiled.num_instructions}")
    print(f"  Weights: {compiled.weight_size} bytes")
    print(f"  Estimated cycles: {compiled.estimated_cycles}")
    
    if args.header:
        compiled.save_c_header(args.header)
        print(f"  C header: {args.header}")
    
    return 0


if __name__ == '__main__':
    sys.exit(main())
