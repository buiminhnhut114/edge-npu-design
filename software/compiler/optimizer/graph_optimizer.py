"""
EdgeNPU Compiler - Graph Optimizer
Main optimizer that runs optimization passes
"""

from typing import List, Optional, Dict, Any
import time

from ..frontend.ir_builder import IRGraph

from .passes import (
    OptimizationPass,
    FuseConvBNPass,
    FuseConvReluPass,
    ConstantFoldingPass,
    DeadCodeEliminationPass,
    LayoutOptimizationPass,
    TilingPass,
)


class OptimizationLevel:
    """Optimization levels"""
    O0 = 0  # No optimization
    O1 = 1  # Basic optimizations
    O2 = 2  # Standard optimizations
    O3 = 3  # Aggressive optimizations


class GraphOptimizer:
    """
    Main graph optimizer
    Runs a sequence of optimization passes on the IR graph
    """
    
    def __init__(self, opt_level: int = OptimizationLevel.O2,
                 pe_rows: int = 16, pe_cols: int = 16,
                 weight_buf_kb: int = 256, act_buf_kb: int = 256):
        self.opt_level = opt_level
        self.pe_rows = pe_rows
        self.pe_cols = pe_cols
        self.weight_buf_kb = weight_buf_kb
        self.act_buf_kb = act_buf_kb
        
        self.passes: List[OptimizationPass] = []
        self.stats: Dict[str, Any] = {}
        
        self._setup_passes()
    
    def _setup_passes(self):
        """Setup optimization passes based on level"""
        self.passes = []
        
        if self.opt_level >= OptimizationLevel.O1:
            # Basic optimizations
            self.passes.append(ConstantFoldingPass())
            self.passes.append(DeadCodeEliminationPass())
        
        if self.opt_level >= OptimizationLevel.O2:
            # Standard optimizations
            self.passes.append(FuseConvBNPass())
            self.passes.append(FuseConvReluPass())
            self.passes.append(DeadCodeEliminationPass())  # Run again after fusion
            self.passes.append(LayoutOptimizationPass())
        
        if self.opt_level >= OptimizationLevel.O3:
            # Aggressive optimizations
            self.passes.append(TilingPass(
                pe_rows=self.pe_rows,
                pe_cols=self.pe_cols,
                weight_buf_kb=self.weight_buf_kb,
                act_buf_kb=self.act_buf_kb
            ))
    
    def add_pass(self, pass_: OptimizationPass):
        """Add custom optimization pass"""
        self.passes.append(pass_)
    
    def remove_pass(self, pass_name: str):
        """Remove pass by name"""
        self.passes = [p for p in self.passes if p.name != pass_name]
    
    def optimize(self, graph: IRGraph, verbose: bool = False) -> IRGraph:
        """
        Run all optimization passes on graph
        
        Args:
            graph: Input IR graph
            verbose: Print optimization progress
            
        Returns:
            Optimized IR graph
        """
        self.stats = {
            'original_nodes': len(graph.nodes),
            'original_tensors': len(graph.tensors),
            'passes': [],
        }
        
        if verbose:
            print(f"Starting optimization (level O{self.opt_level})")
            print(f"  Initial: {len(graph.nodes)} nodes, {len(graph.tensors)} tensors")
        
        for pass_ in self.passes:
            start_time = time.time()
            nodes_before = len(graph.nodes)
            
            try:
                graph = pass_.run(graph)
            except Exception as e:
                if verbose:
                    print(f"  Warning: Pass '{pass_.name}' failed: {e}")
                continue
            
            elapsed = time.time() - start_time
            nodes_after = len(graph.nodes)
            
            pass_stats = {
                'name': pass_.name,
                'time_ms': elapsed * 1000,
                'nodes_removed': nodes_before - nodes_after,
            }
            self.stats['passes'].append(pass_stats)
            
            if verbose:
                print(f"  {pass_.name}: {nodes_before} -> {nodes_after} nodes "
                      f"({elapsed*1000:.2f}ms)")
        
        self.stats['final_nodes'] = len(graph.nodes)
        self.stats['final_tensors'] = len(graph.tensors)
        self.stats['nodes_reduced'] = self.stats['original_nodes'] - self.stats['final_nodes']
        
        if verbose:
            print(f"  Final: {len(graph.nodes)} nodes, {len(graph.tensors)} tensors")
            print(f"  Reduced {self.stats['nodes_reduced']} nodes")
        
        return graph
    
    def get_stats(self) -> Dict[str, Any]:
        """Get optimization statistics"""
        return self.stats
    
    def print_stats(self):
        """Print optimization statistics"""
        print("\nOptimization Statistics:")
        print(f"  Original: {self.stats.get('original_nodes', 0)} nodes")
        print(f"  Final: {self.stats.get('final_nodes', 0)} nodes")
        print(f"  Reduced: {self.stats.get('nodes_reduced', 0)} nodes")
        print("\n  Passes:")
        for p in self.stats.get('passes', []):
            print(f"    {p['name']}: {p['time_ms']:.2f}ms, "
                  f"-{p['nodes_removed']} nodes")


def optimize_graph(graph: IRGraph, 
                   opt_level: int = OptimizationLevel.O2,
                   verbose: bool = False) -> IRGraph:
    """
    Convenience function to optimize a graph
    
    Args:
        graph: Input IR graph
        opt_level: Optimization level (0-3)
        verbose: Print progress
        
    Returns:
        Optimized graph
    """
    optimizer = GraphOptimizer(opt_level=opt_level)
    return optimizer.optimize(graph, verbose=verbose)
