"""
EdgeNPU Benchmark Suite

Provides tools for measuring and estimating NPU performance:
- Performance estimation based on cycle-accurate model
- RTL simulation benchmarks
- Comparison with baseline implementations
"""

from .npu_benchmark import (
    NPUConfig,
    BenchmarkResult,
    ModelBenchmark,
    PerformanceModel,
    print_benchmark_table,
    print_detailed_results,
    save_results_json,
)

__all__ = [
    'NPUConfig',
    'BenchmarkResult', 
    'ModelBenchmark',
    'PerformanceModel',
    'print_benchmark_table',
    'print_detailed_results',
    'save_results_json',
]
