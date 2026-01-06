# EdgeNPU Architecture Document

## 1. Overview

EdgeNPU is a high-performance, low-power Neural Processing Unit designed for edge AI applications. It features a systolic array architecture optimized for matrix multiplication operations common in neural network inference.

## 2. Key Features

- **16x16 Systolic Array**: 256 Processing Elements for parallel computation
- **Multi-precision Support**: INT8, INT16, FP16, BF16
- **On-chip Memory**: 512KB total (256KB weights + 256KB activations)
- **DMA Engine**: High-bandwidth data movement
- **Activation Functions**: ReLU, ReLU6, Sigmoid, Tanh, Swish, GELU
- **Pooling Operations**: Max, Average, Global Average

## 3. Block Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              EdgeNPU                                     │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                         NPU Core                                  │   │
│  │                                                                   │   │
│  │  ┌────────────────────────────────────────────────────────────┐  │   │
│  │  │                    PE Array (16x16)                         │  │   │
│  │  │  ┌─────┬─────┬─────┬─────┬─────┬─────┬─────┬─────┐         │  │   │
│  │  │  │ PE  │ PE  │ PE  │ ... │ PE  │ PE  │ PE  │ PE  │  ←Weights│  │   │
│  │  │  ├─────┼─────┼─────┼─────┼─────┼─────┼─────┼─────┤         │  │   │
│  │  │  │ PE  │ PE  │ PE  │ ... │ PE  │ PE  │ PE  │ PE  │         │  │   │
│  │  │  ├─────┼─────┼─────┼─────┼─────┼─────┼─────┼─────┤         │  │   │
│  │  │  │ ... │ ... │ ... │ ... │ ... │ ... │ ... │ ... │         │  │   │
│  │  │  ├─────┼─────┼─────┼─────┼─────┼─────┼─────┼─────┤         │  │   │
│  │  │  │ PE  │ PE  │ PE  │ ... │ PE  │ PE  │ PE  │ PE  │         │  │   │
│  │  │  └─────┴─────┴─────┴─────┴─────┴─────┴─────┴─────┘         │  │   │
│  │  │    ↑                                                        │  │   │
│  │  │  Activations                                                │  │   │
│  │  └────────────────────────────────────────────────────────────┘  │   │
│  │                                                                   │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐            │   │
│  │  │ Activation   │  │   Pooling    │  │ Quantization │            │   │
│  │  │     Unit     │  │     Unit     │  │     Unit     │            │   │
│  │  └──────────────┘  └──────────────┘  └──────────────┘            │   │
│  │                                                                   │   │
│  │  ┌──────────────────────────────────────────────────────────────┐│   │
│  │  │                    Memory Subsystem                          ││   │
│  │  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐        ││   │
│  │  │  │ Weight Buffer│  │   Act Buffer │  │ Output Buffer│        ││   │
│  │  │  │    256KB     │  │    256KB     │  │    (shared)  │        ││   │
│  │  │  └──────────────┘  └──────────────┘  └──────────────┘        ││   │
│  │  └──────────────────────────────────────────────────────────────┘│   │
│  │                                                                   │   │
│  │  ┌──────────────────────────────────────────────────────────────┐│   │
│  │  │                      Controller                               ││   │
│  │  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐        ││   │
│  │  │  │  Instruction │  │   Scheduler  │  │  Dependency  │        ││   │
│  │  │  │   Decoder    │  │              │  │   Checker    │        ││   │
│  │  │  └──────────────┘  └──────────────┘  └──────────────┘        ││   │
│  │  └──────────────────────────────────────────────────────────────┘│   │
│  └───────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                       DMA Engine                                  │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐          │   │
│  │  │ Channel 0│  │ Channel 1│  │ Channel 2│  │ Channel 3│          │   │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘          │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│  ┌────────────────────────┐  ┌────────────────────────┐                 │
│  │     AXI4 Master        │  │    AXI4-Lite Slave     │                 │
│  │    (Data Path)         │  │    (Register Access)   │                 │
│  └────────────────────────┘  └────────────────────────┘                 │
└─────────────────────────────────────────────────────────────────────────┘
```

## 4. Processing Element (PE)

Each PE contains:
- 8-bit signed multiplier
- 32-bit accumulator
- Weight register
- Systolic data flow (horizontal and vertical)

## 5. Memory Hierarchy

| Buffer | Size | Purpose |
|--------|------|---------|
| Weight Buffer | 256 KB | Store weights for current layer |
| Activation Buffer | 256 KB | Store input/output activations |
| Instruction Buffer | 16 KB | Store NPU instructions |

## 6. Supported Operations

### Convolution
- 1x1, 3x3, 5x5, 7x7 kernels
- Depthwise separable convolution
- Stride 1, 2
- Dilation support

### Fully Connected
- Matrix multiplication

### Element-wise
- Add, Multiply
- Concatenation, Split

### Activation
- ReLU, ReLU6, Sigmoid, Tanh, Swish, GELU

### Pooling
- Max Pooling (2x2, 3x3)
- Average Pooling
- Global Average Pooling

## 7. Performance

- **Peak Performance**: 512 GOPS @ 1GHz (INT8)
- **Power**: < 1W (target)
- **Efficiency**: > 500 GOPS/W

## 8. Interface

- **AXI4 Master**: 128-bit data, 40-bit address
- **AXI4-Lite Slave**: 32-bit data, 32-bit address
- **Interrupt**: Single interrupt line
