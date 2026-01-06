"""
EdgeNPU Compiler - Intermediate Representation (IR)
Graph-based IR for neural network representation
"""

from dataclasses import dataclass, field
from enum import Enum, auto
from typing import List, Dict, Optional, Tuple, Any
import numpy as np


class IROpType(Enum):
    """IR operation types"""
    # Compute ops
    CONV2D = auto()
    DEPTHWISE_CONV2D = auto()
    FULLY_CONNECTED = auto()
    MATMUL = auto()
    
    # Activation ops
    RELU = auto()
    RELU6 = auto()
    SIGMOID = auto()
    TANH = auto()
    LEAKY_RELU = auto()
    SWISH = auto()
    GELU = auto()
    SOFTMAX = auto()
    
    # Pooling ops
    MAX_POOL2D = auto()
    AVG_POOL2D = auto()
    GLOBAL_AVG_POOL = auto()
    
    # Element-wise ops
    ADD = auto()
    SUB = auto()
    MUL = auto()
    DIV = auto()
    
    # Normalization ops
    BATCH_NORM = auto()
    LAYER_NORM = auto()
    
    # Shape ops
    RESHAPE = auto()
    TRANSPOSE = auto()
    CONCAT = auto()
    SPLIT = auto()
    PAD = auto()
    
    # Data ops
    INPUT = auto()
    OUTPUT = auto()
    CONSTANT = auto()


class DataType(Enum):
    """Data types"""
    FLOAT32 = auto()
    FLOAT16 = auto()
    INT32 = auto()
    INT16 = auto()
    INT8 = auto()
    UINT8 = auto()


class DataLayout(Enum):
    """Tensor data layouts"""
    NCHW = auto()  # Batch, Channel, Height, Width
    NHWC = auto()  # Batch, Height, Width, Channel
    NC = auto()    # Batch, Channel (for FC)
    

@dataclass
class IRTensor:
    """IR tensor representation"""
    name: str
    shape: Tuple[int, ...]
    dtype: DataType = DataType.FLOAT32
    layout: DataLayout = DataLayout.NCHW
    data: Optional[np.ndarray] = None
    
    # Quantization info
    scale: float = 1.0
    zero_point: int = 0
    is_quantized: bool = False
    
    def __post_init__(self):
        if self.data is not None and not isinstance(self.shape, tuple):
            self.shape = tuple(self.data.shape)
    
    @property
    def size(self) -> int:
        """Total number of elements"""
        result = 1
        for dim in self.shape:
            result *= dim
        return result
    
    @property
    def nbytes(self) -> int:
        """Size in bytes"""
        dtype_sizes = {
            DataType.FLOAT32: 4,
            DataType.FLOAT16: 2,
            DataType.INT32: 4,
            DataType.INT16: 2,
            DataType.INT8: 1,
            DataType.UINT8: 1,
        }
        return self.size * dtype_sizes.get(self.dtype, 4)
    
    def quantize(self, target_dtype: DataType = DataType.INT8) -> 'IRTensor':
        """Quantize tensor to target dtype"""
        if self.data is None:
            return self
            
        if target_dtype == DataType.INT8:
            max_val = np.max(np.abs(self.data))
            scale = max_val / 127.0 if max_val > 0 else 1.0
            zero_point = 0
            quantized_data = np.clip(np.round(self.data / scale), -128, 127).astype(np.int8)
        elif target_dtype == DataType.UINT8:
            min_val, max_val = np.min(self.data), np.max(self.data)
            scale = (max_val - min_val) / 255.0 if max_val > min_val else 1.0
            zero_point = int(-min_val / scale)
            quantized_data = np.clip(np.round(self.data / scale + zero_point), 0, 255).astype(np.uint8)
        else:
            return self
            
        return IRTensor(
            name=self.name,
            shape=self.shape,
            dtype=target_dtype,
            layout=self.layout,
            data=quantized_data,
            scale=scale,
            zero_point=zero_point,
            is_quantized=True
        )


