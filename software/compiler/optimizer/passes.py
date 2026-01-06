"""
EdgeNPU Compiler - Optimization Passes
Individual optimization transformations
"""

from abc import ABC, abstractmethod
from typing import List, Optional, Set
import numpy as np

from ..frontend.ir_builder import IRGraph, IRNode, IRTensor, IROpType, DataType


class OptimizationPass(ABC):
    """Base class for optimization passes"""
    
    name: str = "base_pass"
    
    @abstractmethod
    def run(self, graph: IRGraph) -> IRGraph:
        """Run optimization pass on graph"""
        pass
    
    def __repr__(self):
        return f"{self.__class__.__name__}()"


class FuseConvBNPass(OptimizationPass):
    """Fuse Conv2D + BatchNorm into single Conv2D"""
    
    name = "fuse_conv_bn"
    
    def run(self, graph: IRGraph) -> IRGraph:
        nodes_to_remove = []
        
        for node in graph.nodes:
            if node.op_type != IROpType.BATCH_NORM:
                continue
            
            # Find producer conv
            bn_input = node.inputs[0]
            producers = graph.get_producers(bn_input)
            
            if not producers:
                continue
                
            conv_node = producers[0]
            if conv_node.op_type not in [IROpType.CONV2D, IROpType.DEPTHWISE_CONV2D]:
                continue
            
            # Check if conv output is only used by this BN
            consumers = graph.get_consumers(bn_input)
            if len(consumers) != 1:
                continue
            
            # Fuse BN into Conv
            self._fuse_bn_into_conv(graph, conv_node, node)
            
            # Update conv output to BN output
            conv_node.outputs = node.outputs
            nodes_to_remove.append(node)
        
        # Remove fused BN nodes
        for node in nodes_to_remove:
            graph.nodes.remove(node)
        
        return graph
    
    def _fuse_bn_into_conv(self, graph: IRGraph, conv: IRNode, bn: IRNode):
        """Fuse batch norm parameters into conv weights"""
        # Get BN parameters
        gamma = graph.get_tensor(bn.inputs[1])
        beta = graph.get_tensor(bn.inputs[2])
        mean = graph.get_tensor(bn.inputs[3])
        var = graph.get_tensor(bn.inputs[4])
        epsilon = bn.get_attr('epsilon', 1e-5)
        
        if not all([gamma, beta, mean, var]):
            return
        
        if not all([t.data is not None for t in [gamma, beta, mean, var]]):
            return
        
        # Get conv weight and bias
        weight_tensor = graph.get_tensor(conv.inputs[1])
        bias_tensor = graph.get_tensor(conv.inputs[2]) if len(conv.inputs) > 2 else None
        
        if weight_tensor is None or weight_tensor.data is None:
            return
        
        weight = weight_tensor.data
        bias = bias_tensor.data if bias_tensor and bias_tensor.data is not None else np.zeros(weight.shape[0])
        
        # Compute fused parameters
        # new_weight = weight * gamma / sqrt(var + eps)
        # new_bias = (bias - mean) * gamma / sqrt(var + eps) + beta
        
        scale = gamma.data / np.sqrt(var.data + epsilon)
        
        # Reshape scale for broadcasting
        if len(weight.shape) == 4:  # Conv2D: [out_ch, in_ch, kh, kw]
            scale_shape = [weight.shape[0], 1, 1, 1]
        else:
            scale_shape = [weight.shape[0], 1]
        
        new_weight = weight * scale.reshape(scale_shape)
        new_bias = (bias - mean.data) * scale + beta.data
        
        # Update tensors
        weight_tensor.data = new_weight
        
        if bias_tensor:
            bias_tensor.data = new_bias
        else:
            # Create new bias tensor
            bias_name = f"{conv.name}_bias"
            new_bias_tensor = IRTensor(
                name=bias_name,
                shape=new_bias.shape,
                data=new_bias
            )
            graph.add_tensor(new_bias_tensor)
            conv.inputs.append(bias_name)


