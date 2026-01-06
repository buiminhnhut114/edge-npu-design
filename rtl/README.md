# EdgeNPU RTL Design

## Architecture Overview

EdgeNPU là một Neural Processing Unit được thiết kế cho edge AI inference với các đặc điểm:

- **16x16 Systolic PE Array** - 256 MACs song song
- **INT8 Quantization** - Tối ưu cho inference
- **AXI4 Interface** - Tương thích SoC
- **JTAG Debug** - Hỗ trợ debug trên silicon

## Module Hierarchy

```
npu_top_v2
├── instruction_scheduler      # Instruction queue & scheduling
├── instruction_decoder        # Decode instructions to control signals
├── pe_array                   # 16x16 Systolic array
│   └── pe (x256)             # Processing Element with MAC
├── conv_controller           # Convolution dataflow control
├── depthwise_conv            # Depthwise separable convolution
├── activation_unit           # ReLU, ReLU6, Sigmoid, Tanh, Swish, GELU
├── batchnorm_unit            # Fused BatchNorm + Scale
├── pooling_unit              # Max, Avg, Global pooling
├── softmax_unit              # Softmax for classification
├── elementwise_unit          # Add, Sub, Mul, Max, Min
├── weight_buffer             # 256KB weight storage
├── activation_buffer         # 256KB activation storage
├── dma_engine                # 4-channel AXI4 DMA
└── npu_debug_if              # JTAG debug interface
```

## New Modules (V2)

### 1. Batch Normalization Unit (`batchnorm_unit.sv`)
- Fused BatchNorm + Scale for inference
- Pre-computed scale/bias parameters
- 3-stage pipeline: Read → Multiply → Add+Saturate

### 2. Softmax Unit (`softmax_unit.sv`)
- LUT-based exponential approximation
- Numerical stability with max subtraction
- Supports up to 1024 classes

### 3. Element-wise Unit (`elementwise_unit.sv`)
- Operations: Add, Sub, Mul, Max, Min, Abs, Neg
- For skip connections (ResNet, MobileNet)
- Single-cycle latency

### 4. Convolution Controller (`conv_controller.sv`)
- Im2Col transformation
- Tiling for large feature maps
- PE array scheduling

### 5. Depthwise Convolution (`depthwise_conv.sv`)
- Efficient depthwise separable conv
- Line buffer based sliding window
- Supports kernel 1x1 to 7x7

### 6. Instruction Decoder (`instruction_decoder.sv`)
- Decodes 64-bit instructions
- Generates control signals
- Operation classification

### 7. Instruction Scheduler (`instruction_scheduler.sv`)
- 16-entry instruction queue
- Resource-aware scheduling
- Dependency tracking

### 8. Debug Interface (`npu_debug_if.sv`)
- JTAG TAP controller
- Register/Memory access
- Halt/Resume/Step control
- Breakpoint support

## Supported Operations

| Operation | Opcode | Description |
|-----------|--------|-------------|
| NOP       | 0x0    | No operation |
| CONV      | 0x1    | 2D Convolution |
| FC        | 0x2    | Fully Connected |
| POOL      | 0x3    | Pooling |
| ACT       | 0x4    | Activation |
| LOAD      | 0x5    | Load from memory |
| STORE     | 0x6    | Store to memory |
| SYNC      | 0x7    | Synchronization |
| ADD       | 0x8    | Element-wise add |
| MUL       | 0x9    | Element-wise mul |
| CONCAT    | 0xA    | Concatenation |
| SPLIT     | 0xB    | Split tensor |

## Register Map

| Offset | Name | Description |
|--------|------|-------------|
| 0x000  | CTRL | Control register |
| 0x004  | STATUS | Status register |
| 0x008  | IRQ_EN | Interrupt enable |
| 0x00C  | IRQ_STATUS | Interrupt status |
| 0x010  | VERSION | NPU version |
| 0x100  | DMA_CTRL | DMA control |
| 0x200  | CONV_CTRL | Convolution control |
| 0x210  | BN_CTRL | BatchNorm control |
| 0x220  | SOFTMAX | Softmax control |

## Build & Simulation

```bash
# Compile
iverilog -f rtl/filelist.f -o sim/npu_sim

# Run simulation
vvp sim/npu_sim

# View waveforms
gtkwave sim/npu.vcd
```

## Integration

NPU có thể tích hợp vào SoC qua:
- **AXI4 Master** - DMA access to system memory
- **AXI4-Lite Slave** - Register configuration
- **Interrupt** - Completion notification
- **JTAG** - Debug access