@dataclass
class IRNode:
    """IR graph node representing an operation"""
    name: str
    op_type: IROpType
    inputs: List[str] = field(default_factory=list)
    outputs: List[str] = field(default_factory=list)
    attrs: Dict[str, Any] = field(default_factory=dict)
    
    # Scheduling info (filled by optimizer)
    schedule_order: int = -1
    tile_config: Optional[Dict] = None
    
    def __repr__(self):
        return f"IRNode({self.name}, {self.op_type.name}, in={self.inputs}, out={self.outputs})"
    
    def get_attr(self, key: str, default: Any = None) -> Any:
        return self.attrs.get(key, default)
    
    def set_attr(self, key: str, value: Any):
        self.attrs[key] = value


@dataclass
class IRGraph:
    """IR graph representing the neural network"""
    name: str = "model"
    nodes: List[IRNode] = field(default_factory=list)
    tensors: Dict[str, IRTensor] = field(default_factory=dict)
    inputs: List[str] = field(default_factory=list)
    outputs: List[str] = field(default_factory=list)
    
    def add_node(self, node: IRNode):
        """Add node to graph"""
        self.nodes.append(node)
        
    def add_tensor(self, tensor: IRTensor):
        """Add tensor to graph"""
        self.tensors[tensor.name] = tensor
        
    def get_node(self, name: str) -> Optional[IRNode]:
        """Get node by name"""
        for node in self.nodes:
            if node.name == name:
                return node
        return None
    
    def get_tensor(self, name: str) -> Optional[IRTensor]:
        """Get tensor by name"""
        return self.tensors.get(name)
    
    def get_node_inputs(self, node: IRNode) -> List[IRTensor]:
        """Get input tensors for a node"""
        return [self.tensors[name] for name in node.inputs if name in self.tensors]
    
    def get_node_outputs(self, node: IRNode) -> List[IRTensor]:
        """Get output tensors for a node"""
        return [self.tensors[name] for name in node.outputs if name in self.tensors]
    
    def get_producers(self, tensor_name: str) -> List[IRNode]:
        """Get nodes that produce this tensor"""
        return [n for n in self.nodes if tensor_name in n.outputs]
    
    def get_consumers(self, tensor_name: str) -> List[IRNode]:
        """Get nodes that consume this tensor"""
        return [n for n in self.nodes if tensor_name in n.inputs]
    
    def topological_sort(self) -> List[IRNode]:
        """Return nodes in topological order"""
        visited = set()
        order = []
        
        def visit(node: IRNode):
            if node.name in visited:
                return
            visited.add(node.name)
            
            # Visit all input producers first
            for inp in node.inputs:
                for producer in self.get_producers(inp):
                    visit(producer)
            
            order.append(node)
        
        for node in self.nodes:
            visit(node)
            
        return order
    
    def validate(self) -> List[str]:
        """Validate graph structure, return list of errors"""
        errors = []
        
        # Check all node inputs exist
        for node in self.nodes:
            for inp in node.inputs:
                if inp not in self.tensors:
                    errors.append(f"Node {node.name}: input tensor '{inp}' not found")
            for out in node.outputs:
                if out not in self.tensors:
                    errors.append(f"Node {node.name}: output tensor '{out}' not found")
        
        # Check graph inputs/outputs
        for inp in self.inputs:
            if inp not in self.tensors:
                errors.append(f"Graph input '{inp}' not found in tensors")
        for out in self.outputs:
            if out not in self.tensors:
                errors.append(f"Graph output '{out}' not found in tensors")
        
        return errors
    
    def summary(self) -> str:
        """Generate graph summary"""
        lines = [
            f"IR Graph: {self.name}",
            f"  Nodes: {len(self.nodes)}",
            f"  Tensors: {len(self.tensors)}",
            f"  Inputs: {self.inputs}",
            f"  Outputs: {self.outputs}",
            "",
            "Nodes:"
        ]
        
        for node in self.topological_sort():
            lines.append(f"  {node.name}: {node.op_type.name}")
            lines.append(f"    inputs: {node.inputs}")
            lines.append(f"    outputs: {node.outputs}")
            if node.attrs:
                lines.append(f"    attrs: {node.attrs}")
        
        return "\n".join(lines)


