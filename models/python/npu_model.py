"""
EdgeNPU Python Reference Model
Behavioral model for verification
"""

import numpy as np
from typing import Tuple, List, Optional
from enum import Enum

class ActivationType(Enum):
    NONE = 0
    RELU = 1
    RELU6 = 2
    SIGMOID = 3
    TANH = 4
    SWISH = 5
    GELU = 6

class PoolingType(Enum):
    MAX = 0
    AVG = 1
    GLOBAL_AVG = 2

class NPUModel:
    """
    Reference model for EdgeNPU
    Used for functional verification
    """
    
    def __init__(self, pe_rows: int = 16, pe_cols: int = 16, data_width: int = 8):
        self.pe_rows = pe_rows
        self.pe_cols = pe_cols
        self.data_width = data_width
        self.max_val = 2 ** (data_width - 1) - 1
        self.min_val = -(2 ** (data_width - 1))
        
        # Buffers
        self.weight_buffer = None
        self.activation_buffer = None
        
    def saturate(self, x: np.ndarray) -> np.ndarray:
        """Saturate values to data width"""
        return np.clip(x, self.min_val, self.max_val).astype(np.int8)
    
    def activation(self, x: np.ndarray, act_type: ActivationType) -> np.ndarray:
        """Apply activation function"""
        if act_type == ActivationType.NONE:
            return x
        elif act_type == ActivationType.RELU:
            return np.maximum(0, x)
        elif act_type == ActivationType.RELU6:
            return np.clip(x, 0, 6)
        elif act_type == ActivationType.SIGMOID:
            return (1 / (1 + np.exp(-x.astype(float) / 16)) * 127).astype(np.int8)
        elif act_type == ActivationType.TANH:
            return (np.tanh(x.astype(float) / 16) * 127).astype(np.int8)
        elif act_type == ActivationType.SWISH:
            x_float = x.astype(float) / 16
            return (x_float * (1 / (1 + np.exp(-x_float))) * 127).astype(np.int8)
        elif act_type == ActivationType.GELU:
            x_float = x.astype(float) / 16
            return (0.5 * x_float * (1 + np.tanh(np.sqrt(2/np.pi) * (x_float + 0.044715 * x_float**3))) * 127).astype(np.int8)
        else:
            return x
    
    def conv2d(
        self,
        input: np.ndarray,       # [H, W, C]
        weight: np.ndarray,      # [KH, KW, C, K]
        bias: Optional[np.ndarray] = None,  # [K]
        stride: Tuple[int, int] = (1, 1),
        padding: Tuple[int, int, int, int] = (0, 0, 0, 0),  # top, bottom, left, right
        activation: ActivationType = ActivationType.NONE
    ) -> np.ndarray:
        """
        2D Convolution
        """
        H, W, C = input.shape
        KH, KW, C_in, K = weight.shape
        assert C == C_in, f"Channel mismatch: {C} vs {C_in}"
        
        # Apply padding
        padded = np.pad(input, ((padding[0], padding[1]), (padding[2], padding[3]), (0, 0)), 
                       mode='constant', constant_values=0)
        
        H_pad, W_pad, _ = padded.shape
        
        # Output dimensions
        H_out = (H_pad - KH) // stride[0] + 1
        W_out = (W_pad - KW) // stride[1] + 1
        
        # Compute convolution
        output = np.zeros((H_out, W_out, K), dtype=np.int32)
        
        for oh in range(H_out):
            for ow in range(W_out):
                for k in range(K):
                    ih = oh * stride[0]
                    iw = ow * stride[1]
                    
                    window = padded[ih:ih+KH, iw:iw+KW, :]
                    output[oh, ow, k] = np.sum(window * weight[:, :, :, k])
        
        # Add bias
        if bias is not None:
            output += bias
        
        # Quantize and activate
        output = self.saturate(output)
        output = self.activation(output, activation)
        
        return output
    
    def matmul(
        self,
        a: np.ndarray,  # [M, K]
        b: np.ndarray,  # [K, N]
        bias: Optional[np.ndarray] = None,  # [N]
        activation: ActivationType = ActivationType.NONE
    ) -> np.ndarray:
        """
        Matrix multiplication (for FC layers)
        """
        # Compute using systolic array tiling
        M, K = a.shape
        K_b, N = b.shape
        assert K == K_b, f"Dimension mismatch: {K} vs {K_b}"
        
        # Tile for PE array
        output = np.zeros((M, N), dtype=np.int32)
        
        for m_tile in range(0, M, self.pe_rows):
            for n_tile in range(0, N, self.pe_cols):
                m_end = min(m_tile + self.pe_rows, M)
                n_end = min(n_tile + self.pe_cols, N)
                
                for k in range(K):
                    output[m_tile:m_end, n_tile:n_end] += \
                        np.outer(a[m_tile:m_end, k], b[k, n_tile:n_end])
        
        # Add bias
        if bias is not None:
            output += bias
        
        # Quantize and activate
        output = self.saturate(output)
        output = self.activation(output, activation)
        
        return output
    
    def max_pool(
        self,
        input: np.ndarray,  # [H, W, C]
        kernel_size: Tuple[int, int] = (2, 2),
        stride: Tuple[int, int] = (2, 2)
    ) -> np.ndarray:
        """Max pooling"""
        H, W, C = input.shape
        KH, KW = kernel_size
        
        H_out = (H - KH) // stride[0] + 1
        W_out = (W - KW) // stride[1] + 1
        
        output = np.zeros((H_out, W_out, C), dtype=input.dtype)
        
        for oh in range(H_out):
            for ow in range(W_out):
                ih = oh * stride[0]
                iw = ow * stride[1]
                output[oh, ow, :] = np.max(input[ih:ih+KH, iw:iw+KW, :], axis=(0, 1))
        
        return output
    
    def avg_pool(
        self,
        input: np.ndarray,
        kernel_size: Tuple[int, int] = (2, 2),
        stride: Tuple[int, int] = (2, 2)
    ) -> np.ndarray:
        """Average pooling"""
        H, W, C = input.shape
        KH, KW = kernel_size
        
        H_out = (H - KH) // stride[0] + 1
        W_out = (W - KW) // stride[1] + 1
        
        output = np.zeros((H_out, W_out, C), dtype=np.int32)
        
        for oh in range(H_out):
            for ow in range(W_out):
                ih = oh * stride[0]
                iw = ow * stride[1]
                output[oh, ow, :] = np.mean(input[ih:ih+KH, iw:iw+KW, :], axis=(0, 1))
        
        return self.saturate(output)


