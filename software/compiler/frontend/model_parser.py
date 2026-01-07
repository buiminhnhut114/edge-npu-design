"""
EdgeNPU Compiler - Model Parsers
Parse ONNX and TFLite models to IR
"""

from abc import ABC, abstractmethod
from typing import Dict, List, Optional, Any
import numpy as np

from .ir_builder import (
    IRBuilder, IRGraph, IRNode, IRTensor, IROpType, 
    DataType, DataLayout
)


class ModelParser(ABC):
    """Abstract base class for model parsers"""
    
    @abstractmethod
    def parse(self, model_path: str) -> IRGraph:
        """Parse model file and return IR graph"""
        pass
    
    @abstractmethod
    def supported_ops(self) -> List[str]:
        """Return list of supported operations"""
        pass


class ONNXParser(ModelParser):
    """Parser for ONNX models"""
    
    # ONNX op to IR op mapping
    OP_MAP = {
        'Conv': IROpType.CONV2D,
        'ConvTranspose': IROpType.CONV2D,
        'Gemm': IROpType.FULLY_CONNECTED,
        'MatMul': IROpType.MATMUL,
        'Relu': IROpType.RELU,
        'Clip': IROpType.RELU6,  # Clip(0,6) = ReLU6
        'Sigmoid': IROpType.SIGMOID,
        'Tanh': IROpType.TANH,
        'LeakyRelu': IROpType.LEAKY_RELU,
        'Softmax': IROpType.SOFTMAX,
        'MaxPool': IROpType.MAX_POOL2D,
        'AveragePool': IROpType.AVG_POOL2D,
        'GlobalAveragePool': IROpType.GLOBAL_AVG_POOL,
        'Add': IROpType.ADD,
        'Sub': IROpType.SUB,
        'Mul': IROpType.MUL,
        'Div': IROpType.DIV,
        'BatchNormalization': IROpType.BATCH_NORM,
        'Reshape': IROpType.RESHAPE,
        'Transpose': IROpType.TRANSPOSE,
        'Concat': IROpType.CONCAT,
        'Split': IROpType.SPLIT,
        'Pad': IROpType.PAD,
    }
    
    def __init__(self):
        self.onnx = None
        self.numpy_helper = None
        self._load_onnx()
    
    def _load_onnx(self):
        """Load ONNX library"""
        try:
            import onnx
            from onnx import numpy_helper
            self.onnx = onnx
            self.numpy_helper = numpy_helper
        except ImportError:
            pass
    
    def supported_ops(self) -> List[str]:
        return list(self.OP_MAP.keys())
    
    def parse(self, model_path: str) -> IRGraph:
        """Parse ONNX model to IR"""
        if self.onnx is None:
            raise ImportError("ONNX not installed. Run: pip install onnx")
        
        model = self.onnx.load(model_path)
        self.onnx.checker.check_model(model)
        graph = model.graph
        
        builder = IRBuilder(name=graph.name or "onnx_model")
        
        # Extract initializers (weights)
        weights = {}
        for init in graph.initializer:
            data = self.numpy_helper.to_array(init)
            weights[init.name] = data
            builder.add_constant(init.name, data)
        
        # Add graph inputs
        for inp in graph.input:
            if inp.name not in weights:  # Skip weight inputs
                shape = tuple(d.dim_value for d in inp.type.tensor_type.shape.dim)
                builder.add_input(inp.name, shape)
        
        # Process nodes
        for node in graph.node:
            self._parse_node(builder, node, weights)
        
        # Add graph outputs
        for out in graph.output:
            builder.add_output(out.name)
        
        return builder.build()
    
    def _parse_node(self, builder: IRBuilder, node, weights: Dict):
        """Parse single ONNX node"""
        op_type = node.op_type
        
        if op_type not in self.OP_MAP:
            print(f"Warning: Unsupported op '{op_type}', skipping")
            return
        
        ir_op = self.OP_MAP[op_type]
        attrs = self._parse_attributes(node)
        
        if op_type == 'Conv':
            self._parse_conv(builder, node, attrs)
        elif op_type == 'Gemm':
            self._parse_gemm(builder, node, attrs)
        elif op_type in ['Relu', 'Sigmoid', 'Tanh']:
            self._parse_activation(builder, node, ir_op)
        elif op_type in ['MaxPool', 'AveragePool']:
            self._parse_pool(builder, node, ir_op, attrs)
        elif op_type == 'GlobalAveragePool':
            self._parse_global_pool(builder, node)
        elif op_type in ['Add', 'Sub', 'Mul', 'Div']:
            self._parse_eltwise(builder, node, ir_op)
        elif op_type == 'BatchNormalization':
            self._parse_batchnorm(builder, node, attrs)
        elif op_type == 'Reshape':
            self._parse_reshape(builder, node)
        elif op_type == 'Concat':
            self._parse_concat(builder, node, attrs)
        elif op_type == 'Softmax':
            self._parse_softmax(builder, node, attrs)
        else:
            # Generic handling
            self._parse_generic(builder, node, ir_op, attrs)
    
    def _parse_attributes(self, node) -> Dict:
        """Parse ONNX node attributes"""
        attrs = {}
        for attr in node.attribute:
            if attr.type == 1:  # FLOAT
                attrs[attr.name] = attr.f
            elif attr.type == 2:  # INT
                attrs[attr.name] = attr.i
            elif attr.type == 3:  # STRING
                attrs[attr.name] = attr.s.decode()
            elif attr.type == 6:  # FLOATS
                attrs[attr.name] = list(attr.floats)
            elif attr.type == 7:  # INTS
                attrs[attr.name] = list(attr.ints)
        return attrs
    
    def _parse_conv(self, builder: IRBuilder, node, attrs: Dict):
        """Parse Conv node"""
        kernel_shape = attrs.get('kernel_shape', [3, 3])
        strides = attrs.get('strides', [1, 1])
        pads = attrs.get('pads', [0, 0, 0, 0])
        group = attrs.get('group', 1)
        
        input_name = node.input[0]
        weight_name = node.input[1]
        bias_name = node.input[2] if len(node.input) > 2 else None
        
        output = builder.conv2d(
            input_name=input_name,
            weight_name=weight_name,
            bias_name=bias_name,
            kernel_size=(kernel_shape[0], kernel_shape[1]),
            stride=(strides[0], strides[1]),
            padding=(pads[0], pads[1]),
            groups=group
        )
        
        # Map output name
        builder.graph.tensors[node.output[0]] = builder.graph.tensors.pop(output)
        builder.graph.tensors[node.output[0]].name = node.output[0]
        builder.graph.nodes[-1].outputs = [node.output[0]]
    
    def _parse_gemm(self, builder: IRBuilder, node, attrs: Dict):
        """Parse Gemm (FC) node"""
        input_name = node.input[0]
        weight_name = node.input[1]
        bias_name = node.input[2] if len(node.input) > 2 else None
        
        output = builder.fully_connected(
            input_name=input_name,
            weight_name=weight_name,
            bias_name=bias_name
        )
        
        builder.graph.tensors[node.output[0]] = builder.graph.tensors.pop(output)
        builder.graph.tensors[node.output[0]].name = node.output[0]
        builder.graph.nodes[-1].outputs = [node.output[0]]
    
    def _parse_activation(self, builder: IRBuilder, node, ir_op: IROpType):
        """Parse activation node"""
        input_name = node.input[0]
        
        if ir_op == IROpType.RELU:
            output = builder.relu(input_name)
        elif ir_op == IROpType.SIGMOID:
            output = builder.sigmoid(input_name)
        else:
            output = builder._add_activation(input_name, ir_op)
        
        builder.graph.tensors[node.output[0]] = builder.graph.tensors.pop(output)
        builder.graph.tensors[node.output[0]].name = node.output[0]
        builder.graph.nodes[-1].outputs = [node.output[0]]
    
    def _parse_pool(self, builder: IRBuilder, node, ir_op: IROpType, attrs: Dict):
        """Parse pooling node"""
        kernel_shape = attrs.get('kernel_shape', [2, 2])
        strides = attrs.get('strides', [2, 2])
        
        input_name = node.input[0]
        
        if ir_op == IROpType.MAX_POOL2D:
            output = builder.max_pool2d(
                input_name,
                kernel_size=(kernel_shape[0], kernel_shape[1]),
                stride=(strides[0], strides[1])
            )
        else:
            output = builder.avg_pool2d(
                input_name,
                kernel_size=(kernel_shape[0], kernel_shape[1]),
                stride=(strides[0], strides[1])
            )
        
        builder.graph.tensors[node.output[0]] = builder.graph.tensors.pop(output)
        builder.graph.tensors[node.output[0]].name = node.output[0]
        builder.graph.nodes[-1].outputs = [node.output[0]]
    
    def _parse_global_pool(self, builder: IRBuilder, node):
        """Parse global average pool"""
        output = builder.global_avg_pool(node.input[0])
        
        builder.graph.tensors[node.output[0]] = builder.graph.tensors.pop(output)
        builder.graph.tensors[node.output[0]].name = node.output[0]
        builder.graph.nodes[-1].outputs = [node.output[0]]
    
    def _parse_eltwise(self, builder: IRBuilder, node, ir_op: IROpType):
        """Parse element-wise op"""
        if ir_op == IROpType.ADD:
            output = builder.add(node.input[0], node.input[1])
        elif ir_op == IROpType.MUL:
            output = builder.mul(node.input[0], node.input[1])
        else:
            output = builder._add_eltwise(node.input[0], node.input[1], ir_op)
        
        builder.graph.tensors[node.output[0]] = builder.graph.tensors.pop(output)
        builder.graph.tensors[node.output[0]].name = node.output[0]
        builder.graph.nodes[-1].outputs = [node.output[0]]
    
    def _parse_batchnorm(self, builder: IRBuilder, node, attrs: Dict):
        """Parse batch normalization"""
        epsilon = attrs.get('epsilon', 1e-5)
        
        output = builder.batch_norm(
            input_name=node.input[0],
            gamma_name=node.input[1],
            beta_name=node.input[2],
            mean_name=node.input[3],
            var_name=node.input[4],
            epsilon=epsilon
        )
        
        builder.graph.tensors[node.output[0]] = builder.graph.tensors.pop(output)
        builder.graph.tensors[node.output[0]].name = node.output[0]
        builder.graph.nodes[-1].outputs = [node.output[0]]
    
    def _parse_reshape(self, builder: IRBuilder, node):
        """Parse reshape"""
        shape_tensor = builder.graph.get_tensor(node.input[1])
        if shape_tensor and shape_tensor.data is not None:
            new_shape = tuple(shape_tensor.data.astype(int))
        else:
            new_shape = (-1,)
        
        output = builder.reshape(node.input[0], new_shape)
        
        builder.graph.tensors[node.output[0]] = builder.graph.tensors.pop(output)
        builder.graph.tensors[node.output[0]].name = node.output[0]
        builder.graph.nodes[-1].outputs = [node.output[0]]
    
    def _parse_concat(self, builder: IRBuilder, node, attrs: Dict):
        """Parse concat"""
        axis = attrs.get('axis', 1)
        output = builder.concat(list(node.input), axis=axis)
        
        builder.graph.tensors[node.output[0]] = builder.graph.tensors.pop(output)
        builder.graph.tensors[node.output[0]].name = node.output[0]
        builder.graph.nodes[-1].outputs = [node.output[0]]
    
    def _parse_softmax(self, builder: IRBuilder, node, attrs: Dict):
        """Parse softmax"""
        axis = attrs.get('axis', -1)
        output = builder.softmax(node.input[0], axis=axis)
        
        builder.graph.tensors[node.output[0]] = builder.graph.tensors.pop(output)
        builder.graph.tensors[node.output[0]].name = node.output[0]
        builder.graph.nodes[-1].outputs = [node.output[0]]
    
    def _parse_generic(self, builder: IRBuilder, node, ir_op: IROpType, attrs: Dict):
        """Generic node parsing"""
        output_name = node.output[0]
        
        # Create output tensor with unknown shape
        output_tensor = IRTensor(name=output_name, shape=(1,))
        builder.graph.add_tensor(output_tensor)
        
        ir_node = IRNode(
            name=f"{node.op_type}_{len(builder.graph.nodes)}",
            op_type=ir_op,
            inputs=list(node.input),
            outputs=[output_name],
            attrs=attrs
        )
        builder.graph.add_node(ir_node)