class FuseConvReluPass(OptimizationPass):
    """Fuse Conv2D + ReLU into single Conv2D with activation"""
    
    name = "fuse_conv_relu"
    
    FUSABLE_ACTIVATIONS = {
        IROpType.RELU: 'relu',
        IROpType.RELU6: 'relu6',
        IROpType.SIGMOID: 'sigmoid',
        IROpType.TANH: 'tanh',
    }
    
    def run(self, graph: IRGraph) -> IRGraph:
        nodes_to_remove = []
        
        for node in graph.nodes:
            if node.op_type not in self.FUSABLE_ACTIVATIONS:
                continue
            
            # Find producer
            act_input = node.inputs[0]
            producers = graph.get_producers(act_input)
            
            if not producers:
                continue
            
            producer = producers[0]
            if producer.op_type not in [IROpType.CONV2D, IROpType.DEPTHWISE_CONV2D, 
                                         IROpType.FULLY_CONNECTED]:
                continue
            
            # Check if producer output is only used by this activation
            consumers = graph.get_consumers(act_input)
            if len(consumers) != 1:
                continue
            
            # Check if producer already has activation
            if producer.get_attr('activation'):
                continue
            
            # Fuse activation into producer
            producer.set_attr('activation', self.FUSABLE_ACTIVATIONS[node.op_type])
            producer.outputs = node.outputs
            
            nodes_to_remove.append(node)
        
        # Remove fused activation nodes
        for node in nodes_to_remove:
            graph.nodes.remove(node)
        
        return graph


class ConstantFoldingPass(OptimizationPass):
    """Fold constant expressions at compile time"""
    
    name = "constant_folding"
    
    def run(self, graph: IRGraph) -> IRGraph:
        changed = True
        
        while changed:
            changed = False
            
            for node in graph.nodes:
                if self._can_fold(graph, node):
                    self._fold_node(graph, node)
                    changed = True
                    break
        
        return graph
    
    def _can_fold(self, graph: IRGraph, node: IRNode) -> bool:
        """Check if node can be constant folded"""
        # All inputs must be constants
        for inp in node.inputs:
            tensor = graph.get_tensor(inp)
            if tensor is None or tensor.data is None:
                return False
        
        # Must be a foldable operation
        foldable_ops = {
            IROpType.ADD, IROpType.SUB, IROpType.MUL, IROpType.DIV,
            IROpType.RESHAPE, IROpType.TRANSPOSE,
        }
        
        return node.op_type in foldable_ops
    
    def _fold_node(self, graph: IRGraph, node: IRNode):
        """Fold constant node"""
        inputs = [graph.get_tensor(inp).data for inp in node.inputs]
        
        if node.op_type == IROpType.ADD:
            result = inputs[0] + inputs[1]
        elif node.op_type == IROpType.SUB:
            result = inputs[0] - inputs[1]
        elif node.op_type == IROpType.MUL:
            result = inputs[0] * inputs[1]
        elif node.op_type == IROpType.DIV:
            result = inputs[0] / inputs[1]
        elif node.op_type == IROpType.RESHAPE:
            shape = node.get_attr('shape', (-1,))
            result = inputs[0].reshape(shape)
        elif node.op_type == IROpType.TRANSPOSE:
            perm = node.get_attr('perm')
            result = np.transpose(inputs[0], perm)
        else:
            return
        
        # Update output tensor with computed result
        output_name = node.outputs[0]
        output_tensor = graph.get_tensor(output_name)
        if output_tensor:
            output_tensor.data = result
            output_tensor.shape = tuple(result.shape)
        
        # Remove node from graph
        graph.nodes.remove(node)


class DeadCodeEliminationPass(OptimizationPass):
    """Remove unused nodes and tensors"""
    
    name = "dead_code_elimination"
    
    def run(self, graph: IRGraph) -> IRGraph:
        # Find all tensors that are used
        used_tensors: Set[str] = set(graph.outputs)
        
        # Backward pass to find all required tensors
        changed = True
        while changed:
            changed = False
            for node in graph.nodes:
                # If any output is used, all inputs are used
                if any(out in used_tensors for out in node.outputs):
                    for inp in node.inputs:
                        if inp not in used_tensors:
                            used_tensors.add(inp)
                            changed = True
        
        # Add graph inputs
        used_tensors.update(graph.inputs)
        
        # Remove unused nodes
        nodes_to_keep = []
        for node in graph.nodes:
            if any(out in used_tensors for out in node.outputs):
                nodes_to_keep.append(node)
        
        graph.nodes = nodes_to_keep
        
        # Remove unused tensors
        tensors_to_remove = [name for name in graph.tensors if name not in used_tensors]
        for name in tensors_to_remove:
            del graph.tensors[name]
        
        return graph


