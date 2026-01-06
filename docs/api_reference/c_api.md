# EdgeNPU C API Reference

**Version 1.0.0**

---

## Overview

The EdgeNPU C API provides a comprehensive interface for controlling the NPU from host software.

---

## Header Files

```c
#include <edge_npu.h>        // Main API
#include <edge_npu_types.h>  // Type definitions
#include <edge_npu_error.h>  // Error codes
```

---

## Initialization

### npu_init

Initialize the NPU hardware.

```c
npu_status_t npu_init(void);
```

**Returns:**
- `NPU_OK` on success
- `NPU_ERROR` on failure

**Example:**
```c
if (npu_init() != NPU_OK) {
    fprintf(stderr, "Failed to initialize NPU\n");
    exit(1);
}
```

---

### npu_deinit

Deinitialize the NPU and release resources.

```c
void npu_deinit(void);
```

---

### npu_reset

Perform a soft reset of the NPU.

```c
npu_status_t npu_reset(void);
```

---

## Model Management

### npu_load_model

Load a compiled model into NPU memory.

```c
npu_model_t npu_load_model(const char *path);
```

**Parameters:**
- `path` - Path to the compiled model file (`.bin`)

**Returns:**
- Valid model handle on success
- `NULL` on failure

**Example:**
```c
npu_model_t model = npu_load_model("model.bin");
if (model == NULL) {
    fprintf(stderr, "Failed to load model\n");
    exit(1);
}
```

---

### npu_load_model_from_memory

Load a model from memory buffer.

```c
npu_model_t npu_load_model_from_memory(
    const void *data,
    size_t size
);
```

**Parameters:**
- `data` - Pointer to model data
- `size` - Size in bytes

---

### npu_unload_model

Unload a model and free resources.

```c
void npu_unload_model(npu_model_t model);
```

---

### npu_get_model_info

Get information about a loaded model.

```c
npu_status_t npu_get_model_info(
    npu_model_t model,
    npu_model_info_t *info
);
```

**Model Info Structure:**
```c
typedef struct {
    uint32_t num_inputs;
    uint32_t num_outputs;
    uint32_t num_layers;
    size_t weight_size;
    size_t activation_size;
    char name[64];
} npu_model_info_t;
```

---

## Tensor Operations

### npu_create_tensor

Create a tensor for input/output.

```c
npu_tensor_t npu_create_tensor(
    npu_data_type_t dtype,
    const int *dims,
    int num_dims
);
```

**Data Types:**
```c
typedef enum {
    NPU_DTYPE_INT8   = 0,
    NPU_DTYPE_INT16  = 1,
    NPU_DTYPE_FP16   = 2,
    NPU_DTYPE_BF16   = 3,
    NPU_DTYPE_FP32   = 4
} npu_data_type_t;
```

**Example:**
```c
int dims[] = {1, 224, 224, 3};
npu_tensor_t input = npu_create_tensor(NPU_DTYPE_INT8, dims, 4);
```

---

### npu_destroy_tensor

Free a tensor.

```c
void npu_destroy_tensor(npu_tensor_t tensor);
```

---

### npu_tensor_set_data

Copy data into a tensor.

```c
npu_status_t npu_tensor_set_data(
    npu_tensor_t tensor,
    const void *data,
    size_t size
);
```

---

### npu_tensor_get_data

Copy data from a tensor.

```c
npu_status_t npu_tensor_get_data(
    npu_tensor_t tensor,
    void *data,
    size_t size
);
```

---

## Inference

### npu_set_input

Set input tensor for inference.

```c
npu_status_t npu_set_input(
    npu_model_t model,
    int input_index,
    npu_tensor_t tensor
);
```

---

### npu_run

Run inference (blocking).

```c
npu_status_t npu_run(npu_model_t model);
```

**Returns:**
- `NPU_OK` on success
- Error code on failure

---

### npu_run_async

Run inference (non-blocking).

```c
npu_status_t npu_run_async(npu_model_t model);
```

---

### npu_wait

Wait for async inference to complete.

```c
npu_status_t npu_wait(npu_model_t model);
```

---

### npu_get_output

Get output tensor after inference.

```c
npu_tensor_t npu_get_output(
    npu_model_t model,
    int output_index
);
```

---

## Performance

