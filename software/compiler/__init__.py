"""
EdgeNPU Compiler
Complete compilation pipeline for neural network models
"""

from .frontend import IRBuilder, IRGraph, ModelParser, ONNXParser, TFLiteParser
from .optimizer import GraphOptimizer, Quantizer
from .backend import CodeGenerator, InstructionEmitter, MemoryAllocator, Scheduler

__version__ = "1.0.0"

__all__ = [
    # Frontend
    'IRBuilder',
    'IRGraph', 
    'ModelParser',
    'ONNXParser',
    'TFLiteParser',
    
    # Optimizer
    'GraphOptimizer',
    'Quantizer',
    
    # Backend
    'CodeGenerator',
    'InstructionEmitter',
    'MemoryAllocator',
    'Scheduler',
    
    # Main compiler
    'NPUCompiler',
    'compile_model',
]


class NPUCompiler:
    """
    Main NPU compiler class
    Provides end-to-end compilation from model file to NPU binary
    """
    
    def __init__(self, pe_rows: int = 16, pe_cols: int = 16,
                 weight_buf_kb: int = 256, act_buf_kb: int = 256,
                 opt_level: int = 2):
        self.pe_rows = pe_rows
        self.pe_cols = pe_cols
        self.weight_buf_kb = weight_buf_kb
        self.act_buf_kb = act_buf_kb
        self.opt_level = opt_level
        
        self.optimizer = GraphOptimizer(
            opt_level=opt_level,
            pe_rows=pe_rows,
            pe_cols=pe_cols,
            weight_buf_kb=weight_buf_kb,
            act_buf_kb=act_buf_kb
        )
        
        self.quantizer = Quantizer()
        
        self.codegen = CodeGenerator(
            pe_rows=pe_rows,
            pe_cols=pe_cols,
            weight_buf_kb=weight_buf_kb,
            act_buf_kb=act_buf_kb
        )
    
    def compile(self, model_path: str, output_path: str = None,
                quantize: bool = True, verbose: bool = False):
        """
        Compile model file to NPU binary
        
        Args:
            model_path: Path to input model (ONNX or TFLite)
            output_path: Path for output binary
            quantize: Whether to quantize to INT8
            verbose: Print progress
            
        Returns:
            CompiledModel object
        """
        if verbose:
            print(f"Compiling: {model_path}")
        
        # Step 1: Parse model
        if verbose:
            print("\n1. Parsing model...")
        
        if model_path.endswith('.onnx'):
            parser = ONNXParser()
        elif model_path.endswith('.tflite'):
            parser = TFLiteParser()
        else:
            raise ValueError(f"Unsupported model format: {model_path}")
        
        graph = parser.parse(model_path)
        
        if verbose:
            print(f"   Parsed {len(graph.nodes)} nodes")
        
        # Step 2: Optimize
        if verbose:
            print("\n2. Optimizing graph...")
        
        graph = self.optimizer.optimize(graph, verbose=verbose)
        
        # Step 3: Quantize
        if quantize:
            if verbose:
                print("\n3. Quantizing to INT8...")
            graph = self.quantizer.quantize(graph)
        
        # Step 4: Generate code
        if verbose:
            print("\n4. Generating code...")
        
        compiled = self.codegen.generate(graph, verbose=verbose)
        
        # Step 5: Save output
        if output_path:
            compiled.save(output_path)
            if verbose:
                print(f"\nSaved to: {output_path}")
        
        return compiled
    
    def compile_graph(self, graph: IRGraph, quantize: bool = True,
                      verbose: bool = False):
        """
        Compile IR graph directly
        
        Args:
            graph: IR graph
            quantize: Whether to quantize
            verbose: Print progress
            
        Returns:
            CompiledModel object
        """
        # Optimize
        graph = self.optimizer.optimize(graph, verbose=verbose)
        
        # Quantize
        if quantize:
            graph = self.quantizer.quantize(graph)
        
        # Generate code
        return self.codegen.generate(graph, verbose=verbose)


def compile_model(model_path: str, output_path: str = None, **kwargs):
    """
    Convenience function to compile a model
    
    Args:
        model_path: Path to input model
        output_path: Path for output binary
        **kwargs: Additional compiler options
        
    Returns:
        CompiledModel object
    """
    compiler = NPUCompiler(**kwargs)
    return compiler.compile(model_path, output_path, verbose=True)
