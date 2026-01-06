# EdgeNPU Documentation

> Tài liệu này được viết theo phong cách của [Google Coral Documentation](https://developers.google.com/coral/guides/intro)

---

## Introduction

### What is EdgeNPU?

EdgeNPU là một machine learning (ML) accelerator core được thiết kế để tăng tốc inference của neural network với hiệu năng cao và tiêu thụ năng lượng thấp. Nó được thiết kế như một IP core có thể tích hợp vào các SoC cho các ứng dụng edge AI.

EdgeNPU sử dụng kiến trúc **systolic array** để tối ưu hóa các phép toán matrix multiplication - nền tảng của hầu hết các neural network hiện đại.

### Key Features

| Feature | Specification |
|---------|---------------|
| **Architecture** | 16×16 Systolic Array (256 PEs) |
| **Peak Performance** | 512 GOPS @ 1GHz (INT8) |
| **Power Consumption** | < 1W (target) |
| **Efficiency** | > 500 GOPS/W |
| **On-chip Memory** | 512KB (256KB weights + 256KB activations) |
| **Data Precision** | INT8, INT16, FP16, BF16 |
| **Interface** | AXI4 (128-bit) + AXI4-Lite (32-bit) |

---

## Architecture Overview

### Traditional Design vs EdgeNPU

```
┌─────────────────────────────────────────────────────────────┐
│                    Traditional Design                        │
│  ┌─────────────┐         ┌─────────────┐                    │
│  │             │         │             │                    │
│  │     CPU     │◄───────►│  ML Engine  │                    │
│  │             │         │             │                    │
│  └──────┬──────┘         └──────┬──────┘                    │
│         │                       │                           │
│         └───────────┬───────────┘                           │
│                     ▼                                       │
│              ┌─────────────┐                                │
│              │   Memory    │                                │
│              │   (DDR)     │                                │
│              └─────────────┘                                │
│                                                             │
│  Problem: Memory bandwidth bottleneck                       │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    EdgeNPU Design                           │
│  ┌─────────────┐         ┌─────────────────────────────┐   │
│  │             │         │         EdgeNPU              │   │
│  │     CPU     │◄───────►│  ┌─────────────────────┐    │   │
│  │             │         │  │   On-chip Memory    │    │   │
│  └──────┬──────┘         │  │      (512KB)        │    │   │
│         │                │  └─────────┬───────────┘    │   │
│         │                │            │                │   │
│         │                │  ┌─────────▼───────────┐    │   │
│         │                │  │   16×16 PE Array    │    │   │
│         │                │  │   (Systolic Array)  │    │   │
│         │                │  └─────────────────────┘    │   │
│         │                └─────────────────────────────┘   │
│         │                       │                          │
│         └───────────┬───────────┘                          │
│                     ▼                                      │
│              ┌─────────────┐                               │
│              │   Memory    │                               │
│              │   (DDR)     │                               │
│              └─────────────┘                               │
│                                                            │
│  Solution: Data reuse in on-chip memory                    │
└────────────────────────────────────────────────────────────┘
```

### System Block Diagram

```
┌──────────────────────────────────────────────────────────────────────────┐
│                                EdgeNPU                                    │
│                                                                           │
│  ┌─────────────────────────────────────────────────────────────────────┐ │
│  │                           NPU Core                                   │ │
│  │                                                                      │ │
│  │  ┌────────────────────────────────────────────────────────────────┐ │ │
│  │  │                    PE Array (16×16 = 256 PEs)                  │ │ │
│  │  │                                                                 │ │ │
│  │  │   ┌────┬────┬────┬────┬────┬────┬────┬────┐                    │ │ │
│  │  │   │ PE │ PE │ PE │ PE │ PE │ PE │ PE │ PE │ ← Weights          │ │ │
│  │  │   ├────┼────┼────┼────┼────┼────┼────┼────┤                    │ │ │
│  │  │   │ PE │ PE │ PE │ PE │ PE │ PE │ PE │ PE │                    │ │ │
│  │  │   ├────┼────┼────┼────┼────┼────┼────┼────┤                    │ │ │
│  │  │   │ .. │ .. │ .. │ .. │ .. │ .. │ .. │ .. │                    │ │ │
│  │  │   ├────┼────┼────┼────┼────┼────┼────┼────┤                    │ │ │
│  │  │   │ PE │ PE │ PE │ PE │ PE │ PE │ PE │ PE │                    │ │ │
│  │  │   └────┴────┴────┴────┴────┴────┴────┴────┘                    │ │ │
│  │  │     ↑                                                           │ │ │
│  │  │   Activations                                                   │ │ │
│  │  └────────────────────────────────────────────────────────────────┘ │ │
│  │                                                                      │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐               │ │
│  │  │  Activation  │  │   Pooling    │  │ Quantization │               │ │
│  │  │     Unit     │  │     Unit     │  │     Unit     │               │ │
│  │  └──────────────┘  └──────────────┘  └──────────────┘               │ │
│  │                                                                      │ │
│  │  ┌────────────────────────────────────────────────────────────────┐ │ │
│  │  │                    Memory Subsystem                             │ │ │
│  │  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │ │ │
│  │  │  │Weight Buffer │  │  Act Buffer  │  │ Inst Buffer  │          │ │ │
│  │  │  │    256KB     │  │    256KB     │  │     16KB     │          │ │ │
│  │  │  └──────────────┘  └──────────────┘  └──────────────┘          │ │ │
│  │  └────────────────────────────────────────────────────────────────┘ │ │
│  │                                                                      │ │
│  │  ┌────────────────────────────────────────────────────────────────┐ │ │
│  │  │                       Controller                                │ │ │
│  │  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │ │ │
│  │  │  │  Instruction │  │   Scheduler  │  │  Dependency  │          │ │ │
│  │  │  │   Decoder    │  │              │  │   Checker    │          │ │ │
│  │  │  └──────────────┘  └──────────────┘  └──────────────┘          │ │ │
│  │  └────────────────────────────────────────────────────────────────┘ │ │
│  └─────────────────────────────────────────────────────────────────────┘ │
│                                                                           │
│  ┌─────────────────────────────────────────────────────────────────────┐ │
│  │                         DMA Engine (4 Channels)                      │ │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐             │ │
│  │  │Channel 0 │  │Channel 1 │  │Channel 2 │  │Channel 3 │             │ │
│  │  │ Weights  │  │   Acts   │  │  Output  │  │  Instr   │             │ │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘             │ │
│  └─────────────────────────────────────────────────────────────────────┘ │
│                                                                           │
│  ┌────────────────────────┐  ┌────────────────────────┐                  │
│  │     AXI4 Master        │  │    AXI4-Lite Slave     │                  │
│  │    (128-bit Data)      │  │    (32-bit Config)     │                  │
│  └────────────────────────┘  └────────────────────────┘                  │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## Platform Components

### Processing Element (PE)

Mỗi PE là đơn vị tính toán cơ bản, chứa:

- **8-bit Multiplier**: Nhân input activation với weight
- **32-bit Accumulator**: Tích lũy kết quả MAC
- **Weight Register**: Lưu trữ weight cho tính toán
- **Systolic Data Flow**: Truyền data theo chiều ngang và dọc

```
┌─────────────────────────────────────────┐
│            Processing Element           │
│                                         │
│  data_in ──►┌─────────┐                 │
│             │   MUL   │──►┌─────────┐   │
│  weight ───►│  8×8    │   │   ADD   │   │
│             └─────────┘   │  32-bit │   │
│                           └────┬────┘   │
│                                │        │
│                           ┌────▼────┐   │
│                           │   ACC   │───► acc_out
│                           │ 32-bit  │   │
│                           └─────────┘   │
│                                         │
│  data_in ─────────────────────────────► data_out
│                                         │
└─────────────────────────────────────────┘
```

### Systolic Array Operation

Systolic array hoạt động theo nguyên tắc "data reuse":

1. **Weight Stationary**: Weights được load một lần và giữ trong PE
2. **Data Flow**: Activations chảy qua array theo chiều ngang
3. **Accumulation**: Kết quả được tích lũy trong mỗi PE

```
Time T=0:        Time T=1:        Time T=2:
┌───┬───┬───┐    ┌───┬───┬───┐    ┌───┬───┬───┐
│ W │ W │ W │    │ W │ W │ W │    │ W │ W │ W │
├───┼───┼───┤    ├───┼───┼───┤    ├───┼───┼───┤
│ W │ W │ W │    │ W │ W │ W │    │ W │ W │ W │
├───┼───┼───┤    ├───┼───┼───┤    ├───┼───┼───┤
│ W │ W │ W │    │ W │ W │ W │    │ W │ W │ W │
└───┴───┴───┘    └───┴───┴───┘    └───┴───┴───┘
  ↑                ↑ ↑              ↑ ↑ ↑
  A0               A0 A1            A0 A1 A2
```

---

## Performance vs Power

### Performance Metrics

| Metric | Value | Condition |
|--------|-------|-----------|
| Peak TOPS | 0.512 TOPS | INT8, 1GHz |
| Sustained TOPS | ~0.4 TOPS | Typical workload |
| Memory Bandwidth | 16 GB/s | AXI4 128-bit @ 1GHz |
| Latency | < 1ms | Single layer inference |

### Power Efficiency

| Mode | Power | Performance |
|------|-------|-------------|
| Full Speed | < 1W | 512 GOPS |
| Power Save | < 0.3W | 128 GOPS |
| Idle | < 10mW | Clock gated |

### Efficiency Comparison

```
Performance per Watt (GOPS/W):

EdgeNPU (INT8)     ████████████████████████████████████████ 500+
GPU (Mobile)       ████████████ 150
CPU (ARM Cortex)   ██ 20
```

---

## Supported Operations

### Neural Network Layers

| Operation | Kernel Sizes | Notes |
|-----------|--------------|-------|
| **Convolution** | 1×1, 3×3, 5×5, 7×7 | Standard, Depthwise, Dilated |
| **Fully Connected** | Any | Matrix multiplication |
| **Pooling** | 2×2, 3×3 | Max, Average, Global Average |
| **Activation** | - | ReLU, ReLU6, Sigmoid, Tanh, Swish, GELU |
| **Element-wise** | - | Add, Multiply, Concat, Split |

### Activation Functions

```
ReLU:     f(x) = max(0, x)
ReLU6:    f(x) = min(max(0, x), 6)
Sigmoid:  f(x) = 1 / (1 + e^(-x))
Tanh:     f(x) = (e^x - e^(-x)) / (e^x + e^(-x))
Swish:    f(x) = x × sigmoid(x)
GELU:     f(x) = x × Φ(x)
```

### Quantization Support

EdgeNPU hỗ trợ quantization để tối ưu hiệu năng:

- **Per-tensor quantization**: Một scale/zero-point cho toàn tensor
- **Per-channel quantization**: Scale/zero-point riêng cho mỗi channel
- **Symmetric/Asymmetric**: Cả hai mode đều được hỗ trợ

```
Quantization Formula:
q = round(x / scale) + zero_point

Dequantization Formula:
x = (q - zero_point) × scale
```

---

## Supported Models

EdgeNPU được tối ưu cho các model phổ biến:

| Model | Input Size | Parameters | Supported |
|-------|------------|------------|-----------|
| MobileNetV1 | 224×224 | 4.2M | ✅ |
| MobileNetV2 | 224×224 | 3.4M | ✅ |
| MobileNetV3 | 224×224 | 5.4M | ✅ |
| EfficientNet-Lite | 224×224 | 4.7M | ✅ |
| ResNet-18 | 224×224 | 11.7M | ✅ |
| YOLO-Tiny | 416×416 | 6.0M | ✅ |
| SSD-MobileNet | 300×300 | 6.8M | ✅ |

---

## Getting Started

### For Software Developers

1. **Compile Model**: Sử dụng EdgeNPU Compiler để convert model
2. **Load Model**: Load compiled model vào EdgeNPU
3. **Run Inference**: Gọi inference API

```c
// Example: Run inference
#include "edgenpu_runtime.h"

int main() {
    // Initialize EdgeNPU
    edgenpu_context_t ctx;
    edgenpu_init(&ctx);
    
    // Load model
    edgenpu_model_t model;
    edgenpu_load_model(&ctx, "model.enpu", &model);
    
    // Prepare input
    float input[224*224*3];
    // ... fill input data ...
    
    // Run inference
    float output[1000];
    edgenpu_invoke(&ctx, &model, input, output);
    
    // Cleanup
    edgenpu_free_model(&model);
    edgenpu_deinit(&ctx);
    
    return 0;
}
```

### For Hardware Developers

1. **Integration**: Tích hợp EdgeNPU IP vào SoC
2. **Memory Map**: Cấu hình address space cho registers và buffers
3. **Clocking**: Cung cấp clock và reset signals
4. **Interrupts**: Kết nối interrupt line

```verilog
// Example: Instantiate EdgeNPU
npu_top #(
    .PE_ROWS     (16),
    .PE_COLS     (16),
    .DATA_WIDTH  (8),
    .AXI_DATA_W  (128),
    .AXI_ADDR_W  (40)
) u_edgenpu (
    .clk         (npu_clk),
    .rst_n       (npu_rst_n),
    
    // AXI4 Master
    .m_axi_*     (axi_master_*),
    
    // AXI4-Lite Slave
    .s_axil_*    (axil_slave_*),
    
    // Interrupt
    .irq         (npu_irq)
);
```

---

## Register Map

| Offset | Name | Access | Description |
|--------|------|--------|-------------|
| 0x000 | CTRL | R/W | Control register |
| 0x004 | STATUS | R | Status register |
| 0x008 | IRQ_EN | R/W | Interrupt enable |
| 0x00C | IRQ_STATUS | R/W1C | Interrupt status |
| 0x010 | VERSION | R | IP version |
| 0x014 | CONFIG | R | Configuration |
| 0x100 | DMA_CTRL | R/W | DMA control |
| 0x104 | DMA_STATUS | R | DMA status |
| 0x108 | DMA_SRC | R/W | DMA source address |
| 0x10C | DMA_DST | R/W | DMA destination address |
| 0x110 | DMA_LEN | R/W | DMA transfer length |

---

## Frequently Asked Questions

### Q: EdgeNPU có thể chạy model nào?

A: EdgeNPU hỗ trợ hầu hết các CNN model phổ biến như MobileNet, EfficientNet, ResNet, YOLO. Model cần được quantize sang INT8 để đạt hiệu năng tối ưu.

### Q: Làm sao để tối ưu model cho EdgeNPU?

A: 
1. Sử dụng quantization-aware training
2. Ưu tiên các layer được hỗ trợ native (Conv, FC, Pooling)
3. Tránh các operation phức tạp không được hỗ trợ

### Q: Power consumption thực tế là bao nhiêu?

A: Phụ thuộc vào workload và tần số hoạt động. Typical: 0.5-1W @ 1GHz với full utilization.

### Q: Có thể scale PE array không?

A: Có, PE array có thể được cấu hình từ 8×8 đến 32×32 tùy theo yêu cầu về performance và area.

---

## Resources

- [Architecture Document](../architecture/npu_architecture.md)
- [Mermaid Diagrams](../architecture/diagrams/mermaid_diagrams.md)
- [API Reference](../api_reference/)
- [RTL Source Code](../../rtl/)

---

*EdgeNPU - High Performance, Low Power Neural Processing Unit for Edge AI*
