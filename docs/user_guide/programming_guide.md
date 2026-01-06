# EdgeNPU Programming Guide

**Version 1.0.0**

---

## Table of Contents

1. [Introduction](#introduction)
2. [Getting Started](#getting-started)
3. [Programming Model](#programming-model)
4. [Basic Operations](#basic-operations)
5. [Advanced Features](#advanced-features)
6. [Performance Optimization](#performance-optimization)
7. [Debugging](#debugging)
8. [Code Examples](#code-examples)

---

## 1. Introduction

EdgeNPU is a neural network accelerator designed for efficient inference of deep learning models at the edge. This guide provides comprehensive programming instructions for software developers.

### 1.1 Target Audience

- Embedded software engineers
- Machine learning engineers
- System architects

### 1.2 Prerequisites

- Understanding of neural network concepts
- C/C++ programming experience
- Familiarity with embedded systems

---

## 2. Getting Started

### 2.1 Hardware Setup

1. Connect EdgeNPU to the host system
2. Verify power and clock supplies
3. Configure AXI bus connections

### 2.2 Software Requirements

- EdgeNPU SDK
- Cross-compiler toolchain
- ONNX/TFLite model converter

### 2.3 First Program

```c
#include "edge_npu.h"

int main() {
    // Initialize NPU
    npu_init();
    
    // Load model
    npu_model_t model = npu_load_model("model.bin");
    
    // Set input data
    npu_set_input(model, input_data, input_size);
    
    // Run inference
    npu_run(model);
    
    // Get output
    npu_get_output(model, output_data, output_size);
    
    // Cleanup
    npu_unload_model(model);
    npu_deinit();
    
    return 0;
}
```

---

## 3. Programming Model

### 3.1 Execution Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    Host Processor                                │
│  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐    │
│  │ 1. Load   │  │ 2. Config │  │ 3. Start  │  │ 5. Read   │    │
│  │   Model   │──│   Params  │──│   Infer   │──│   Output  │    │
│  └───────────┘  └───────────┘  └─────┬─────┘  └───────────┘    │
└──────────────────────────────────────┼──────────────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────┐
│                       EdgeNPU                                    │
│  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐    │
│  │   DMA     │  │ Controller│  │ PE Array  │  │   Post-   │    │
│  │  Transfer │──│  Execute  │──│  Compute  │──│  Process  │    │
│  └───────────┘  └───────────┘  └───────────┘  └───────────┘    │
│                                                     │            │
│                              4. Interrupt ──────────┘            │
└─────────────────────────────────────────────────────────────────┘
```

### 3.2 Memory Model

| Memory Region | Address Range | Size | Description |
|---------------|---------------|------|-------------|
| Weight Buffer | Internal | 256 KB | Pre-loaded weights |
| Activation Buffer | Internal | 256 KB | Input/intermediate |
| Instruction Buffer | Internal | 16 KB | Microcode |
| DDR | External | - | Model storage |

### 3.3 Data Formats

| Format | Bits | Range | Use Case |
|--------|------|-------|----------|
| INT8 | 8 | [-128, 127] | Default inference |
| INT16 | 16 | [-32768, 32767] | Higher precision |
| FP16 | 16 | ±65504 | Training compatible |
| BF16 | 16 | ±3.4e38 | Large dynamic range |

---

## 4. Basic Operations

### 4.1 Initialization

```c
// Initialize with default configuration
npu_status_t npu_init(void) {
    // Reset NPU
    NPU_CTRL = 0x04;  // Assert reset
    delay_us(10);
    NPU_CTRL = 0x00;  // Deassert reset
    
    // Wait for ready
    while (!(NPU_STATUS & 0x01));
    
    // Enable interrupts
    NPU_IRQ_EN = 0x0F;
    
    return NPU_OK;
}
```

### 4.2 Loading Weights

```c
npu_status_t npu_load_weights(const void *weights, size_t size) {
    // Configure DMA for weight loading
    NPU_DMA_SRC_LO = (uint32_t)weights;
    NPU_DMA_DST_LO = WEIGHT_BUFFER_ADDR;
    NPU_DMA_LENGTH = size;
    NPU_DMA_CTRL = 0x01;  // Direction: DDR -> Weight Buffer
    
    // Wait for DMA complete
    while (NPU_DMA_STATUS & 0x01);
    
    if (NPU_DMA_STATUS & 0x04) {
        return NPU_DMA_ERROR;
    }
    
    return NPU_OK;
}
```

### 4.3 Running Inference

```c
npu_status_t npu_run_inference(void) {
    // Clear status
    NPU_IRQ_STATUS = 0xFF;
    
    // Start execution
    NPU_CTRL = 0x09;  // START + IRQ_EN
    
    // Wait for completion (polling or interrupt)
    while (!(NPU_IRQ_STATUS & 0x01));
    
    // Check for errors
    if (NPU_STATUS & 0x04) {
        return NPU_ERROR;
    }
    
    return NPU_OK;
}
```

### 4.4 Reading Results

```c
npu_status_t npu_read_output(void *output, size_t size) {
    // Configure DMA for output reading
    NPU_DMA_SRC_LO = OUTPUT_BUFFER_ADDR;
    NPU_DMA_DST_LO = (uint32_t)output;
    NPU_DMA_LENGTH = size;
    NPU_DMA_CTRL = 0x05;  // Direction: Output Buffer -> DDR
    
    // Wait for DMA complete
    while (NPU_DMA_STATUS & 0x01);
    
    return NPU_OK;
}
```

---

## 5. Advanced Features

### 5.1 Layer Fusion

EdgeNPU supports fusing multiple operations:

```
Supported Fusions:
• Conv2D + BatchNorm + ReLU → Single operation
• Conv2D + Add (residual) → Fused residual
• DepthwiseConv + PointwiseConv → Fused separable
```

### 5.2 Multi-batch Processing

```c
void npu_run_batch(int batch_size) {
    for (int i = 0; i < batch_size; i++) {
        // Load input i
        npu_load_input(inputs[i], input_size);
        
        // Run inference (async)
        npu_start_async();
        
        // Process previous output while NPU is busy
        if (i > 0) {
            process_output(outputs[i-1]);
        }
        
        // Wait for current inference
        npu_wait();
        
        // Read output
        npu_read_output(outputs[i], output_size);
    }
}
```

### 5.3 Dynamic Quantization

```c
// Configure per-layer quantization
typedef struct {
    float scale;
    int32_t zero_point;
} quant_params_t;

void npu_set_quant_params(int layer_id, quant_params_t *params) {
    uint32_t scale_fixed = float_to_fixed(params->scale);
    NPU_QUANT_SCALE(layer_id) = scale_fixed;
    NPU_QUANT_ZP(layer_id) = params->zero_point;
}
```

---

## 6. Performance Optimization

### 6.1 Data Layout

**NHWC vs NCHW:**
- EdgeNPU internally uses NHWC layout
- Use data reshaper for NCHW models
- Pre-convert data to avoid runtime conversion

### 6.2 Tiling Strategy

```
Optimal Tile Sizes:
┌──────────────────────────────────────────────────┐
│ Activation Buffer = 256 KB                       │
│ Weight Buffer = 256 KB                           │
│                                                  │
│ For Conv2D (3x3, 64 channels):                   │
│   Max tile: 56x56x64 = 200 KB (fits)            │
│   Recommended: 28x28x64 for double buffering     │
└──────────────────────────────────────────────────┘
```

### 6.3 DMA Optimization

```c
// Double buffering for continuous execution
void npu_double_buffer_run(void) {
    // Load first batch to buffer A
    npu_dma_load_async(BUFFER_A, input_0);
    npu_dma_wait();
    
    for (int i = 0; i < num_batches; i++) {
        // Start compute on current buffer
        npu_set_input_buffer(i % 2 ? BUFFER_B : BUFFER_A);
        npu_start_async();
        
        // Load next batch to other buffer
        if (i + 1 < num_batches) {
            npu_dma_load_async(
                i % 2 ? BUFFER_A : BUFFER_B,
                inputs[i + 1]
            );
        }
        
        // Wait for both
        npu_dma_wait();
        npu_wait();
    }
}
```

### 6.4 Performance Metrics

```c
// Read performance counters
uint64_t get_cycle_count(void) {
    uint32_t lo = NPU_PERF_CYCLE_LO;
    uint32_t hi = NPU_PERF_CYCLE_HI;
    return ((uint64_t)hi << 32) | lo;
}

float get_utilization(void) {
    uint64_t active = get_pe_active_cycles();
    uint64_t total = get_cycle_count();
    return (float)active / total * 100.0f;
}
```

---

## 7. Debugging

### 7.1 Error Handling

```c
const char* npu_error_string(npu_status_t status) {
    switch (status) {
        case NPU_OK:           return "Success";
        case NPU_INVALID_OP:   return "Invalid opcode";
        case NPU_MEM_FAULT:    return "Memory access fault";
        case NPU_DMA_TIMEOUT:  return "DMA timeout";
        case NPU_OVERFLOW:     return "Arithmetic overflow";
        default:               return "Unknown error";
    }
}
```

### 7.2 Debug Mode

```c
void npu_enable_debug(void) {
    NPU_DEBUG_CTRL = 0x03;  // TRACE_EN + BREAK_EN
}

void npu_set_breakpoint(uint16_t addr) {
    NPU_DEBUG_BREAKPOINT = addr | 0x10000;  // BP_EN
}

void npu_single_step(void) {
    NPU_DEBUG_CTRL |= 0x04;  // SINGLE_STEP
    NPU_CTRL = 0x01;         // START
    while (!(NPU_STATUS & 0x02));  // Wait DONE
}
```

### 7.3 Trace Output

Enable instruction tracing for debugging:

```c
void npu_dump_trace(void) {
    printf("PC: 0x%04X\n", NPU_DEBUG_PC);
    printf("Status: 0x%08X\n", NPU_STATUS);
    printf("Error: %s\n", npu_error_string(NPU_STATUS >> 8));
}
```

---

## 8. Code Examples

### 8.1 MobileNet Inference

```c
#include "edge_npu.h"
#include "mobilenet_weights.h"

#define INPUT_SIZE (224 * 224 * 3)
#define OUTPUT_SIZE 1000

int mobilenet_inference(uint8_t *input, float *output) {
    // Initialize
    npu_init();
    
    // Load pre-quantized weights
    npu_load_weights(mobilenet_weights, sizeof(mobilenet_weights));
    npu_load_instructions(mobilenet_instrs, sizeof(mobilenet_instrs));
    
    // Load input
    npu_load_input(input, INPUT_SIZE);
    
    // Run
    npu_status_t status = npu_run_inference();
    if (status != NPU_OK) {
        printf("Error: %s\n", npu_error_string(status));
        return -1;
    }
    
    // Read and dequantize output
    int8_t raw_output[OUTPUT_SIZE];
    npu_read_output(raw_output, OUTPUT_SIZE);
    
    for (int i = 0; i < OUTPUT_SIZE; i++) {
        output[i] = (raw_output[i] - ZERO_POINT) * SCALE;
    }
    
    // Find top-1
    int max_idx = 0;
    for (int i = 1; i < OUTPUT_SIZE; i++) {
        if (output[i] > output[max_idx]) max_idx = i;
    }
    
    return max_idx;
}
```

### 8.2 Real-time Object Detection

```c
void detection_loop(void) {
    while (running) {
        // Capture frame
        camera_capture(frame_buffer);
        
        // Preprocess
        resize_and_normalize(frame_buffer, npu_input);
        
        // Inference
        npu_load_input(npu_input, INPUT_SIZE);
        npu_run_inference();
        npu_read_output(npu_output, OUTPUT_SIZE);
        
        // Postprocess
        decode_detections(npu_output, boxes, NUM_BOXES);
        nms(boxes, &num_detections);
        
        // Display
        draw_boxes(frame_buffer, boxes, num_detections);
        display_frame(frame_buffer);
    }
}
```

---

## Appendix A: API Reference

| Function | Description |
|----------|-------------|
| `npu_init()` | Initialize NPU |
| `npu_deinit()` | Deinitialize NPU |
| `npu_load_model()` | Load compiled model |
| `npu_set_input()` | Set input tensor |
| `npu_run()` | Run inference (blocking) |
| `npu_run_async()` | Run inference (non-blocking) |
| `npu_wait()` | Wait for completion |
| `npu_get_output()` | Get output tensor |

---

## Appendix B: Supported Operators

| Operator | INT8 | INT16 | FP16 | Notes |
|----------|------|-------|------|-------|
| Conv2D | ✓ | ✓ | ✓ | |
| DepthwiseConv2D | ✓ | ✓ | ✓ | |
| FullyConnected | ✓ | ✓ | ✓ | |
| MaxPool2D | ✓ | ✓ | ✓ | |
| AvgPool2D | ✓ | ✓ | ✓ | |
| ReLU | ✓ | ✓ | ✓ | |
| ReLU6 | ✓ | ✓ | ✓ | |
| Sigmoid | ✓ | ✓ | ✓ | LUT-based |
| Add | ✓ | ✓ | ✓ | |
| Concat | ✓ | ✓ | ✓ | |

---

*© 2026 EdgeNPU Project. All rights reserved.*
