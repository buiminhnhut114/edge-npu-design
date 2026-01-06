"""
EdgeNPU Compiler Optimizer
Graph optimization passes
"""

from .graph_optimizer import GraphOptimizer
from .passes import (
    OptimizationPass,
    FuseConvBNPass,
    FuseConvReluPass,
    ConstantFoldingPass,
    DeadCodeEliminationPass,
    LayoutOptimizationPass,
)
from .quantizer import Quantizer, CalibrationData

__all__ = [
    'GraphOptimizer',
    'OptimizationPass',
    'FuseConvBNPass',
    'FuseConvReluPass',
    'ConstantFoldingPass',
    'DeadCodeEliminationPass',
    'LayoutOptimizationPass',
    'Quantizer',
    'CalibrationData',
]