class IRBuilder:
    """Builder for constructing IR graphs"""
    
    def __init__(self, name: str = "model"):
        self.graph = IRGraph(name=name)
        self._tensor_counter = 0
        self._node_counter = 0
        
    def _gen_tensor_name(self, prefix: str = "t") -> str:
        name = f"{prefix}_{self._tensor_counter}"
        self._tensor_counter += 1
        return name
    
    def _gen_node_name(self, prefix: str = "n") -> str:
        name = f"{prefix}_{self._node_counter}"
        self._node_counter += 1
        return name
    
    def add_input(self, name: str, shape: Tuple[int, ...], 
                  dtype: DataType = DataType.FLOAT32) -> str:
        """Add graph input"""
        tensor = IRTensor(name=name, shape=shape, dtype=dtype)
        self.graph.add_tensor(tensor)
        self.graph.inputs.append(name)
        return name
    
    def add_output(self, tensor_name: str):
        """Mark tensor as graph output"""
        self.graph.outputs.append(tensor_name)
    
    def add_constant(self, name: str, data: np.ndarray) -> str:
        """Add constant tensor"""
        tensor = IRTensor(
            name=name,
            shape=tuple(data.shape),
            dtype=DataType.FLOAT32,
            data=data
        )
        self.graph.add_tensor(tensor)
        return name
    
    def conv2d(self, input_name: str, weight_name: str, 
               bias_name: Optional[str] = None,
               kernel_size: Tuple[int, int] = (3, 3),
               stride: Tuple[int, int] = (1, 1),
               padding: Tuple[int, int] = (1, 1),
               groups: int = 1,
               activation: Optional[str] = None) -> str:
        """Add Conv2D operation"""
        output_name = self._gen_tensor_name("conv_out")
        node_name = self._gen_node_name("conv2d")
        
        inputs = [input_name, weight_name]
        if bias_name:
            inputs.append(bias_name)
        
        # Calculate output shape
        input_tensor = self.graph.get_tensor(input_name)
        weight_tensor = self.graph.get_tensor(weight_name)
        
        if input_tensor and weight_tensor:
            n, c, h, w = input_tensor.shape
            out_c = weight_tensor.shape[0]
            out_h = (h + 2 * padding[0] - kernel_size[0]) // stride[0] + 1
            out_w = (w + 2 * padding[1] - kernel_size[1]) // stride[1] + 1
            output_shape = (n, out_c, out_h, out_w)
        else:
            output_shape = (1, 1, 1, 1)
        
        output_tensor = IRTensor(name=output_name, shape=output_shape)
        self.graph.add_tensor(output_tensor)
        
        op_type = IROpType.DEPTHWISE_CONV2D if groups > 1 else IROpType.CONV2D
        
        node = IRNode(
            name=node_name,
            op_type=op_type,
            inputs=inputs,
            outputs=[output_name],
            attrs={
                'kernel_size': kernel_size,
                'stride': stride,
                'padding': padding,
                'groups': groups,
                'activation': activation,
            }
        )
        self.graph.add_node(node)
        
        return output_name
    
    def fully_connected(self, input_name: str, weight_name: str,
                        bias_name: Optional[str] = None,
                        activation: Optional[str] = None) -> str:
        """Add Fully Connected operation"""
        output_name = self._gen_tensor_name("fc_out")
        node_name = self._gen_node_name("fc")
        
        inputs = [input_name, weight_name]
        if bias_name:
            inputs.append(bias_name)
        
        # Calculate output shape
        weight_tensor = self.graph.get_tensor(weight_name)
        input_tensor = self.graph.get_tensor(input_name)
        
        if weight_tensor and input_tensor:
            batch = input_tensor.shape[0]
            out_features = weight_tensor.shape[0]
            output_shape = (batch, out_features)
        else:
            output_shape = (1, 1)
        
        output_tensor = IRTensor(name=output_name, shape=output_shape)
        self.graph.add_tensor(output_tensor)
        
        node = IRNode(
            name=node_name,
            op_type=IROpType.FULLY_CONNECTED,
            inputs=inputs,
            outputs=[output_name],
            attrs={'activation': activation}
        )
        self.graph.add_node(node)
        
        return output_name
    
    def relu(self, input_name: str) -> str:
        """Add ReLU activation"""
        return self._add_activation(input_name, IROpType.RELU)
    
    def relu6(self, input_name: str) -> str:
        """Add ReLU6 activation"""
        return self._add_activation(input_name, IROpType.RELU6)
    
    def sigmoid(self, input_name: str) -> str:
        """Add Sigmoid activation"""
        return self._add_activation(input_name, IROpType.SIGMOID)
    
    def softmax(self, input_name: str, axis: int = -1) -> str:
        """Add Softmax"""
        output_name = self._gen_tensor_name("softmax_out")
        node_name = self._gen_node_name("softmax")
        
        input_tensor = self.graph.get_tensor(input_name)
        output_tensor = IRTensor(
            name=output_name,
            shape=input_tensor.shape if input_tensor else (1,)
        )
        self.graph.add_tensor(output_tensor)
        
        node = IRNode(
            name=node_name,
            op_type=IROpType.SOFTMAX,
            inputs=[input_name],
            outputs=[output_name],
            attrs={'axis': axis}
        )
        self.graph.add_node(node)
        
        return output_name
    
    def _add_activation(self, input_name: str, op_type: IROpType) -> str:
        """Helper to add activation ops"""
        output_name = self._gen_tensor_name(f"{op_type.name.lower()}_out")
        node_name = self._gen_node_name(op_type.name.lower())
        
        input_tensor = self.graph.get_tensor(input_name)
        output_tensor = IRTensor(
            name=output_name,
            shape=input_tensor.shape if input_tensor else (1,)
        )
        self.graph.add_tensor(output_tensor)
        
        node = IRNode(
            name=node_name,
            op_type=op_type,
            inputs=[input_name],
            outputs=[output_name]
        )
        self.graph.add_node(node)
        
        return output_name
    
    def max_pool2d(self, input_name: str, 
                   kernel_size: Tuple[int, int] = (2, 2),
                   stride: Tuple[int, int] = (2, 2)) -> str:
        """Add MaxPool2D"""
        return self._add_pool(input_name, IROpType.MAX_POOL2D, kernel_size, stride)
    
    def avg_pool2d(self, input_name: str,
                   kernel_size: Tuple[int, int] = (2, 2),
                   stride: Tuple[int, int] = (2, 2)) -> str:
        """Add AvgPool2D"""
        return self._add_pool(input_name, IROpType.AVG_POOL2D, kernel_size, stride)
    
    def global_avg_pool(self, input_name: str) -> str:
        """Add Global Average Pooling"""
        output_name = self._gen_tensor_name("gap_out")
        node_name = self._gen_node_name("global_avg_pool")
        
        input_tensor = self.graph.get_tensor(input_name)
        if input_tensor:
            n, c, h, w = input_tensor.shape
            output_shape = (n, c, 1, 1)
        else:
            output_shape = (1, 1, 1, 1)
        
        output_tensor = IRTensor(name=output_name, shape=output_shape)
        self.graph.add_tensor(output_tensor)
        
        node = IRNode(
            name=node_name,
            op_type=IROpType.GLOBAL_AVG_POOL,
            inputs=[input_name],
            outputs=[output_name]
        )
        self.graph.add_node(node)
        
        return output_name
    
    def _add_pool(self, input_name: str, op_type: IROpType,
                  kernel_size: Tuple[int, int],
                  stride: Tuple[int, int]) -> str:
        """Helper to add pooling ops"""
        output_name = self._gen_tensor_name("pool_out")
        node_name = self._gen_node_name("pool")
        
        input_tensor = self.graph.get_tensor(input_name)
        if input_tensor:
            n, c, h, w = input_tensor.shape
            out_h = (h - kernel_size[0]) // stride[0] + 1
            out_w = (w - kernel_size[1]) // stride[1] + 1
            output_shape = (n, c, out_h, out_w)
        else:
            output_shape = (1, 1, 1, 1)
        
        output_tensor = IRTensor(name=output_name, shape=output_shape)
        self.graph.add_tensor(output_tensor)
        
        node = IRNode(
            name=node_name,
            op_type=op_type,
            inputs=[input_name],
            outputs=[output_name],
            attrs={
                'kernel_size': kernel_size,
                'stride': stride
            }
        )
        self.graph.add_node(node)
        
        return output_name
    
    def add(self, input1_name: str, input2_name: str) -> str:
        """Add element-wise addition"""
        return self._add_eltwise(input1_name, input2_name, IROpType.ADD)
    
    def mul(self, input1_name: str, input2_name: str) -> str:
        """Add element-wise multiplication"""
        return self._add_eltwise(input1_name, input2_name, IROpType.MUL)
    
    def _add_eltwise(self, input1_name: str, input2_name: str, 
                     op_type: IROpType) -> str:
        """Helper to add element-wise ops"""
        output_name = self._gen_tensor_name(f"{op_type.name.lower()}_out")
        node_name = self._gen_node_name(op_type.name.lower())
        
        input_tensor = self.graph.get_tensor(input1_name)
        output_tensor = IRTensor(
            name=output_name,
            shape=input_tensor.shape if input_tensor else (1,)
        )
        self.graph.add_tensor(output_tensor)
        
        node = IRNode(
            name=node_name,
            op_type=op_type,
            inputs=[input1_name, input2_name],
            outputs=[output_name]
        )
        self.graph.add_node(node)
        
        return output_name
    
    def reshape(self, input_name: str, new_shape: Tuple[int, ...]) -> str:
        """Add reshape operation"""
        output_name = self._gen_tensor_name("reshape_out")
        node_name = self._gen_node_name("reshape")
        
        output_tensor = IRTensor(name=output_name, shape=new_shape)
        self.graph.add_tensor(output_tensor)
        
        node = IRNode(
            name=node_name,
            op_type=IROpType.RESHAPE,
            inputs=[input_name],
            outputs=[output_name],
            attrs={'shape': new_shape}
        )
        self.graph.add_node(node)
        
        return output_name
    
    def batch_norm(self, input_name: str, gamma_name: str, beta_name: str,
                   mean_name: str, var_name: str, epsilon: float = 1e-5) -> str:
        """Add batch normalization"""
        output_name = self._gen_tensor_name("bn_out")
        node_name = self._gen_node_name("batch_norm")
        
        input_tensor = self.graph.get_tensor(input_name)
        output_tensor = IRTensor(
            name=output_name,
            shape=input_tensor.shape if input_tensor else (1,)
        )
        self.graph.add_tensor(output_tensor)
        
        node = IRNode(
            name=node_name,
            op_type=IROpType.BATCH_NORM,
            inputs=[input_name, gamma_name, beta_name, mean_name, var_name],
            outputs=[output_name],
            attrs={'epsilon': epsilon}
        )
        self.graph.add_node(node)
        
        return output_name
    
    def concat(self, input_names: List[str], axis: int = 1) -> str:
        """Add concatenation"""
        output_name = self._gen_tensor_name("concat_out")
        node_name = self._gen_node_name("concat")
        
        # Calculate output shape
        shapes = [self.graph.get_tensor(n).shape for n in input_names 
                  if self.graph.get_tensor(n)]
        if shapes:
            output_shape = list(shapes[0])
            output_shape[axis] = sum(s[axis] for s in shapes)
            output_shape = tuple(output_shape)
        else:
            output_shape = (1,)
        
        output_tensor = IRTensor(name=output_name, shape=output_shape)
        self.graph.add_tensor(output_tensor)
        
        node = IRNode(
            name=node_name,
            op_type=IROpType.CONCAT,
            inputs=input_names,
            outputs=[output_name],
            attrs={'axis': axis}
        )
        self.graph.add_node(node)
        
        return output_name
    
    def build(self) -> IRGraph:
        """Build and return the IR graph"""
        errors = self.graph.validate()
        if errors:
            raise ValueError(f"Graph validation failed:\n" + "\n".join(errors))
        return self.graph