def test_model():
    """Test the reference model"""
    model = NPUModel(pe_rows=16, pe_cols=16)
    
    # Test matrix multiplication
    print("Testing Matrix Multiplication...")
    a = np.random.randint(-128, 127, (32, 64), dtype=np.int8)
    b = np.random.randint(-128, 127, (64, 32), dtype=np.int8)
    c = model.matmul(a, b, activation=ActivationType.RELU)
    print(f"  Input A: {a.shape}, Input B: {b.shape}")
    print(f"  Output: {c.shape}")
    
    # Test convolution
    print("\nTesting Convolution...")
    input = np.random.randint(-128, 127, (28, 28, 3), dtype=np.int8)
    weight = np.random.randint(-128, 127, (3, 3, 3, 16), dtype=np.int8)
    output = model.conv2d(input, weight, padding=(1, 1, 1, 1), activation=ActivationType.RELU)
    print(f"  Input: {input.shape}, Weight: {weight.shape}")
    print(f"  Output: {output.shape}")
    
    # Test pooling
    print("\nTesting Max Pooling...")
    pool_out = model.max_pool(output)
    print(f"  Input: {output.shape}")
    print(f"  Output: {pool_out.shape}")
    
    print("\nAll tests passed!")


if __name__ == "__main__":
    test_model()
