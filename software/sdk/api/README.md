# EdgeNPU SDK API Bindings

API bindings cho các ngôn ngữ lập trình khác nhau.

## Cấu trúc

```
api/
├── python/         # Python bindings
│   ├── npu_api.py  # Main Python API
│   ├── __init__.py
│   └── setup.py    # Package setup
├── cpp/            # C++ wrapper
│   └── npu_api.hpp # Header-only C++ API
└── README.md
```

## Python API

### Cài đặt

```bash
cd api/python
pip install -e .
```

### Sử dụng

```python
import numpy as np
from edgenpu import Device, Model, Session

# Mở device
with Device(0) as device:
    print(f"Device: {device.get_info().name}")
    
    # Load model
    with Model(device, "model.npu") as model:
        # Simple inference
        input_data = np.random.randn(1, 3, 224, 224).astype(np.float32)
        output = model.infer(input_data)
        print(f"Output shape: {output.shape}")

# Hoặc dùng convenience function
from edgenpu import infer
output = infer("model.npu", input_data)
```

### Session API (fine-grained control)

```python
with Device(0) as device:
    with Model(device, "model.npu") as model:
        with Session(model) as session:
            # Set inputs
            session.set_input(0, input_data)
            
            # Run inference
            session.run(timeout_ms=1000, profile=True)
            
            # Get outputs
            output = session.get_output(0, shape=(1, 1000), dtype=np.float32)
            
            # Get profiling
            profile = session.get_profile_result()
            print(f"Inference time: {profile.inference_time_us} us")
```

## C++ API

### Sử dụng

```cpp
#include "npu_api.hpp"

int main() {
    // Open device
    npu::Device device(0);
    auto info = device.get_info();
    std::cout << "Device: " << info.name << std::endl;
    
    // Load model
    npu::Model model(device, "model.npu");
    
    // Create tensors
    npu::TensorF32 input({1, 3, 224, 224});
    npu::TensorF32 output({1, 1000});
    
    // Fill input data...
    
    // Run inference
    model.infer_float32(input, output);
    
    // Or use session for more control
    npu::Session session(model);
    session.set_input(0, input);
    session.run(1000, true);  // timeout=1000ms, profile=true
    session.get_output(0, output);
    
    auto profile = session.get_profile_result();
    std::cout << "Time: " << profile.inference_time_us << " us" << std::endl;
    
    return 0;
}
```

### Async inference

```cpp
npu::Session session(model);
session.set_input(0, input);

// Async run with callback
session.run_async([](npu_error_t status) {
    if (status == NPU_SUCCESS) {
        std::cout << "Inference complete!" << std::endl;
    }
});

// Do other work...

// Wait for completion
session.wait(5000);  // 5 second timeout
```

## Error Handling

### Python

```python
from edgenpu import NPUException, NPUError

try:
    model = Model(device, "invalid.npu")
except NPUException as e:
    print(f"Error: {e.error_code} - {e.message}")
```

### C++

```cpp
try {
    npu::Model model(device, "invalid.npu");
} catch (const npu::Exception& e) {
    std::cerr << "Error: " << e.code() << " - " << e.what() << std::endl;
}
```

## License

Copyright (c) 2024 EdgeNPU Project