class LayoutOptimizationPass(OptimizationPass):
    """Optimize tensor layouts for NPU"""
    
    name = "layout_optimization"
    
    def run(self, graph: IRGraph) -> IRGraph:
        # NPU prefers NHWC layout for activations
        # and specific layouts for weights
        
        for node in graph.nodes:
            if node.op_type in [IROpType.CONV2D, IROpType.DEPTHWISE_CONV2D]:
                self._optimize_conv_layout(graph, node)
            elif node.op_type == IROpType.FULLY_CONNECTED:
                self._optimize_fc_layout(graph, node)
        
        return graph
    
    def _optimize_conv_layout(self, graph: IRGraph, node: IRNode):
        """Optimize conv layout"""
        # Mark preferred layout in node attributes
        node.set_attr('input_layout', 'NHWC')
        node.set_attr('weight_layout', 'OHWI')  # Out, H, W, In
        node.set_attr('output_layout', 'NHWC')
    
    def _optimize_fc_layout(self, graph: IRGraph, node: IRNode):
        """Optimize FC layout"""
        node.set_attr('input_layout', 'NC')
        node.set_attr('weight_layout', 'OI')  # Out, In
        node.set_attr('output_layout', 'NC')


class TilingPass(OptimizationPass):
    """Compute optimal tiling for NPU execution"""
    
    name = "tiling"
    
    def __init__(self, pe_rows: int = 16, pe_cols: int = 16,
                 weight_buf_kb: int = 256, act_buf_kb: int = 256):
        self.pe_rows = pe_rows
        self.pe_cols = pe_cols
        self.weight_buf_size = weight_buf_kb * 1024
        self.act_buf_size = act_buf_kb * 1024
    
    def run(self, graph: IRGraph) -> IRGraph:
        for node in graph.nodes:
            if node.op_type in [IROpType.CONV2D, IROpType.DEPTHWISE_CONV2D]:
                self._compute_conv_tiling(graph, node)
            elif node.op_type == IROpType.FULLY_CONNECTED:
                self._compute_fc_tiling(graph, node)
        
        return graph
    
    def _compute_conv_tiling(self, graph: IRGraph, node: IRNode):
        """Compute tiling for convolution"""
        weight_tensor = graph.get_tensor(node.inputs[1])
        if not weight_tensor:
            return
        
        out_ch, in_ch, kh, kw = weight_tensor.shape
        
        # Tile output channels to fit PE array
        tile_oc = min(out_ch, self.pe_cols)
        
        # Tile input channels
        tile_ic = min(in_ch, self.pe_rows)
        
        # Calculate weight tile size
        weight_tile_size = tile_oc * tile_ic * kh * kw
        
        # Adjust if doesn't fit in buffer
        while weight_tile_size > self.weight_buf_size and tile_oc > 1:
            tile_oc //= 2
            weight_tile_size = tile_oc * tile_ic * kh * kw
        
        node.tile_config = {
            'tile_oc': tile_oc,
            'tile_ic': tile_ic,
            'tile_oh': 1,  # Output height tile
            'tile_ow': 1,  # Output width tile
        }
    
    def _compute_fc_tiling(self, graph: IRGraph, node: IRNode):
        """Compute tiling for fully connected"""
        weight_tensor = graph.get_tensor(node.inputs[1])
        if not weight_tensor:
            return
        
        out_features, in_features = weight_tensor.shape
        
        tile_out = min(out_features, self.pe_cols)
        tile_in = min(in_features, self.pe_rows)
        
        node.tile_config = {
            'tile_out': tile_out,
            'tile_in': tile_in,
        }
