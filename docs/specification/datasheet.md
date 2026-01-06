# EdgeNPU Datasheet

**Version 1.0.0** | **Document Revision 1.0**

---

## Product Overview

EdgeNPU is a high-performance, low-power Neural Processing Unit designed for edge AI applications. It features a 16×16 systolic array architecture optimized for convolutional neural network (CNN) inference.

---

## Key Features

| Feature | Specification |
|---------|---------------|
| Architecture | Systolic Array |
| PE Array Size | 16 × 16 (256 PEs) |
| Peak Performance | 512 GOPS @ 1 GHz (INT8) |
| Data Formats | INT8, INT16, FP16, BF16 |
| On-chip Memory | 528 KB total |
| Host Interface | AXI4 (128-bit) |
| Control Interface | AXI4-Lite (32-bit) |
| Power Consumption | < 500 mW (typical) |
| Technology Node | 28nm / 16nm / 7nm compatible |

---

## Block Diagram

```
                    ┌─────────────────────────────────────────────────────────┐
                    │                      EdgeNPU                             │
                    │  ┌─────────────────────────────────────────────────────┐ │
                    │  │              Host Interface (AXI4)                  │ │
                    │  └────────────────────┬────────────────────────────────┘ │
                    │                       │                                  │
     ┌──────────┐   │  ┌────────────────────┴────────────────────┐            │
     │          │   │  │           DMA Controller                 │            │
     │   DDR    │◄──┼──┤    • 2D/3D DMA transfers                │            │
     │  Memory  │   │  │    • Scatter/Gather support             │            │
     │          │   │  └────────────────────┬────────────────────┘            │
     └──────────┘   │                       │                                  │
                    │  ┌────────────┬───────┴───────┬────────────┐            │
                    │  │            │               │            │            │
                    │  ▼            ▼               ▼            ▼            │
                    │  ┌────────┐ ┌────────┐ ┌──────────┐ ┌──────────┐        │
                    │  │ Weight │ │  Act.  │ │  Inst.   │ │ Output   │        │
                    │  │ Buffer │ │ Buffer │ │  Buffer  │ │ Buffer   │        │
                    │  │ 256KB  │ │ 256KB  │ │   16KB   │ │   -      │        │
                    │  └───┬────┘ └───┬────┘ └────┬─────┘ └────▲─────┘        │
                    │      │          │           │            │              │
                    │      ▼          ▼           ▼            │              │
                    │  ┌──────────────────────────────────────────────────┐   │
                    │  │              NPU Controller                       │   │
                    │  │    • Instruction Fetch/Decode                    │   │
                    │  │    • Scheduling & Orchestration                  │   │
                    │  └──────────────────────┬───────────────────────────┘   │
                    │                         │                               │
                    │  ┌──────────────────────┴───────────────────────────┐   │
                    │  │                                                   │   │
                    │  │            ┌───────────────────┐                 │   │
                    │  │            │   PE Array        │                 │   │
                    │  │            │   16 × 16         │                 │   │
                    │  │ Weights ──►│   ┌─┬─┬─┬─┐      │──► Outputs      │   │
                    │  │            │   ├─┼─┼─┼─┤      │                 │   │
                    │  │ Activations│   ├─┼─┼─┼─┤      │                 │   │
                    │  │     │      │   ├─┼─┼─┼─┤      │                 │   │
                    │  │     ▼      │   └─┴─┴─┴─┘      │                 │   │
                    │  │            └───────────────────┘                 │   │
                    │  │                     │                            │   │
                    │  │  ┌──────────────────┼──────────────────┐        │   │
                    │  │  │                  ▼                  │        │   │
                    │  │  │  ┌────────┐ ┌─────────┐ ┌────────┐ │        │   │
                    │  │  │  │ ReLU   │ │ Pooling │ │ Quant  │ │        │   │
                    │  │  │  │ Sigmoid│ │ Max/Avg │ │ INT8   │ │        │   │
                    │  │  │  │ GELU   │ │ Global  │ │        │ │        │   │
                    │  │  │  └────────┘ └─────────┘ └────────┘ │        │   │
                    │  │  └─────────── Post-Processing ────────┘        │   │
                    │  └──────────────────────────────────────────────────┘   │
                    │                                                         │
                    │  ┌─────────────────────────────────────────────────────┐ │
                    │  │         Control Interface (AXI4-Lite)               │ │
                    │  └─────────────────────────────────────────────────────┘ │
                    └─────────────────────────────────────────────────────────┘
```

---

## Specifications

### Compute Engine

