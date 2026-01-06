"""
EdgeNPU Compiler - Quantizer
Post-training quantization for INT8 inference
"""

from typing import List, Dict, Optional, Tuple, Callable
from dataclasses import dataclass, field
import numpy as np

from ..frontend.ir_builder import IRGraph, IRNode, IRTensor, IROpType, DataType


@dataclass
class CalibrationData:
    """Calibration data for quantization"""
    input_data: List[np.ndarray] = field(default_factory=list)
    num_samples: int = 0
    
    def add_sample(self, data: np.ndarray):
        """Add calibration sample"""
        self.input_data.append(data)
        self.num_samples += 1
    
    def get_batched(self, batch_size: int = 32) -> List[np.ndarray]:
        """Get data in batches"""
        batches = []
        for i in range(0, len(self.input_data), batch_size):
            batch = np.stack(self.input_data[i:i+batch_size])
            batches.append(batch)
        return batches


@dataclass
class QuantizationConfig:
    """Quantization configuration"""
    # Target data type
    weight_dtype: DataType = DataType.INT8
    activation_dtype: DataType = DataType.INT8
    
    # Quantization method
    per_channel_weights: bool = True
    symmetric_weights: bool = True
    symmetric_activations: bool = False
    
    # Calibration
    calibration_method: str = "minmax"  # minmax, percentile, entropy
    percentile: float = 99.99
    
    # Ops to quantize
    quantize_ops: List[IROpType] = field(default_factory=lambda: [
        IROpType.CONV2D,
        IROpType.DEPTHWISE_CONV2D,
        IROpType.FULLY_CONNECTED,
    ])


