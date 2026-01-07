"""
EdgeNPU Compiler - PyTorch Model Parser
Parse PyTorch models (.pt, .pth, TorchScript) to IR

Supports:
- TorchScript models (traced/scripted)
- State dict with model definition
- Direct nn.Module parsing via tracing
"""

from typing import Dict, List, Optional, Any, Tuple, Union
import numpy as np
from pathlib import Path

from .ir_builder import (
    IRBuilder, IRGraph, IRNode, IRTensor, IROpType,
    DataType, DataLayout
)


class PyTorchParser:
    """
    Parser for PyTorch models
    
    Supports multiple input formats:
    1. TorchScript (.pt) - torch.jit.save() output
    2. State dict (.pth) - torch.save(model.state_dict())
    3. Full model (.pth) - torch.save(model)
    4. nn.Module - direct parsing via tracing
    """
    
    # PyTorch op to IR op mapping
    OP_MAP = {
        # Convolution
        'aten::conv2d': IROpType.CONV2D,
        'aten::_convolution': IROpType.CONV2D,
        'aten::conv1d': IROpType.CONV2D,
        'aten::conv_transpose2d': IROpType.CONV2D,
        
        # Linear
        'aten::linear': IROpType.FULLY_CONNECTED,
        'aten::matmul': IROpType.MATMUL,
        'aten::mm': IROpType.MATMUL,
        'aten::bmm': IROpType.MATMUL,
        'aten::addmm': IROpType.FULLY_CONNECTED,
        
        # Activations
        'aten::relu': IROpType.RELU,
        'aten::relu_': IROpType.RELU,
        'aten::relu6': IROpType.RELU6,
        'aten::hardtanh': IROpType.RELU6,  # hardtanh(0,6) = relu6
        'aten::sigmoid': IROpType.SIGMOID,
        'aten::tanh': IROpType.TANH,
        'aten::leaky_relu': IROpType.LEAKY_RELU,
        'aten::leaky_relu_': IROpType.LEAKY_RELU,
        'aten::silu': IROpType.SWISH,  # SiLU = Swish
        'aten::gelu': IROpType.GELU,
        'aten::softmax': IROpType.SOFTMAX,
        'aten::log_softmax': IROpType.SOFTMAX,
        'aten::hardswish': IROpType.SWISH,
        'aten::hardsigmoid': IROpType.SIGMOID,
        
        # Pooling
        'aten::max_pool2d': IROpType.MAX_POOL2D,
        'aten::max_pool2d_with_indices': IROpType.MAX_POOL2D,
        'aten::avg_pool2d': IROpType.AVG_POOL2D,
        'aten::adaptive_avg_pool2d': IROpType.GLOBAL_AVG_POOL,
        'aten::adaptive_max_pool2d': IROpType.MAX_POOL2D,
        'aten::mean': IROpType.GLOBAL_AVG_POOL,
        
        # Element-wise
        'aten::add': IROpType.ADD,
        'aten::add_': IROpType.ADD,
        'aten::sub': IROpType.SUB,
        'aten::mul': IROpType.MUL,
        'aten::mul_': IROpType.MUL,
        'aten::div': IROpType.DIV,
        
        # Normalization
        'aten::batch_norm': IROpType.BATCH_NORM,
        'aten::layer_norm': IROpType.LAYER_NORM,
        'aten::instance_norm': IROpType.BATCH_NORM,
        'aten::group_norm': IROpType.BATCH_NORM,
        
        # Shape operations
        'aten::view': IROpType.RESHAPE,
        'aten::reshape': IROpType.RESHAPE,
        'aten::flatten': IROpType.RESHAPE,
        'aten::squeeze': IROpType.RESHAPE,
        'aten::unsqueeze': IROpType.RESHAPE,
        'aten::permute': IROpType.TRANSPOSE,
        'aten::transpose': IROpType.TRANSPOSE,
        'aten::contiguous': IROpType.RESHAPE,
        'aten::cat': IROpType.CONCAT,
        'aten::concat': IROpType.CONCAT,
        'aten::split': IROpType.SPLIT,
        'aten::chunk': IROpType.SPLIT,
        'aten::pad': IROpType.PAD,
        
        # Other
        'aten::dropout': None,  # Skip in inference
        'aten::dropout_': None,
    }
    
    def __init__(self):
        self.torch = None
        self._load_torch()
        self._weight_map: Dict[str, np.ndarray] = {}
        self._node_outputs: Dict[str, str] = {}  # torch node -> ir tensor name
    
    def _load_torch(self):
        """Load PyTorch library"""
        try:
            import torch
            self.torch = torch
        except ImportError:
            pass
    
    def supported_ops(self) -> List[str]:
        """Return list of supported operations"""
        return [k for k, v in self.OP_MAP.items() if v is not None]

    def parse(self, model_path: str, 
              input_shape: Tuple[int, ...] = (1, 3, 224, 224),
              model_class: Optional[Any] = None) -> IRGraph:
        """
        Parse PyTorch model to IR
        
        Args:
            model_path: Path to .pt or .pth file
            input_shape: Input tensor shape for tracing (NCHW format)
            model_class: Optional model class for state_dict loading
            
        Returns:
            IRGraph representation
        """
        if self.torch is None:
            raise ImportError("PyTorch not installed. Run: pip install torch")
        
        path = Path(model_path)
        
        # Determine model type and load
        if path.suffix == '.pt':
            # TorchScript model
            model = self._load_torchscript(model_path)
        elif path.suffix == '.pth':
            # State dict or full model
            model = self._load_pth(model_path, model_class)
        else:
            raise ValueError(f"Unsupported file format: {path.suffix}")
        
        # Convert to TorchScript if needed
        if not isinstance(model, self.torch.jit.ScriptModule):
            model = self._trace_model(model, input_shape)
        
        # Parse TorchScript graph
        return self._parse_torchscript(model, input_shape)
    
    def parse_module(self, module, 
                     input_shape: Tuple[int, ...] = (1, 3, 224, 224),
                     model_name: str = "pytorch_model") -> IRGraph:
        """
        Parse nn.Module directly
        
        Args:
            module: PyTorch nn.Module
            input_shape: Input tensor shape
            model_name: Name for the model
            
        Returns:
            IRGraph representation
        """
        if self.torch is None:
            raise ImportError("PyTorch not installed")
        
        # Trace the module
        traced = self._trace_model(module, input_shape)
        return self._parse_torchscript(traced, input_shape, model_name)
    
    def _load_torchscript(self, path: str):
        """Load TorchScript model"""
        return self.torch.jit.load(path, map_location='cpu')
    
    def _load_pth(self, path: str, model_class: Optional[Any] = None):
        """Load .pth file (state_dict or full model)"""
        checkpoint = self.torch.load(path, map_location='cpu')
        
        if isinstance(checkpoint, dict):
            # It's a state dict
            if model_class is None:
                raise ValueError(
                    "model_class required for state_dict loading. "
                    "Provide the model class or use TorchScript (.pt) format."
                )
            
            # Handle different checkpoint formats
            if 'state_dict' in checkpoint:
                state_dict = checkpoint['state_dict']
            elif 'model_state_dict' in checkpoint:
                state_dict = checkpoint['model_state_dict']
            else:
                state_dict = checkpoint
            
            model = model_class()
            model.load_state_dict(state_dict, strict=False)
            return model
        else:
            # It's a full model
            return checkpoint
    
    def _trace_model(self, model, input_shape: Tuple[int, ...]):
        """Trace model to TorchScript"""
        model.eval()
        dummy_input = self.torch.randn(*input_shape)
        
        with self.torch.no_grad():
            traced = self.torch.jit.trace(model, dummy_input)
        
        return traced

    def _parse_torchscript(self, model, input_shape: Tuple[int, ...],
                           model_name: str = "pytorch_model") -> IRGraph:
        """Parse TorchScript model to IR"""
        builder = IRBuilder(name=model_name)
        
        # Extract weights from state dict
        self._extract_weights(model, builder)
        
        # Add input
        input_name = builder.add_input("input", input_shape)
        self._node_outputs['input'] = input_name
        
        # Get the graph
        graph = model.graph
        
        # Process graph inputs (skip self and input tensor)
        graph_inputs = list(graph.inputs())
        
        # Process all nodes
        for node in graph.nodes():
            self._parse_node(builder, node)
        
        # Find and add output
        for output in graph.outputs():
            output_name = self._get_tensor_name(output)
            if output_name in self._node_outputs:
                builder.add_output(self._node_outputs[output_name])
            elif output_name in builder.graph.tensors:
                builder.add_output(output_name)
        
        # If no output found, use last node's output
        if not builder.graph.outputs and builder.graph.nodes:
            last_node = builder.graph.nodes[-1]
            if last_node.outputs:
                builder.add_output(last_node.outputs[0])
        
        return builder.build()
    
    def _extract_weights(self, model, builder: IRBuilder):
        """Extract weights from model state dict"""
        state_dict = model.state_dict()
        
        for name, param in state_dict.items():
            # Convert to numpy
            data = param.cpu().numpy()
            
            # Clean up name
            clean_name = name.replace('.', '_')
            
            # Add as constant
            builder.add_constant(clean_name, data)
            self._weight_map[name] = clean_name
    
    def _get_tensor_name(self, value) -> str:
        """Get unique name for a tensor value"""
        debug_name = value.debugName()
        return debug_name.replace('.', '_').replace('%', 't')
    
    def _parse_node(self, builder: IRBuilder, node):
        """Parse a single TorchScript node"""
        op_kind = node.kind()
        
        # Skip certain ops
        if op_kind in ['prim::Constant', 'prim::ListConstruct', 
                       'prim::TupleConstruct', 'prim::GetAttr',
                       'prim::NumToTensor', 'aten::Int', 'aten::size',
                       'aten::to', 'aten::detach', 'aten::clone']:
            return
        
        # Get IR op type
        ir_op = self.OP_MAP.get(op_kind)
        
        if ir_op is None:
            if op_kind in self.OP_MAP:
                # Explicitly skipped (like dropout)
                return
            print(f"Warning: Unsupported op '{op_kind}', skipping")
            return
        
        # Parse based on op type
        if op_kind in ['aten::conv2d', 'aten::_convolution']:
            self._parse_conv2d(builder, node)
        elif op_kind in ['aten::linear', 'aten::addmm']:
            self._parse_linear(builder, node)
        elif op_kind == 'aten::batch_norm':
            self._parse_batch_norm(builder, node)
        elif op_kind in ['aten::relu', 'aten::relu_']:
            self._parse_activation(builder, node, IROpType.RELU)
        elif op_kind in ['aten::sigmoid']:
            self._parse_activation(builder, node, IROpType.SIGMOID)
        elif op_kind in ['aten::tanh']:
            self._parse_activation(builder, node, IROpType.TANH)
        elif op_kind in ['aten::silu', 'aten::hardswish']:
            self._parse_activation(builder, node, IROpType.SWISH)
        elif op_kind == 'aten::gelu':
            self._parse_activation(builder, node, IROpType.GELU)
        elif op_kind in ['aten::softmax', 'aten::log_softmax']:
            self._parse_softmax(builder, node)
        elif op_kind in ['aten::max_pool2d', 'aten::max_pool2d_with_indices']:
            self._parse_maxpool(builder, node)
        elif op_kind == 'aten::avg_pool2d':
            self._parse_avgpool(builder, node)
        elif op_kind in ['aten::adaptive_avg_pool2d', 'aten::mean']:
            self._parse_global_pool(builder, node)
        elif op_kind in ['aten::add', 'aten::add_']:
            self._parse_elementwise(builder, node, IROpType.ADD)
        elif op_kind in ['aten::mul', 'aten::mul_']:
            self._parse_elementwise(builder, node, IROpType.MUL)
        elif op_kind in ['aten::sub']:
            self._parse_elementwise(builder, node, IROpType.SUB)
        elif op_kind in ['aten::view', 'aten::reshape', 'aten::flatten']:
            self._parse_reshape(builder, node)
        elif op_kind in ['aten::cat', 'aten::concat']:
            self._parse_concat(builder, node)
        elif op_kind in ['aten::permute', 'aten::transpose']:
            self._parse_transpose(builder, node)
        else:
            self._parse_generic(builder, node, ir_op)

    def _get_input_name(self, node, idx: int = 0) -> Optional[str]:
        """Get input tensor name for node"""
        inputs = list(node.inputs())
        if idx >= len(inputs):
            return None
        
        input_val = inputs[idx]
        tensor_name = self._get_tensor_name(input_val)
        
        # Check if it's a previous node's output
        if tensor_name in self._node_outputs:
            return self._node_outputs[tensor_name]
        
        # Check if it's 'input'
        if 'input' in tensor_name.lower() or tensor_name == 't0':
            return 'input'
        
        return tensor_name
    
    def _get_const_value(self, node, idx: int) -> Optional[Any]:
        """Get constant value from node input"""
        inputs = list(node.inputs())
        if idx >= len(inputs):
            return None
        
        input_node = inputs[idx].node()
        if input_node.kind() == 'prim::Constant':
            # Extract constant value
            output = input_node.output()
            if output.type().kind() == 'IntType':
                return output.toIValue()
            elif output.type().kind() == 'ListType':
                return output.toIValue()
            elif output.type().kind() == 'FloatType':
                return output.toIValue()
        return None
    
    def _find_weight(self, name_hint: str) -> Optional[str]:
        """Find weight tensor by name hint"""
        for orig_name, clean_name in self._weight_map.items():
            if name_hint in orig_name or name_hint in clean_name:
                return clean_name
        return None
    
    def _parse_conv2d(self, builder: IRBuilder, node):
        """Parse Conv2D node"""
        inputs = list(node.inputs())
        output = node.output()
        output_name = self._get_tensor_name(output)
        
        # Get input
        input_name = self._get_input_name(node, 0)
        if input_name is None:
            return
        
        # Find weight - try to get from GetAttr chain
        weight_name = None
        bias_name = None
        
        # Look for weight in inputs
        if len(inputs) > 1:
            weight_input = inputs[1]
            weight_node = weight_input.node()
            
            if weight_node.kind() == 'prim::GetAttr':
                # Extract attribute name
                attr_name = weight_node.s('name')
                weight_name = self._find_weight(attr_name)
            else:
                # Try to find by pattern matching
                for name, clean in self._weight_map.items():
                    if 'weight' in name and 'conv' in name.lower():
                        weight_name = clean
                        break
        
        # If still no weight, create placeholder
        if weight_name is None:
            weight_name = f"conv_weight_{len(builder.graph.nodes)}"
            # Create dummy weight
            builder.add_constant(weight_name, np.zeros((64, 64, 3, 3), dtype=np.float32))
        
        # Get conv parameters
        stride = self._get_const_value(node, 3) or [1, 1]
        padding = self._get_const_value(node, 4) or [0, 0]
        
        if isinstance(stride, int):
            stride = [stride, stride]
        if isinstance(padding, int):
            padding = [padding, padding]
        
        # Build conv
        ir_output = builder.conv2d(
            input_name=input_name,
            weight_name=weight_name,
            bias_name=bias_name,
            kernel_size=(3, 3),  # Will be inferred from weight
            stride=tuple(stride[:2]),
            padding=tuple(padding[:2])
        )
        
        self._node_outputs[output_name] = ir_output
    
    def _parse_linear(self, builder: IRBuilder, node):
        """Parse Linear/FC node"""
        output = node.output()
        output_name = self._get_tensor_name(output)
        
        input_name = self._get_input_name(node, 0)
        if input_name is None:
            return
        
        # Find weight
        weight_name = None
        for name, clean in self._weight_map.items():
            if 'weight' in name and ('fc' in name.lower() or 'linear' in name.lower() 
                                      or 'classifier' in name.lower()):
                weight_name = clean
                break
        
        if weight_name is None:
            weight_name = f"fc_weight_{len(builder.graph.nodes)}"
            builder.add_constant(weight_name, np.zeros((1000, 512), dtype=np.float32))
        
        ir_output = builder.fully_connected(
            input_name=input_name,
            weight_name=weight_name
        )
        
        self._node_outputs[output_name] = ir_output

    def _parse_batch_norm(self, builder: IRBuilder, node):
        """Parse BatchNorm node"""
        output = node.output()
        output_name = self._get_tensor_name(output)
        
        input_name = self._get_input_name(node, 0)
        if input_name is None:
            return
        
        # Find BN parameters
        gamma_name = beta_name = mean_name = var_name = None
        
        for name, clean in self._weight_map.items():
            if 'running_mean' in name:
                mean_name = clean
            elif 'running_var' in name:
                var_name = clean
            elif 'weight' in name and 'bn' in name.lower():
                gamma_name = clean
            elif 'bias' in name and 'bn' in name.lower():
                beta_name = clean
        
        # Create placeholders if not found
        if gamma_name is None:
            gamma_name = f"bn_gamma_{len(builder.graph.nodes)}"
            builder.add_constant(gamma_name, np.ones(64, dtype=np.float32))
        if beta_name is None:
            beta_name = f"bn_beta_{len(builder.graph.nodes)}"
            builder.add_constant(beta_name, np.zeros(64, dtype=np.float32))
        if mean_name is None:
            mean_name = f"bn_mean_{len(builder.graph.nodes)}"
            builder.add_constant(mean_name, np.zeros(64, dtype=np.float32))
        if var_name is None:
            var_name = f"bn_var_{len(builder.graph.nodes)}"
            builder.add_constant(var_name, np.ones(64, dtype=np.float32))
        
        ir_output = builder.batch_norm(
            input_name=input_name,
            gamma_name=gamma_name,
            beta_name=beta_name,
            mean_name=mean_name,
            var_name=var_name
        )
        
        self._node_outputs[output_name] = ir_output
    
    def _parse_activation(self, builder: IRBuilder, node, op_type: IROpType):
        """Parse activation node"""
        output = node.output()
        output_name = self._get_tensor_name(output)
        
        input_name = self._get_input_name(node, 0)
        if input_name is None:
            return
        
        if op_type == IROpType.RELU:
            ir_output = builder.relu(input_name)
        elif op_type == IROpType.SIGMOID:
            ir_output = builder.sigmoid(input_name)
        else:
            ir_output = builder._add_activation(input_name, op_type)
        
        self._node_outputs[output_name] = ir_output
    
    def _parse_softmax(self, builder: IRBuilder, node):
        """Parse Softmax node"""
        output = node.output()
        output_name = self._get_tensor_name(output)
        
        input_name = self._get_input_name(node, 0)
        if input_name is None:
            return
        
        axis = self._get_const_value(node, 1) or -1
        
        ir_output = builder.softmax(input_name, axis=axis)
        self._node_outputs[output_name] = ir_output
    
    def _parse_maxpool(self, builder: IRBuilder, node):
        """Parse MaxPool2D node"""
        output = node.output()
        # Handle max_pool2d_with_indices which returns tuple
        if node.kind() == 'aten::max_pool2d_with_indices':
            outputs = list(node.outputs())
            output_name = self._get_tensor_name(outputs[0])
        else:
            output_name = self._get_tensor_name(output)
        
        input_name = self._get_input_name(node, 0)
        if input_name is None:
            return
        
        kernel_size = self._get_const_value(node, 1) or [2, 2]
        stride = self._get_const_value(node, 2) or kernel_size
        
        if isinstance(kernel_size, int):
            kernel_size = [kernel_size, kernel_size]
        if isinstance(stride, int):
            stride = [stride, stride]
        
        ir_output = builder.max_pool2d(
            input_name,
            kernel_size=tuple(kernel_size[:2]),
            stride=tuple(stride[:2])
        )
        
        self._node_outputs[output_name] = ir_output
    
    def _parse_avgpool(self, builder: IRBuilder, node):
        """Parse AvgPool2D node"""
        output = node.output()
        output_name = self._get_tensor_name(output)
        
        input_name = self._get_input_name(node, 0)
        if input_name is None:
            return
        
        kernel_size = self._get_const_value(node, 1) or [2, 2]
        stride = self._get_const_value(node, 2) or kernel_size
        
        if isinstance(kernel_size, int):
            kernel_size = [kernel_size, kernel_size]
        if isinstance(stride, int):
            stride = [stride, stride]
        
        ir_output = builder.avg_pool2d(
            input_name,
            kernel_size=tuple(kernel_size[:2]),
            stride=tuple(stride[:2])
        )
        
        self._node_outputs[output_name] = ir_output

    def _parse_global_pool(self, builder: IRBuilder, node):
        """Parse Global Average Pooling node"""
        output = node.output()
        output_name = self._get_tensor_name(output)
        
        input_name = self._get_input_name(node, 0)
        if input_name is None:
            return
        
        ir_output = builder.global_avg_pool(input_name)
        self._node_outputs[output_name] = ir_output
    
    def _parse_elementwise(self, builder: IRBuilder, node, op_type: IROpType):
        """Parse element-wise operation"""
        output = node.output()
        output_name = self._get_tensor_name(output)
        
        input1_name = self._get_input_name(node, 0)
        input2_name = self._get_input_name(node, 1)
        
        if input1_name is None:
            return
        
        # Handle scalar addition (bias, etc.)
        if input2_name is None:
            # Just pass through
            self._node_outputs[output_name] = input1_name
            return
        
        if op_type == IROpType.ADD:
            ir_output = builder.add(input1_name, input2_name)
        elif op_type == IROpType.MUL:
            ir_output = builder.mul(input1_name, input2_name)
        else:
            ir_output = builder._add_eltwise(input1_name, input2_name, op_type)
        
        self._node_outputs[output_name] = ir_output
    
    def _parse_reshape(self, builder: IRBuilder, node):
        """Parse reshape/view/flatten node"""
        output = node.output()
        output_name = self._get_tensor_name(output)
        
        input_name = self._get_input_name(node, 0)
        if input_name is None:
            return
        
        # Get target shape
        shape = self._get_const_value(node, 1)
        if shape is None:
            shape = (-1,)
        
        if isinstance(shape, int):
            shape = (shape,)
        
        ir_output = builder.reshape(input_name, tuple(shape))
        self._node_outputs[output_name] = ir_output
    
    def _parse_concat(self, builder: IRBuilder, node):
        """Parse concatenation node"""
        output = node.output()
        output_name = self._get_tensor_name(output)
        
        # Get input list
        inputs = list(node.inputs())
        input_names = []
        
        # First input is usually a list
        if inputs:
            list_node = inputs[0].node()
            if list_node.kind() == 'prim::ListConstruct':
                for inp in list_node.inputs():
                    name = self._get_tensor_name(inp)
                    if name in self._node_outputs:
                        input_names.append(self._node_outputs[name])
        
        if not input_names:
            return
        
        axis = self._get_const_value(node, 1) or 1
        
        ir_output = builder.concat(input_names, axis=axis)
        self._node_outputs[output_name] = ir_output
    
    def _parse_transpose(self, builder: IRBuilder, node):
        """Parse transpose/permute node"""
        output = node.output()
        output_name = self._get_tensor_name(output)
        
        input_name = self._get_input_name(node, 0)
        if input_name is None:
            return
        
        # For now, just pass through (transpose is handled in layout optimization)
        self._node_outputs[output_name] = input_name
    
    def _parse_generic(self, builder: IRBuilder, node, ir_op: IROpType):
        """Generic node parsing for unsupported ops"""
        output = node.output()
        output_name = self._get_tensor_name(output)
        
        input_name = self._get_input_name(node, 0)
        if input_name is None:
            return
        
        # Create a generic node
        ir_output = builder._add_activation(input_name, ir_op)
        self._node_outputs[output_name] = ir_output


# =============================================================================
# Convenience functions
# =============================================================================

def parse_pytorch_model(model_path: str,
                        input_shape: Tuple[int, ...] = (1, 3, 224, 224),
                        model_class: Optional[Any] = None) -> IRGraph:
    """
    Parse PyTorch model file to IR
    
    Args:
        model_path: Path to .pt or .pth file
        input_shape: Input tensor shape (NCHW)
        model_class: Model class for state_dict loading
        
    Returns:
        IRGraph
    """
    parser = PyTorchParser()
    return parser.parse(model_path, input_shape, model_class)


def parse_pytorch_module(module,
                         input_shape: Tuple[int, ...] = (1, 3, 224, 224),
                         model_name: str = "model") -> IRGraph:
    """
    Parse PyTorch nn.Module to IR
    
    Args:
        module: PyTorch nn.Module
        input_shape: Input tensor shape (NCHW)
        model_name: Name for the model
        
    Returns:
        IRGraph
    """
    parser = PyTorchParser()
    return parser.parse_module(module, input_shape, model_name)
