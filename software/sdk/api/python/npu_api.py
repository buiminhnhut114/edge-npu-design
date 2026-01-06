"""
EdgeNPU Python API
High-level Python bindings for NPU SDK
"""

import ctypes
import numpy as np
from typing import List, Optional, Tuple, Union, Callable
from pathlib import Path
from enum import IntEnum
from dataclasses import dataclass
import os


# =============================================================================
# Load native library
# =============================================================================

def _find_library():
    """Find the NPU SDK shared library"""
    lib_names = {
        'linux': 'libnpu_sdk.so',
        'darwin': 'libnpu_sdk.dylib',
        'win32': 'npu_sdk.dll',
    }
    
    import sys
    lib_name = lib_names.get(sys.platform, 'libnpu_sdk.so')
    
    # Search paths
    search_paths = [
        Path(__file__).parent.parent / 'lib',
        Path('/usr/local/lib'),
        Path('/usr/lib'),
        Path.home() / '.local/lib',
    ]
    
    # Add LD_LIBRARY_PATH
    if 'LD_LIBRARY_PATH' in os.environ:
        for p in os.environ['LD_LIBRARY_PATH'].split(':'):
            search_paths.append(Path(p))
    
    for path in search_paths:
        lib_path = path / lib_name
        if lib_path.exists():
            return str(lib_path)
    
    return lib_name  # Let ctypes search system paths


try:
    _lib = ctypes.CDLL(_find_library())
except OSError:
    _lib = None


# =============================================================================
# Enums
# =============================================================================

class NPUError(IntEnum):
    """NPU error codes"""
    SUCCESS = 0
    INVALID_PARAM = -1
    NOT_INITIALIZED = -2
    OUT_OF_MEMORY = -3
    MODEL_INVALID = -4
    MODEL_NOT_LOADED = -5
    INFERENCE_FAILED = -6
    TIMEOUT = -7
    HARDWARE = -8
    NOT_SUPPORTED = -9
    FILE_NOT_FOUND = -10


class DataType(IntEnum):
    """Tensor data types"""
    FLOAT32 = 0
    FLOAT16 = 1
    INT32 = 2
    INT16 = 3
    INT8 = 4
    UINT8 = 5


class Layout(IntEnum):
    """Tensor layouts"""
    NCHW = 0
    NHWC = 1
    NC = 2


# =============================================================================
# Data structures
# =============================================================================

@dataclass
class DeviceInfo:
    """NPU device information"""
    name: str
    version: str
    pe_count: int
    max_batch_size: int
    weight_memory_kb: int
    activation_memory_kb: int
    max_ops_per_sec: int
    supports_int8: bool
    supports_float16: bool
    supports_dynamic_shape: bool


@dataclass
class TensorDesc:
    """Tensor descriptor"""
    dtype: DataType
    layout: Layout
    dims: Tuple[int, ...]
    name: str


@dataclass
class ModelInfo:
    """Model information"""
    name: str
    num_inputs: int
    num_outputs: int
    inputs: List[TensorDesc]
    outputs: List[TensorDesc]
    weight_size: int
    estimated_flops: int


@dataclass
class ProfileResult:
    """Profiling results"""
    total_time_us: int
    preprocess_time_us: int
    inference_time_us: int
    postprocess_time_us: int
    mac_operations: int
    utilization_percent: float
    power_mw: float


# =============================================================================
# Exception
# =============================================================================

class NPUException(Exception):
    """NPU SDK exception"""
    def __init__(self, error_code: int, message: str = ""):
        self.error_code = error_code
        self.message = message or f"NPU error: {NPUError(error_code).name}"
        super().__init__(self.message)


def _check_error(error_code: int):
    """Check error code and raise exception if needed"""
    if error_code != NPUError.SUCCESS:
        raise NPUException(error_code)


# =============================================================================
# Device class
# =============================================================================

class Device:
    """NPU Device handle"""
    
    def __init__(self, device_id: int = 0):
        """
        Open NPU device
        
        Args:
            device_id: Device index (0 for first device)
        """
        if _lib is None:
            raise NPUException(-1, "NPU SDK library not found")
        
        self._handle = _lib.npu_open_device(device_id)
        if not self._handle:
            raise NPUException(NPUError.HARDWARE, f"Failed to open device {device_id}")
        
        self._device_id = device_id
    
    def __del__(self):
        self.close()
    
    def __enter__(self):
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()
    
    def close(self):
        """Close device"""
        if hasattr(self, '_handle') and self._handle:
            _lib.npu_close_device(self._handle)
            self._handle = None
    
    @property
    def handle(self):
        return self._handle
    
    def get_info(self) -> DeviceInfo:
        """Get device information"""
        # In real implementation, call native function
        return DeviceInfo(
            name="EdgeNPU",
            version="1.0.0",
            pe_count=256,
            max_batch_size=16,
            weight_memory_kb=256,
            activation_memory_kb=256,
            max_ops_per_sec=4_000_000_000,  # 4 TOPS
            supports_int8=True,
            supports_float16=True,
            supports_dynamic_shape=False
        )
    
    def alloc(self, size: int) -> ctypes.c_void_p:
        """Allocate NPU-accessible memory"""
        return _lib.npu_alloc(self._handle, size)
    
    def free(self, ptr: ctypes.c_void_p):
        """Free NPU-accessible memory"""
        _lib.npu_free(self._handle, ptr)
    
    @staticmethod
    def get_device_count() -> int:
        """Get number of available NPU devices"""
        if _lib is None:
            return 0
        return _lib.npu_get_device_count()


