#!/usr/bin/env python3
"""
Compare EdgeNPU performance with CPU/GPU baselines
"""

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))

from benchmark.npu_benchmark import NPUConfig, ModelBenchmark, BenchmarkResult


# Baseline performance data (typical values)
CPU_BASELINES = {
    # Model: (latency_ms, power_mw) on ARM Cortex-A76 @ 2.4GHz
    'mobilenet_v1': (45.0, 2000),
    'mobilenet_v2': (35.0, 2000),
    'mobilenet_v3_small': (15.0, 1800),
    'efficientnet_lite0': (55.0, 2200),
    'resnet18': (120.0, 2500),
    'yolo_tiny': (250.0, 3000),
    'ssd_mobilenetv2': (85.0, 2200),
}

GPU_BASELINES = {
    # Model: (latency_ms, power_mw) on Mali-G78 GPU
    'mobilenet_v1': (8.0, 3500),
    'mobilenet_v2': (6.5, 3500),
    'mobilenet_v3_small': (4.0, 3000),
    'efficientnet_lite0': (10.0, 4000),
    'resnet18': (25.0, 5000),
    'yolo_tiny': (45.0, 6000),
    'ssd_mobilenetv2': (15.0, 4000),
}

EDGE_TPU_BASELINES = {
    # Model: (latency_ms, power_mw) on Google Edge TPU
    'mobilenet_v1': (2.0, 2000),
    'mobilenet_v2': (2.5, 2000),
    'mobilenet_v3_small': (1.2, 1800),
    'efficientnet_lite0': (3.5, 2200),
    'resnet18': (10.0, 2500),
    'yolo_tiny': (15.0, 2800),
    'ssd_mobilenetv2': (6.0, 2200),
}


def compare_performance():
    """Compare EdgeNPU with baselines"""
    
    # Run NPU benchmark
    config = NPUConfig(clock_mhz=800)
    benchmark = ModelBenchmark(config)
    
    print("=" * 100)
    print("EdgeNPU vs Baseline Comparison")
    print("=" * 100)
    print(f"\nEdgeNPU Config: {config.pe_rows}x{config.pe_cols} PE @ {config.clock_mhz}MHz")
    print(f"Peak Performance: {config.peak_gops:.1f} GOPS\n")
    
    # Header
    print(f"{'Model':<20} {'EdgeNPU':<15} {'CPU':<15} {'GPU':<15} {'Edge TPU':<15} {'NPU Speedup':<15}")
    print(f"{'':20} {'(ms/mW)':<15} {'(ms/mW)':<15} {'(ms/mW)':<15} {'(ms/mW)':<15} {'vs CPU/GPU':<15}")
    print("-" * 100)
    
    for model_name in ['mobilenet_v1', 'mobilenet_v2', 'mobilenet_v3_small', 
                       'resnet18', 'yolo_tiny']:
        try:
            npu_result = benchmark.benchmark_model(model_name)
            
            cpu_lat, cpu_pwr = CPU_BASELINES.get(model_name, (0, 0))
            gpu_lat, gpu_pwr = GPU_BASELINES.get(model_name, (0, 0))
            tpu_lat, tpu_pwr = EDGE_TPU_BASELINES.get(model_name, (0, 0))
            
            # Calculate speedups
            cpu_speedup = cpu_lat / npu_result.latency_ms if npu_result.latency_ms > 0 else 0
            gpu_speedup = gpu_lat / npu_result.latency_ms if npu_result.latency_ms > 0 else 0
            
            # Calculate efficiency (TOPS/W)
            npu_eff = npu_result.tops_per_watt
            cpu_eff = (npu_result.total_macs * 2 / (cpu_lat * 1e6) / 1000) / (cpu_pwr / 1000) if cpu_lat > 0 else 0
            gpu_eff = (npu_result.total_macs * 2 / (gpu_lat * 1e6) / 1000) / (gpu_pwr / 1000) if gpu_lat > 0 else 0
            
            print(f"{model_name:<20} "
                  f"{npu_result.latency_ms:>5.1f}/{npu_result.power_mw:>4.0f}   "
                  f"{cpu_lat:>5.1f}/{cpu_pwr:>4.0f}   "
                  f"{gpu_lat:>5.1f}/{gpu_pwr:>4.0f}   "
                  f"{tpu_lat:>5.1f}/{tpu_pwr:>4.0f}   "
                  f"{cpu_speedup:>4.1f}x/{gpu_speedup:>4.1f}x")
            
        except Exception as e:
            print(f"{model_name:<20} Error: {e}")
    
    print("=" * 100)
    
    # Summary
    print("\nEfficiency Comparison (TOPS/W):")
    print("-" * 50)
    
    total_npu_eff = 0
    count = 0
    
    for model_name in ['mobilenet_v1', 'mobilenet_v2', 'mobilenet_v3_small']:
        try:
            npu_result = benchmark.benchmark_model(model_name)
            cpu_lat, cpu_pwr = CPU_BASELINES.get(model_name, (100, 2000))
            gpu_lat, gpu_pwr = GPU_BASELINES.get(model_name, (10, 4000))
            
            npu_eff = npu_result.tops_per_watt
            cpu_eff = 0.01  # Typical CPU efficiency
            gpu_eff = 0.1   # Typical mobile GPU efficiency
            
            print(f"{model_name:<25} NPU: {npu_eff:.2f}  CPU: {cpu_eff:.2f}  GPU: {gpu_eff:.2f}")
            total_npu_eff += npu_eff
            count += 1
        except:
            pass
    
    if count > 0:
        print(f"\nAverage NPU Efficiency: {total_npu_eff/count:.2f} TOPS/W")
    
    print("\nNote: Baseline values are typical estimates for comparison purposes.")


def main():
    compare_performance()
    return 0


if __name__ == '__main__':
    sys.exit(main())
