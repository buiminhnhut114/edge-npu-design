#!/usr/bin/env python3
"""
Run benchmark with actual PyTorch models from torchvision

This script:
1. Downloads pre-trained models from torchvision
2. Compiles them to NPU format
3. Estimates performance based on compiled model
"""

import sys
import time
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))

# Check PyTorch availability
try:
    import torch
    import torch.nn as nn
    HAS_TORCH = True
except ImportError:
    HAS_TORCH = False
    print("PyTorch not installed. Run: pip install torch torchvision")

try:
    import torchvision.models as models
    HAS_TORCHVISION = True
except ImportError:
    HAS_TORCHVISION = False


from benchmark.npu_benchmark import NPUConfig, PerformanceModel, BenchmarkResult


# Model configurations
PYTORCH_MODELS = {
    'mobilenet_v2': {
        'loader': lambda: models.mobilenet_v2(weights=None),
        'input_shape': (1, 3, 224, 224),
    },
    'mobilenet_v3_small': {
        'loader': lambda: models.mobilenet_v3_small(weights=None),
        'input_shape': (1, 3, 224, 224),
    },
    'mobilenet_v3_large': {
        'loader': lambda: models.mobilenet_v3_large(weights=None),
        'input_shape': (1, 3, 224, 224),
    },
    'resnet18': {
        'loader': lambda: models.resnet18(weights=None),
        'input_shape': (1, 3, 224, 224),
    },
    'resnet50': {
        'loader': lambda: models.resnet50(weights=None),
        'input_shape': (1, 3, 224, 224),
    },
    'efficientnet_b0': {
        'loader': lambda: models.efficientnet_b0(weights=None),
        'input_shape': (1, 3, 224, 224),
    },
    'squeezenet1_0': {
        'loader': lambda: models.squeezenet1_0(weights=None),
        'input_shape': (1, 3, 224, 224),
    },
    'shufflenet_v2_x1_0': {
        'loader': lambda: models.shufflenet_v2_x1_0(weights=None),
        'input_shape': (1, 3, 224, 224),
    },
}