### npu_get_perf_stats

Get performance statistics.

```c
npu_status_t npu_get_perf_stats(
    npu_model_t model,
    npu_perf_stats_t *stats
);
```

**Perf Stats Structure:**
```c
typedef struct {
    uint64_t total_cycles;
    uint64_t compute_cycles;
    uint64_t dma_cycles;
    uint64_t stall_cycles;
    float utilization;
    float throughput_gops;
} npu_perf_stats_t;
```

---

### npu_profile_layer

Profile individual layer performance.

```c
npu_status_t npu_profile_layer(
    npu_model_t model,
    int layer_index,
    npu_layer_profile_t *profile
);
```

---

## Error Handling

### Error Codes

```c
typedef enum {
    NPU_OK           = 0,
    NPU_ERROR        = -1,
    NPU_INVALID_ARG  = -2,
    NPU_OUT_OF_MEM   = -3,
    NPU_TIMEOUT      = -4,
    NPU_NOT_READY    = -5,
    NPU_INVALID_OP   = -6,
    NPU_HW_ERROR     = -7
} npu_status_t;
```

---

### npu_get_error_string

Get human-readable error message.

```c
const char* npu_get_error_string(npu_status_t status);
```

---

### npu_get_last_error

Get the last error that occurred.

```c
npu_status_t npu_get_last_error(void);
```

---

## Debug

### npu_set_log_level

Set logging verbosity.

```c
void npu_set_log_level(npu_log_level_t level);
```

**Log Levels:**
```c
typedef enum {
    NPU_LOG_NONE    = 0,
    NPU_LOG_ERROR   = 1,
    NPU_LOG_WARN    = 2,
    NPU_LOG_INFO    = 3,
    NPU_LOG_DEBUG   = 4,
    NPU_LOG_TRACE   = 5
} npu_log_level_t;
```

---

### npu_dump_registers

Dump all register values for debugging.

```c
void npu_dump_registers(void);
```

---

## Complete Example

```c
#include <stdio.h>
#include <stdlib.h>
#include <edge_npu.h>

int main(int argc, char *argv[]) {
    npu_status_t status;
    npu_model_t model;
    npu_tensor_t input, output;
    npu_perf_stats_t stats;
    
    // Initialize
    status = npu_init();
    if (status != NPU_OK) {
        fprintf(stderr, "Init failed: %s\n", 
                npu_get_error_string(status));
        return 1;
    }
    
    // Load model
    model = npu_load_model("mobilenet.bin");
    if (model == NULL) {
        fprintf(stderr, "Failed to load model\n");
        npu_deinit();
        return 1;
    }
    
    // Create input tensor
    int dims[] = {1, 224, 224, 3};
    input = npu_create_tensor(NPU_DTYPE_INT8, dims, 4);
    
    // Load input data
    uint8_t *image_data = load_image("image.jpg");
    npu_tensor_set_data(input, image_data, 224*224*3);
    
    // Set input
    npu_set_input(model, 0, input);
    
    // Run inference
    status = npu_run(model);
    if (status != NPU_OK) {
        fprintf(stderr, "Inference failed: %s\n",
                npu_get_error_string(status));
    }
    
    // Get output
    output = npu_get_output(model, 0);
    
    int8_t results[1000];
    npu_tensor_get_data(output, results, sizeof(results));
    
    // Find top prediction
    int top_class = 0;
    for (int i = 1; i < 1000; i++) {
        if (results[i] > results[top_class]) {
            top_class = i;
        }
    }
    printf("Predicted class: %d\n", top_class);
    
    // Performance stats
    npu_get_perf_stats(model, &stats);
    printf("Utilization: %.1f%%\n", stats.utilization);
    printf("Throughput: %.1f GOPS\n", stats.throughput_gops);
    
    // Cleanup
    npu_destroy_tensor(input);
    npu_unload_model(model);
    npu_deinit();
    
    free(image_data);
    return 0;
}
```

---

## Thread Safety

| Function | Thread Safe |
|----------|-------------|
| `npu_init` | No |
| `npu_load_model` | Yes |
| `npu_run` | No* |
| `npu_get_output` | Yes |

> *Multiple models can run on separate NPU instances.

---

*© 2026 EdgeNPU Project. All rights reserved.*