# =============================================================================
# Model class
# =============================================================================

class Model:
    """NPU Model handle"""
    
    def __init__(self, device: Device, path: Optional[str] = None,
                 data: Optional[bytes] = None):
        """
        Load model from file or memory
        
        Args:
            device: NPU device
            path: Path to model file (.npu format)
            data: Model binary data (alternative to path)
        """
        self._device = device
        self._handle = None
        
        if path:
            path_bytes = path.encode('utf-8')
            self._handle = _lib.npu_load_model(device.handle, path_bytes)
        elif data:
            self._handle = _lib.npu_load_model_memory(
                device.handle, data, len(data)
            )
        else:
            raise ValueError("Either path or data must be provided")
        
        if not self._handle:
            raise NPUException(NPUError.MODEL_INVALID, "Failed to load model")
    
    def __del__(self):
        self.unload()
    
    def __enter__(self):
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        self.unload()
    
    def unload(self):
        """Unload model"""
        if hasattr(self, '_handle') and self._handle:
            _lib.npu_unload_model(self._handle)
            self._handle = None
    
    @property
    def handle(self):
        return self._handle
    
    def get_info(self) -> ModelInfo:
        """Get model information"""
        # In real implementation, call native function
        return ModelInfo(
            name="model",
            num_inputs=1,
            num_outputs=1,
            inputs=[TensorDesc(DataType.INT8, Layout.NCHW, (1, 3, 224, 224), "input")],
            outputs=[TensorDesc(DataType.INT8, Layout.NC, (1, 1000), "output")],
            weight_size=0,
            estimated_flops=0
        )
    
    def infer(self, input_data: np.ndarray) -> np.ndarray:
        """
        Run inference (simple API)
        
        Args:
            input_data: Input numpy array
            
        Returns:
            Output numpy array
        """
        # Ensure contiguous array
        input_data = np.ascontiguousarray(input_data)
        
        # Get model info for output shape
        info = self.get_info()
        output_shape = info.outputs[0].dims
        output_dtype = np.int8 if info.outputs[0].dtype == DataType.INT8 else np.float32
        
        output_data = np.zeros(output_shape, dtype=output_dtype)
        
        error = _lib.npu_infer_simple(
            self._handle,
            input_data.ctypes.data_as(ctypes.c_void_p),
            input_data.nbytes,
            output_data.ctypes.data_as(ctypes.c_void_p),
            output_data.nbytes
        )
        _check_error(error)
        
        return output_data
    
    def infer_float32(self, input_data: np.ndarray) -> np.ndarray:
        """
        Run inference with float32 I/O (auto quantization)
        
        Args:
            input_data: Float32 input array
            
        Returns:
            Float32 output array
        """
        input_data = np.ascontiguousarray(input_data, dtype=np.float32)
        
        info = self.get_info()
        output_size = 1
        for d in info.outputs[0].dims:
            output_size *= d
        
        output_data = np.zeros(output_size, dtype=np.float32)
        
        error = _lib.npu_infer_float32(
            self._handle,
            input_data.ctypes.data_as(ctypes.POINTER(ctypes.c_float)),
            input_data.size,
            output_data.ctypes.data_as(ctypes.POINTER(ctypes.c_float)),
            output_data.size
        )
        _check_error(error)
        
        return output_data


# =============================================================================
# Session class
# =============================================================================

