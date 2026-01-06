"""
EdgeNPU Python SDK
"""

from .npu_api import (
    # Classes
    Device,
    Model,
    Session,
    
    # Data types
    NPUError,
    DataType,
    Layout,
    DeviceInfo,
    TensorDesc,
    ModelInfo,
    ProfileResult,
    NPUException,
    
    # Functions
    get_version,
    get_device_count,
    infer,
)

__version__ = "1.0.0"
__all__ = [
    'Device',
    'Model', 
    'Session',
    'NPUError',
    'DataType',
    'Layout',
    'DeviceInfo',
    'TensorDesc',
    'ModelInfo',
    'ProfileResult',
    'NPUException',
    'get_version',
    'get_device_count',
    'infer',
]
