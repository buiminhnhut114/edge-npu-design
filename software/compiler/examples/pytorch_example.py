#!/usr/bin/env python3
"""
Example: Compile a simple PyTorch model directly

This example shows how to:
1. Define a PyTorch model
2. Parse it to IR
3. Optimize and quantize
4. Generate NPU binary
"""

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

import numpy as np

# Check if PyTorch is available
try:
    import torch
    import torch.nn as nn
    HAS_TORCH = True
except ImportError:
    HAS_TORCH = False
    print("PyTorch not installed. Run: pip install torch")


def create_simple_cnn():
    """Create a simple CNN model"""
    return nn.Sequential(
        # Conv block 1
        nn.Conv2d(3, 32, kernel_size=3, padding=1),
        nn.BatchNorm2d(32),
        nn.ReLU(),
        nn.MaxPool2d(2, 2),
        
        # Conv block 2
        nn.Conv2d(32, 64, kernel_size=3, padding=1),
        nn.BatchNorm2d(64),
        nn.ReLU(),
        nn.MaxPool2d(2, 2),
        
        # Conv block 3
        nn.Conv2d(64, 128, kernel_size=3, padding=1),
        nn.BatchNorm2d(128),
        nn.ReLU(),
        nn.AdaptiveAvgPool2d((1, 1)),
        
        # Classifier
        nn.Flatten(),
        nn.Linear(128, 10),
    )


def main():
    if not HAS_TORCH:
        return 1
    
    from compiler.frontend import parse_pytorch_module
    from compiler.optimizer import optimize_graph
    from compiler.optimizer.quantizer import quantize_graph
    from compiler.backend import compile_graph
    
    print("=" * 60)
    print("EdgeNPU PyTorch Compilation Example")
    print("=" * 60)
    
    # Create model
    print("\n[1] Creating PyTorch model...")
    model = create_simple_cnn()
    model.eval()
    
    # Print model structure
    print(f"Model: {model}")
    
    # Count parameters
    total_params = sum(p.numel() for p in model.parameters())
    print(f"Total parameters: {total_params:,}")
    
    # Test forward pass
    print("\n[2] Testing forward pass...")
    dummy_input = torch.randn(1, 3, 32, 32)
    with torch.no_grad():
        output = model(dummy_input)
    print(f"Input shape: {dummy_input.shape}")
    print(f"Output shape: {output.shape}")
    
    # Parse to IR
    print("\n[3] Parsing to IR...")
    ir_graph = parse_pytorch_module(
        model, 
        input_shape=(1, 3, 32, 32),
        model_name="simple_cnn"
    )
    print(f"IR nodes: {len(ir_graph.nodes)}")
    print(f"IR tensors: {len(ir_graph.tensors)}")
    
    # Optimize
    print("\n[4] Optimizing graph...")
    ir_graph = optimize_graph(ir_graph, opt_level=2, verbose=True)
    
    # Quantize
    print("\n[5] Quantizing to INT8...")
    ir_graph = quantize_graph(ir_graph)
    
    # Compile
    print("\n[6] Generating NPU binary...")
    compiled = compile_graph(ir_graph, verbose=True)
    
    # Save
    output_path = "simple_cnn.npu"
    compiled.save(output_path)
    
    # Also save C header
    header_path = "simple_cnn_model.h"
    compiled.save_c_header(header_path)
    
    print("\n" + "=" * 60)
    print("Compilation Complete!")
    print("=" * 60)
    print(f"Binary output: {output_path}")
    print(f"C header: {header_path}")
    print(f"Instructions: {compiled.num_instructions}")
    print(f"Weight size: {compiled.weight_size} bytes")
    print(f"Estimated cycles: {compiled.estimated_cycles}")
    
    return 0


if __name__ == '__main__':
    sys.exit(main())