class TFLiteParser(ModelParser):
    """Parser for TensorFlow Lite models"""
    
    def __init__(self):
        self.tflite = None
        self._load_tflite()
    
    def _load_tflite(self):
        """Load TFLite library"""
        try:
            import tensorflow as tf
            self.tflite = tf.lite
        except ImportError:
            pass
    
    def supported_ops(self) -> List[str]:
        return [
            'CONV_2D', 'DEPTHWISE_CONV_2D', 'FULLY_CONNECTED',
            'RELU', 'RELU6', 'SOFTMAX',
            'MAX_POOL_2D', 'AVERAGE_POOL_2D',
            'ADD', 'MUL', 'RESHAPE', 'CONCATENATION'
        ]
    
    def parse(self, model_path: str) -> IRGraph:
        """Parse TFLite model to IR"""
        if self.tflite is None:
            raise ImportError("TensorFlow not installed. Run: pip install tensorflow")
        
        # Load model
        with open(model_path, 'rb') as f:
            model_content = f.read()
        
        interpreter = self.tflite.Interpreter(model_content=model_content)
        interpreter.allocate_tensors()
        
        builder = IRBuilder(name="tflite_model")
        
        # Get input/output details
        input_details = interpreter.get_input_details()
        output_details = interpreter.get_output_details()
        tensor_details = interpreter.get_tensor_details()
        
        # Add inputs
        for inp in input_details:
            shape = tuple(inp['shape'])
            builder.add_input(inp['name'], shape)
        
        # Process tensors
        for tensor in tensor_details:
            name = tensor['name']
            shape = tuple(tensor['shape'])
            
            # Check if it's a constant (weight)
            try:
                data = interpreter.get_tensor(tensor['index'])
                if data is not None and name not in [i['name'] for i in input_details]:
                    builder.add_constant(name, data)
            except:
                pass
        
        # Add outputs
        for out in output_details:
            builder.add_output(out['name'])
        
        return builder.build()