class Quantizer:
    """
    Post-training quantizer for NPU
    Converts float32 model to int8
    """
    
    def __init__(self, config: Optional[QuantizationConfig] = None):
        self.config = config or QuantizationConfig()
        self.calibration_stats: Dict[str, Dict] = {}
        self.scale_map: Dict[str, float] = {}
        self.zero_point_map: Dict[str, int] = {}
    
    def calibrate(self, graph: IRGraph, calibration_data: CalibrationData,
                  forward_fn: Optional[Callable] = None):
        """
        Calibrate quantization parameters using calibration data
        
        Args:
            graph: IR graph to calibrate
            calibration_data: Calibration dataset
            forward_fn: Optional forward function for inference
        """
        print(f"Calibrating with {calibration_data.num_samples} samples...")
        
        # Initialize stats for each tensor
        for name, tensor in graph.tensors.items():
            self.calibration_stats[name] = {
                'min': float('inf'),
                'max': float('-inf'),
                'values': [],
            }
        
        # Collect activation statistics
        # In a real implementation, this would run inference
        # For now, we'll use the tensor data if available
        for name, tensor in graph.tensors.items():
            if tensor.data is not None:
                data = tensor.data.flatten()
                self.calibration_stats[name]['min'] = min(
                    self.calibration_stats[name]['min'],
                    float(np.min(data))
                )
                self.calibration_stats[name]['max'] = max(
                    self.calibration_stats[name]['max'],
                    float(np.max(data))
                )
                self.calibration_stats[name]['values'].extend(
                    data[:1000].tolist()  # Sample for histogram
                )
        
        # Compute quantization parameters
        self._compute_quant_params()
    
    def _compute_quant_params(self):
        """Compute scale and zero point for each tensor"""
        for name, stats in self.calibration_stats.items():
            if stats['min'] == float('inf'):
                # No data collected, use defaults
                self.scale_map[name] = 1.0
                self.zero_point_map[name] = 0
                continue
            
            min_val = stats['min']
            max_val = stats['max']
            
            if self.config.calibration_method == 'percentile':
                values = np.array(stats['values'])
                if len(values) > 0:
                    min_val = np.percentile(values, 100 - self.config.percentile)
                    max_val = np.percentile(values, self.config.percentile)
            
            # Compute scale and zero point
            if self.config.symmetric_activations:
                # Symmetric quantization
                abs_max = max(abs(min_val), abs(max_val))
                scale = abs_max / 127.0 if abs_max > 0 else 1.0
                zero_point = 0
            else:
                # Asymmetric quantization
                scale = (max_val - min_val) / 255.0 if max_val > min_val else 1.0
                zero_point = int(-min_val / scale) if scale > 0 else 0
                zero_point = max(0, min(255, zero_point))
            
            self.scale_map[name] = scale
            self.zero_point_map[name] = zero_point
    
    def quantize(self, graph: IRGraph) -> IRGraph:
        """
        Quantize the graph to INT8
        
        Args:
            graph: Float32 IR graph
            
        Returns:
            Quantized IR graph
        """
        print("Quantizing graph...")
        
        # Quantize weights
        for node in graph.nodes:
            if node.op_type not in self.config.quantize_ops:
                continue
            
            self._quantize_node_weights(graph, node)
        
        # Update tensor dtypes
        for name, tensor in graph.tensors.items():
            if tensor.data is not None:
                # Weight tensor - already quantized
                tensor.dtype = self.config.weight_dtype
            else:
                # Activation tensor
                tensor.dtype = self.config.activation_dtype
            
            # Store quantization params
            tensor.scale = self.scale_map.get(name, 1.0)
            tensor.zero_point = self.zero_point_map.get(name, 0)
            tensor.is_quantized = True
        
        return graph
    
    def _quantize_node_weights(self, graph: IRGraph, node: IRNode):
        """Quantize weights for a node"""
        if len(node.inputs) < 2:
            return
        
        weight_name = node.inputs[1]
        weight_tensor = graph.get_tensor(weight_name)
        
        if weight_tensor is None or weight_tensor.data is None:
            return
        
        weight_data = weight_tensor.data
        
        if self.config.per_channel_weights:
            # Per-channel quantization
            quantized, scales, zero_points = self._quantize_per_channel(
                weight_data, axis=0
            )
        else:
            # Per-tensor quantization
            quantized, scale, zero_point = self._quantize_tensor(weight_data)
            scales = [scale]
            zero_points = [zero_point]
        
        weight_tensor.data = quantized
        weight_tensor.dtype = self.config.weight_dtype
        weight_tensor.is_quantized = True
        
        # Store per-channel scales if needed
        node.set_attr('weight_scales', scales)
        node.set_attr('weight_zero_points', zero_points)
        
        # Quantize bias if present
        if len(node.inputs) > 2:
            bias_name = node.inputs[2]
            bias_tensor = graph.get_tensor(bias_name)
            
            if bias_tensor and bias_tensor.data is not None:
                # Bias is quantized with input_scale * weight_scale
                # For simplicity, use int32 for bias
                bias_data = bias_tensor.data
                bias_scale = scales[0] if len(scales) == 1 else np.mean(scales)
                
                quantized_bias = np.round(bias_data / bias_scale).astype(np.int32)
                bias_tensor.data = quantized_bias
                bias_tensor.dtype = DataType.INT32
    
    def _quantize_tensor(self, data: np.ndarray) -> Tuple[np.ndarray, float, int]:
        """Quantize tensor with per-tensor scale"""
        if self.config.symmetric_weights:
            abs_max = np.max(np.abs(data))
            scale = abs_max / 127.0 if abs_max > 0 else 1.0
            zero_point = 0
            quantized = np.clip(np.round(data / scale), -128, 127).astype(np.int8)
        else:
            min_val, max_val = np.min(data), np.max(data)
            scale = (max_val - min_val) / 255.0 if max_val > min_val else 1.0
            zero_point = int(-min_val / scale)
            quantized = np.clip(np.round(data / scale + zero_point), 0, 255).astype(np.uint8)
        
        return quantized, scale, zero_point
    
    def _quantize_per_channel(self, data: np.ndarray, axis: int = 0
                              ) -> Tuple[np.ndarray, List[float], List[int]]:
        """Quantize tensor with per-channel scale"""
        num_channels = data.shape[axis]
        scales = []
        zero_points = []
        
        # Move axis to front for easier processing
        data_moved = np.moveaxis(data, axis, 0)
        quantized_channels = []
        
        for i in range(num_channels):
            channel_data = data_moved[i]
            q_channel, scale, zp = self._quantize_tensor(channel_data)
            quantized_channels.append(q_channel)
            scales.append(scale)
            zero_points.append(zp)
        
        quantized = np.stack(quantized_channels, axis=0)
        quantized = np.moveaxis(quantized, 0, axis)
        
        return quantized, scales, zero_points
    
    def get_quant_info(self) -> Dict:
        """Get quantization information"""
        return {
            'scales': self.scale_map,
            'zero_points': self.zero_point_map,
            'config': {
                'weight_dtype': self.config.weight_dtype.name,
                'activation_dtype': self.config.activation_dtype.name,
                'per_channel': self.config.per_channel_weights,
                'symmetric_weights': self.config.symmetric_weights,
            }
        }


def quantize_graph(graph: IRGraph, 
                   calibration_data: Optional[CalibrationData] = None,
                   config: Optional[QuantizationConfig] = None) -> IRGraph:
    """
    Convenience function to quantize a graph
    
    Args:
        graph: Float32 IR graph
        calibration_data: Optional calibration data
        config: Quantization configuration
        
    Returns:
        Quantized graph
    """
    quantizer = Quantizer(config)
    
    if calibration_data:
        quantizer.calibrate(graph, calibration_data)
    
    return quantizer.quantize(graph)