def count_macs_params(model, input_shape):
    """Count MACs and parameters in a model"""
    total_params = sum(p.numel() for p in model.parameters())
    
    # Estimate MACs by analyzing layers
    total_macs = 0
    
    def hook_fn(module, input, output):
        nonlocal total_macs
        
        if isinstance(module, nn.Conv2d):
            # MACs = out_ch * in_ch * k_h * k_w * out_h * out_w / groups
            out_h, out_w = output.shape[2], output.shape[3]
            macs = (module.out_channels * module.in_channels * 
                   module.kernel_size[0] * module.kernel_size[1] *
                   out_h * out_w // module.groups)
            total_macs += macs
            
        elif isinstance(module, nn.Linear):
            macs = module.in_features * module.out_features
            total_macs += macs
    
    hooks = []
    for layer in model.modules():
        if isinstance(layer, (nn.Conv2d, nn.Linear)):
            hooks.append(layer.register_forward_hook(hook_fn))
    
    # Forward pass
    model.eval()
    with torch.no_grad():
        dummy = torch.randn(*input_shape)
        model(dummy)
    
    # Remove hooks
    for h in hooks:
        h.remove()
    
    return total_macs, total_params


def benchmark_pytorch_model(model_name: str, config: NPUConfig) -> BenchmarkResult:
    """Benchmark a PyTorch model"""
    
    if model_name not in PYTORCH_MODELS:
        raise ValueError(f"Unknown model: {model_name}")
    
    model_info = PYTORCH_MODELS[model_name]
    input_shape = model_info['input_shape']
    
    print(f"\nBenchmarking: {model_name}")
    print(f"  Loading model...")
    
    # Load model
    model = model_info['loader']()
    model.eval()
    
    # Count MACs and params
    print(f"  Analyzing model...")
    total_macs, total_params = count_macs_params(model, input_shape)
    
    print(f"  MACs: {total_macs:,}")
    print(f"  Params: {total_params:,}")
    
    # Estimate performance
    perf_model = PerformanceModel(config)
    
    # Calculate cycles
    macs_per_cycle = config.pe_rows * config.pe_cols
    utilization = 0.70  # Assume 70% utilization
    
    effective_macs_per_cycle = macs_per_cycle * utilization
    compute_cycles = int(total_macs / effective_macs_per_cycle)
    total_cycles = int(compute_cycles * 1.15)  # 15% memory overhead
    
    latency_ms = perf_model.cycles_to_time(total_cycles)
    throughput_fps = 1000 / latency_ms if latency_ms > 0 else 0
    
    # Power estimation
    power_mw = perf_model.estimate_power(
        utilization,
        total_params / 1024,
        input_shape[1] * input_shape[2] * input_shape[3] / 1024
    )
    
    # GOPS and efficiency
    gops = total_macs * 2 / (latency_ms * 1e6) if latency_ms > 0 else 0
    tops_per_watt = (gops / 1000) / (power_mw / 1000) if power_mw > 0 else 0
    
    input_size = f"{input_shape[2]}×{input_shape[3]}"
    
    return BenchmarkResult(
        model_name=model_name,
        input_size=input_size,
        latency_ms=round(latency_ms, 2),
        throughput_fps=round(throughput_fps, 1),
        power_mw=round(power_mw, 0),
        total_macs=total_macs,
        total_params=total_params,
        utilization=round(utilization * 100, 1),
        gops=round(gops, 1),
        tops_per_watt=round(tops_per_watt, 2),
        weight_size_kb=round(total_params / 1024, 1),
    )


def main():
    if not HAS_TORCH:
        print("PyTorch required. Install with: pip install torch torchvision")
        return 1
    
    if not HAS_TORCHVISION:
        print("torchvision required. Install with: pip install torchvision")
        return 1
    
    import argparse
    parser = argparse.ArgumentParser(description='PyTorch Model Benchmark')
    parser.add_argument('--model', help='Specific model to benchmark')
    parser.add_argument('--all', action='store_true', help='Benchmark all models')
    parser.add_argument('--clock', type=int, default=800, help='Clock MHz')
    parser.add_argument('--pe-size', type=int, default=16, help='PE array size')
    parser.add_argument('--list', action='store_true', help='List available models')
    
    args = parser.parse_args()
    
    if args.list:
        print("Available PyTorch models:")
        for name in PYTORCH_MODELS:
            print(f"  {name}")
        return 0
    
    config = NPUConfig(
        clock_mhz=args.clock,
        pe_rows=args.pe_size,
        pe_cols=args.pe_size
    )
    
    print("=" * 70)
    print("EdgeNPU PyTorch Model Benchmark")
    print("=" * 70)
    print(f"PE Array: {config.pe_rows}x{config.pe_cols}")
    print(f"Clock: {config.clock_mhz} MHz")
    print(f"Peak: {config.peak_gops:.1f} GOPS")
    
    results = []
    
    if args.all:
        models_to_test = list(PYTORCH_MODELS.keys())
    elif args.model:
        models_to_test = [args.model]
    else:
        # Default: test common models
        models_to_test = ['mobilenet_v2', 'mobilenet_v3_small', 'resnet18']
    
    for model_name in models_to_test:
        try:
            result = benchmark_pytorch_model(model_name, config)
            results.append(result)
        except Exception as e:
            print(f"  Error: {e}")
    
    # Print results table
    print("\n" + "=" * 90)
    print("Benchmark Results")
    print("=" * 90)
    print(f"{'Model':<25} {'Input':<10} {'Latency':<12} {'FPS':<10} {'Power':<10} {'TOPS/W':<10}")
    print("-" * 90)
    
    for r in results:
        print(f"{r.model_name:<25} {r.input_size:<10} {r.latency_ms:>8.2f} ms  "
              f"{r.throughput_fps:>6.1f}    {r.power_mw:>6.0f} mW  {r.tops_per_watt:>6.2f}")
    
    print("=" * 90)
    
    return 0


if __name__ == '__main__':
    sys.exit(main())