class Session:
    """Inference session for fine-grained control"""
    
    def __init__(self, model: Model):
        """
        Create inference session
        
        Args:
            model: Loaded model
        """
        self._model = model
        self._handle = _lib.npu_create_session(model.handle)
        if not self._handle:
            raise NPUException(NPUError.OUT_OF_MEMORY, "Failed to create session")
        
        self._profile_enabled = False
    
    def __del__(self):
        self.destroy()
    
    def __enter__(self):
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        self.destroy()
    
    def destroy(self):
        """Destroy session"""
        if hasattr(self, '_handle') and self._handle:
            _lib.npu_destroy_session(self._handle)
            self._handle = None
    
    def set_input(self, index: int, data: np.ndarray):
        """
        Set input tensor
        
        Args:
            index: Input index
            data: Input data
        """
        data = np.ascontiguousarray(data)
        error = _lib.npu_set_input(
            self._handle, index,
            data.ctypes.data_as(ctypes.c_void_p),
            data.nbytes
        )
        _check_error(error)
    
    def set_input_by_name(self, name: str, data: np.ndarray):
        """
        Set input tensor by name
        
        Args:
            name: Input tensor name
            data: Input data
        """
        data = np.ascontiguousarray(data)
        error = _lib.npu_set_input_by_name(
            self._handle, name.encode('utf-8'),
            data.ctypes.data_as(ctypes.c_void_p),
            data.nbytes
        )
        _check_error(error)
    
    def get_output(self, index: int, shape: Tuple[int, ...], 
                   dtype: np.dtype = np.int8) -> np.ndarray:
        """
        Get output tensor
        
        Args:
            index: Output index
            shape: Output shape
            dtype: Output data type
            
        Returns:
            Output numpy array
        """
        output = np.zeros(shape, dtype=dtype)
        error = _lib.npu_get_output(
            self._handle, index,
            output.ctypes.data_as(ctypes.c_void_p),
            output.nbytes
        )
        _check_error(error)
        return output
    
    def run(self, timeout_ms: int = 0, profile: bool = False):
        """
        Run inference
        
        Args:
            timeout_ms: Timeout in milliseconds (0 = infinite)
            profile: Enable profiling
        """
        self._profile_enabled = profile
        # In real implementation, create options struct and call native
        error = _lib.npu_run(self._handle, None)
        _check_error(error)
    
    def run_async(self, callback: Callable[[int], None], 
                  user_data: any = None):
        """
        Run inference asynchronously
        
        Args:
            callback: Completion callback
            user_data: User data for callback
        """
        # Create callback wrapper
        CALLBACK_TYPE = ctypes.CFUNCTYPE(None, ctypes.c_int, ctypes.c_void_p)
        
        def wrapper(status, data):
            callback(status)
        
        c_callback = CALLBACK_TYPE(wrapper)
        error = _lib.npu_run_async(self._handle, None, c_callback, None)
        _check_error(error)
    
    def wait(self, timeout_ms: int = 0):
        """
        Wait for async inference completion
        
        Args:
            timeout_ms: Timeout in milliseconds
        """
        error = _lib.npu_wait(self._handle, timeout_ms)
        _check_error(error)
    
    def get_profile_result(self) -> ProfileResult:
        """Get profiling results"""
        # In real implementation, call native function
        return ProfileResult(
            total_time_us=0,
            preprocess_time_us=0,
            inference_time_us=0,
            postprocess_time_us=0,
            mac_operations=0,
            utilization_percent=0.0,
            power_mw=0.0
        )


# =============================================================================
# Convenience functions
# =============================================================================

def get_version() -> str:
    """Get SDK version string"""
    if _lib is None:
        return "1.0.0 (stub)"
    return _lib.npu_get_version().decode('utf-8')


def get_device_count() -> int:
    """Get number of available NPU devices"""
    return Device.get_device_count()


def infer(model_path: str, input_data: np.ndarray, 
          device_id: int = 0) -> np.ndarray:
    """
    Simple inference function
    
    Args:
        model_path: Path to model file
        input_data: Input numpy array
        device_id: Device ID
        
    Returns:
        Output numpy array
    """
    with Device(device_id) as device:
        with Model(device, path=model_path) as model:
            return model.infer(input_data)


# =============================================================================
# Stub implementation for testing without hardware
# =============================================================================

class StubDevice:
    """Stub device for testing without hardware"""
    
    def __init__(self, device_id: int = 0):
        self._device_id = device_id
        self._handle = 1  # Fake handle
    
    def __enter__(self):
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        pass
    
    def close(self):
        pass
    
    @property
    def handle(self):
        return self._handle
    
    def get_info(self) -> DeviceInfo:
        return DeviceInfo(
            name="EdgeNPU (Stub)",
            version="1.0.0",
            pe_count=256,
            max_batch_size=16,
            weight_memory_kb=256,
            activation_memory_kb=256,
            max_ops_per_sec=4_000_000_000,
            supports_int8=True,
            supports_float16=True,
            supports_dynamic_shape=False
        )


class StubModel:
    """Stub model for testing"""
    
    def __init__(self, device: StubDevice, path: str = None, data: bytes = None):
        self._device = device
        self._path = path
        self._handle = 1
    
    def __enter__(self):
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        pass
    
    def unload(self):
        pass
    
    @property
    def handle(self):
        return self._handle
    
    def get_info(self) -> ModelInfo:
        return ModelInfo(
            name="stub_model",
            num_inputs=1,
            num_outputs=1,
            inputs=[TensorDesc(DataType.FLOAT32, Layout.NCHW, (1, 3, 224, 224), "input")],
            outputs=[TensorDesc(DataType.FLOAT32, Layout.NC, (1, 1000), "output")],
            weight_size=0,
            estimated_flops=0
        )
    
    def infer(self, input_data: np.ndarray) -> np.ndarray:
        """Stub inference - returns random output"""
        info = self.get_info()
        output_shape = info.outputs[0].dims
        return np.random.randn(*output_shape).astype(np.float32)


# Use stub if library not available
if _lib is None:
    Device = StubDevice
    Model = StubModel