def create_parser(model_path: str) -> ModelParser:
    """Factory function to create appropriate parser"""
    if model_path.endswith('.onnx'):
        return ONNXParser()
    elif model_path.endswith('.tflite'):
        return TFLiteParser()
    elif model_path.endswith('.pt') or model_path.endswith('.pth'):
        from .pytorch_parser import PyTorchParser
        return PyTorchParser()
    else:
        raise ValueError(f"Unsupported model format: {model_path}")


def parse_model(model_path: str, 
                input_shape: tuple = (1, 3, 224, 224),
                model_class=None) -> IRGraph:
    """
    Universal model parser - automatically detects format
    
    Args:
        model_path: Path to model file (.onnx, .tflite, .pt, .pth)
        input_shape: Input tensor shape (for PyTorch tracing)
        model_class: Model class (for PyTorch state_dict loading)
        
    Returns:
        IRGraph representation
    """
    if model_path.endswith('.onnx'):
        parser = ONNXParser()
        return parser.parse(model_path)
    elif model_path.endswith('.tflite'):
        parser = TFLiteParser()
        return parser.parse(model_path)
    elif model_path.endswith('.pt') or model_path.endswith('.pth'):
        from .pytorch_parser import PyTorchParser
        parser = PyTorchParser()
        return parser.parse(model_path, input_shape, model_class)
    else:
        raise ValueError(f"Unsupported model format: {model_path}")