| Parameter | Value | Description |
|-----------|-------|-------------|
| PE Array Dimensions | 16 × 16 | 256 Processing Elements |
| MAC per PE | 1 | 8-bit × 8-bit → 32-bit accumulator |
| Peak INT8 GOPS | 512 | @ 1 GHz clock |
| Peak INT16 GOPS | 256 | @ 1 GHz clock |
| Peak FP16 GFLOPS | 128 | @ 1 GHz clock |

### Memory Subsystem

| Buffer | Size | Width | Description |
|--------|------|-------|-------------|
| Weight Buffer | 256 KB | 128-bit | Stores convolution weights |
| Activation Buffer | 256 KB | 128-bit | Stores input/output activations |
| Instruction Buffer | 16 KB | 64-bit | NPU microcode storage |
| Total On-chip | 528 KB | - | Combined SRAM |

### Interfaces

| Interface | Type | Width | Description |
|-----------|------|-------|-------------|
| Data Port | AXI4 | 128-bit | DDR memory access |
| Control Port | AXI4-Lite | 32-bit | Register configuration |
| Interrupt | Level | 1-bit | Completion/error signaling |

### Supported Operations

| Category | Operations |
|----------|------------|
| Convolution | Conv2D, DepthwiseConv2D, TransposeConv2D |
| Activation | ReLU, ReLU6, Sigmoid, Tanh, Swish, GELU |
| Pooling | MaxPool, AvgPool, GlobalPool |
| Other | FullyConnected, Add, Multiply, Concat |

---

## Instruction Set

| Opcode | Mnemonic | Description |
|--------|----------|-------------|
| 0x0 | NOP | No operation |
| 0x1 | CONV | Convolution operation |
| 0x2 | FC | Fully connected layer |
| 0x3 | POOL | Pooling operation |
| 0x4 | ACT | Activation function |
| 0x5 | LOAD | Load data from memory |
| 0x6 | STORE | Store data to memory |
| 0x7 | SYNC | Synchronization barrier |
| 0x8 | ADD | Element-wise addition |
| 0x9 | MUL | Element-wise multiplication |
| 0xA | CONCAT | Tensor concatenation |
| 0xB | SPLIT | Tensor splitting |

---

## Register Map

| Offset | Name | R/W | Description |
|--------|------|-----|-------------|
| 0x000 | CTRL | R/W | Control register |
| 0x004 | STATUS | R | Status register |
| 0x008 | IRQ_EN | R/W | Interrupt enable |
| 0x00C | IRQ_STATUS | R/W1C | Interrupt status |
| 0x010 | VERSION | R | Hardware version |
| 0x014 | CONFIG | R | Configuration info |
| 0x020 | PERF_CNT | R | Performance counter |
| 0x100 | DMA_CTRL | R/W | DMA control |
| 0x104 | DMA_STATUS | R | DMA status |
| 0x108 | DMA_SRC | R/W | DMA source address |
| 0x10C | DMA_DST | R/W | DMA destination address |
| 0x110 | DMA_LEN | R/W | DMA transfer length |

---

## Electrical Characteristics

### Power Consumption (Typical @ 28nm)

| Mode | Power | Conditions |
|------|-------|------------|
| Active (Peak) | 500 mW | Full PE utilization, 1 GHz |
| Active (Typical) | 300 mW | 60% utilization, 800 MHz |
| Idle | 50 mW | Clock gated |
| Sleep | 5 mW | Power gated |

### Operating Conditions

| Parameter | Min | Typical | Max | Unit |
|-----------|-----|---------|-----|------|
| Core Voltage | 0.72 | 0.80 | 0.88 | V |
| I/O Voltage | 1.62 | 1.80 | 1.98 | V |
| Operating Temp | -40 | 25 | 105 | °C |
| Clock Frequency | - | 800 | 1000 | MHz |

---

## Package Information

EdgeNPU is designed to be integrated as an IP block in SoC designs.

| Parameter | Value |
|-----------|-------|
| Design Type | Hard IP / Soft IP |
| Area Estimate | ~2.5 mm² @ 28nm |
| Gate Count | ~5M gates |

---

## Ordering Information

| Part Number | Description |
|-------------|-------------|
| EDGENPU-RTL | RTL source package |
| EDGENPU-NETLIST | Synthesized netlist |
| EDGENPU-GDS | Physical design (GDSII) |

---

## Revision History

| Version | Date | Description |
|---------|------|-------------|
| 1.0 | 2026-01-06 | Initial release |

---

*© 2026 EdgeNPU Project. All rights reserved.*
