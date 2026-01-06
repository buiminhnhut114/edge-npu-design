# EdgeNPU Python API Reference

**Version 1.0.0**

---

## Installation

```bash
pip install edge-npu
```

---

## Quick Start

```python
import edge_npu as npu

# Initialize
npu.init()

# Load and run model
model = npu.load_model("mobilenet.onnx")
output = model.run(input_data)

# Cleanup
npu.deinit()
```

---

## Module: edge_npu

### edge_npu.init()

Initialize the NPU hardware.

```python
edge_npu.init(device_id: int = 0) -> None
```

**Parameters:**
- `device_id` - NPU device index (default: 0)

**Raises:**
- `NPUError` if initialization fails

---

### edge_npu.deinit()

Release NPU resources.

```python
edge_npu.deinit() -> None
```

---

### edge_npu.get_device_info()

Get NPU device information.

```python
edge_npu.get_device_info() -> DeviceInfo
```

**Returns:**
```python
class DeviceInfo:
    name: str           # "EdgeNPU"
    version: str        # "1.0.0"
    pe_rows: int        # 16
    pe_cols: int        # 16
    memory_size: int    # 528 KB
```

---

## Class: Model

### load_model()

Load a model from file.

```python
edge_npu.load_model(
    path: str,
    dtype: str = "int8"
) -> Model
```

**Parameters:**
- `path` - Path to model file (`.onnx`, `.tflite`, `.bin`)
- `dtype` - Target data type ("int8", "int16", "fp16")

**Returns:**
- `Model` instance

**Example:**
```python
model = npu.load_model("resnet50.onnx", dtype="int8")
```

---

### Model.run()

Run inference.

```python
Model.run(
    inputs: Union[np.ndarray, List[np.ndarray], Dict[str, np.ndarray]],
    **kwargs
) -> Union[np.ndarray, List[np.ndarray]]
```

**Parameters:**
- `inputs` - Input data (numpy array or dict of arrays)

**Returns:**
- Output array(s)

**Example:**
```python
# Single input
output = model.run(input_array)

# Multiple inputs
outputs = model.run([input1, input2])

# Named inputs
outputs = model.run({"image": image, "mask": mask})
```

---

### Model.run_async()

Run inference asynchronously.

```python
Model.run_async(inputs) -> AsyncResult
```

**Example:**
```python
result = model.run_async(input_data)
# Do other work...
output = result.wait()
```

---

### Model.summary()

Print model summary.

```python
Model.summary() -> str
```

**Example:**
```python
print(model.summary())
```

Output:
```
Model: mobilenet_v2
==================================================
Layer (type)          Output Shape      Params
==================================================
Conv2D               [1, 112, 112, 32]   864
BatchNorm            [1, 112, 112, 32]   128
ReLU6                [1, 112, 112, 32]   0
...
==================================================
Total params: 3,538,984
Trainable params: 0
Non-trainable params: 3,538,984
==================================================
```

---

### Model Properties

```python
model.input_shapes   # List of input shapes
model.output_shapes  # List of output shapes
model.input_names    # List of input names
model.output_names   # List of output names
model.num_layers     # Number of layers
model.memory_usage   # Memory footprint in bytes
```

---

## Class: Tensor

### Creating Tensors

```python
edge_npu.Tensor(
    data: np.ndarray,
    dtype: str = None
) -> Tensor
```

**Example:**
```python
tensor = npu.Tensor(np.random.randn(1, 224, 224, 3).astype(np.float32))
```

---

### Tensor.to_numpy()

Convert to NumPy array.

```python
Tensor.to_numpy() -> np.ndarray
```

---

## Quantization

### edge_npu.quantize()

Quantize a floating-point model.

```python
edge_npu.quantize(
    model_path: str,
    output_path: str,
    calibration_data: np.ndarray,
    dtype: str = "int8"
) -> None
```

**Parameters:**
- `model_path` - Path to ONNX/TFLite model
- `output_path` - Output path for quantized model
- `calibration_data` - Sample data for calibration
- `dtype` - Target data type

**Example:**
```python
# Load calibration images
calib_data = load_calibration_images("calib_dir/")

# Quantize
npu.quantize(
    model_path="model.onnx",
    output_path="model_int8.bin",
    calibration_data=calib_data,
    dtype="int8"
)
```

---

## Performance Profiling

### Model.profile()

Profile model performance.

```python
Model.profile(
    inputs: np.ndarray,
    num_runs: int = 10
) -> ProfileResult
```

**Returns:**
```python
class ProfileResult:
    latency_ms: float        # Average latency
    throughput_fps: float    # Frames per second
    utilization: float       # PE utilization (%)
    per_layer: List[LayerProfile]
```

**Example:**
```python
result = model.profile(input_data, num_runs=100)
print(f"Latency: {result.latency_ms:.2f} ms")
print(f"Throughput: {result.throughput_fps:.1f} FPS")
print(f"Utilization: {result.utilization:.1f}%")

# Per-layer breakdown
for layer in result.per_layer:
    print(f"  {layer.name}: {layer.time_ms:.3f} ms")
```

---

## Error Handling

### NPUError

Base exception class.

```python
class NPUError(Exception):
    code: int
    message: str
```

### Specific Errors

```python
class NPUInitError(NPUError): ...
class NPUModelError(NPUError): ...
class NPUInferenceError(NPUError): ...
class NPUTimeoutError(NPUError): ...
```

**Example:**
```python
try:
    model = npu.load_model("invalid.onnx")
except npu.NPUModelError as e:
    print(f"Failed to load model: {e.message}")
```

---

## Logging

### edge_npu.set_log_level()

Set logging verbosity.

```python
edge_npu.set_log_level(level: str) -> None
```

**Levels:** `"none"`, `"error"`, `"warn"`, `"info"`, `"debug"`, `"trace"`

---

## Complete Example

```python
import numpy as np
import edge_npu as npu
from PIL import Image

def preprocess(image_path):
    """Preprocess image for MobileNet."""
    img = Image.open(image_path).resize((224, 224))
    arr = np.array(img, dtype=np.float32)
    arr = (arr - 128) / 128  # Normalize
    return arr[np.newaxis, ...]  # Add batch dim

def main():
    # Initialize NPU
    npu.init()
    
    # Print device info
    info = npu.get_device_info()
    print(f"Device: {info.name} v{info.version}")
    print(f"PE Array: {info.pe_rows}x{info.pe_cols}")
    
    # Load model
    model = npu.load_model("mobilenet_v2.onnx", dtype="int8")
    print(model.summary())
    
    # Preprocess input
    input_data = preprocess("cat.jpg")
    
    # Run inference
    output = model.run(input_data)
    
    # Get prediction
    class_id = np.argmax(output)
    confidence = np.max(output)
    print(f"Predicted: class {class_id} ({confidence:.2%})")
    
    # Profile
    result = model.profile(input_data, num_runs=100)
    print(f"\nPerformance:")
    print(f"  Latency: {result.latency_ms:.2f} ms")
    print(f"  Throughput: {result.throughput_fps:.1f} FPS")
    
    # Cleanup
    npu.deinit()

if __name__ == "__main__":
    main()
```

---

## Compatibility

| Python | NumPy | ONNX | TFLite |
|--------|-------|------|--------|
| 3.8+ | 1.20+ | 1.12+ | 2.10+ |

---

*© 2026 EdgeNPU Project. All rights reserved.*
