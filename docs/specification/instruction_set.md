# EdgeNPU Instruction Set Reference

**Version 1.0.0**

---

## Instruction Format

All EdgeNPU instructions are 64-bit wide:

```
┌───────┬───────┬─────────┬─────────┬─────────┬────────────────────────────────┐
│ 63:60 │ 59:56 │  55:48  │  47:40  │  39:32  │             31:0               │
├───────┼───────┼─────────┼─────────┼─────────┼────────────────────────────────┤
│Opcode │ Flags │  DST    │  SRC0   │  SRC1   │          Immediate             │
│ 4-bit │ 4-bit │  8-bit  │  8-bit  │  8-bit  │            32-bit              │
└───────┴───────┴─────────┴─────────┴─────────┴────────────────────────────────┘
```

---

## Opcode Summary

| Opcode | Mnemonic | Category | Description |
|--------|----------|----------|-------------|
| 0x0 | NOP | Control | No operation |
| 0x1 | CONV | Compute | 2D Convolution |
| 0x2 | FC | Compute | Fully Connected |
| 0x3 | POOL | Compute | Pooling |
| 0x4 | ACT | Compute | Activation function |
| 0x5 | LOAD | Memory | Load from DDR |
| 0x6 | STORE | Memory | Store to DDR |
| 0x7 | SYNC | Control | Synchronization |
| 0x8 | ADD | Compute | Element-wise add |
| 0x9 | MUL | Compute | Element-wise multiply |
| 0xA | CONCAT | Data | Tensor concatenation |
| 0xB | SPLIT | Data | Tensor splitting |

---

## Control Instructions

### NOP - No Operation

**Opcode:** 0x0

**Format:**
```
NOP [cycles]
```

**Fields:**
| Field | Bits | Description |
|-------|------|-------------|
| Opcode | 63:60 | 0x0 |
| Flags | 59:56 | Reserved |
| Immediate | 31:0 | Number of cycles to wait |

**Example:**
```
NOP 100       ; Wait 100 cycles
```

---

### SYNC - Synchronization

**Opcode:** 0x7

**Format:**
```
SYNC [barrier_id]
```

**Description:** Wait for all pending operations to complete.

**Flags:**
| Bit | Name | Description |
|-----|------|-------------|
| 0 | WAIT_DMA | Wait for DMA complete |
| 1 | WAIT_COMPUTE | Wait for compute complete |
| 2 | IRQ | Generate interrupt |

---

## Compute Instructions

### CONV - 2D Convolution

**Opcode:** 0x1

**Format:**
```
CONV dst, src_act, src_weight [, flags]
```

**Fields:**
| Field | Bits | Description |
|-------|------|-------------|
| DST | 55:48 | Output buffer address |
| SRC0 | 47:40 | Activation buffer address |
| SRC1 | 39:32 | Weight buffer address |
| Immediate | 31:0 | Parameter descriptor address |

**Flags:**
| Bit | Name | Description |
|-----|------|-------------|
| 0 | RELU | Apply ReLU activation |
| 1 | BIAS | Add bias |
| 2 | RESIDUAL | Add residual connection |

**Parameter Descriptor (in memory):**
```
Offset 0x00: [15:0] input_height,  [31:16] input_width
Offset 0x04: [15:0] input_ch,      [31:16] output_ch
Offset 0x08: [3:0]  kernel_h,      [7:4]   kernel_w
             [11:8] stride_h,      [15:12] stride_w
Offset 0x0C: [7:0]  pad_top,       [15:8]  pad_bottom
             [23:16] pad_left,     [31:24] pad_right
```

---

### FC - Fully Connected

**Opcode:** 0x2

**Format:**
```
FC dst, src_act, src_weight [, flags]
```

**Fields:**
| Field | Bits | Description |
|-------|------|-------------|
| DST | 55:48 | Output buffer address |
| SRC0 | 47:40 | Input vector address |
| SRC1 | 39:32 | Weight matrix address |
| Immediate [15:0] | - | Input features |
| Immediate [31:16] | - | Output features |

---

### POOL - Pooling

**Opcode:** 0x3

**Format:**
```
POOL dst, src [, type]
```

**Immediate Field:**
| Bits | Description |
|------|-------------|
| 1:0 | Pool type (0=Max, 1=Avg, 2=Global) |
| 5:2 | Kernel height |
| 9:6 | Kernel width |
| 13:10 | Stride height |
| 17:14 | Stride width |

---

### ACT - Activation Function

**Opcode:** 0x4

**Format:**
```
ACT dst, src [, type]
```

**Activation Types (Immediate[2:0]):**
| Value | Function |
|-------|----------|
| 0 | None (passthrough) |
| 1 | ReLU |
| 2 | ReLU6 |
| 3 | Sigmoid |
| 4 | Tanh |
| 5 | Swish |
| 6 | GELU |

---

### ADD - Element-wise Addition

**Opcode:** 0x8

**Format:**
```
ADD dst, src0, src1
```

**Description:** Element-wise addition of two tensors.

---

### MUL - Element-wise Multiplication

**Opcode:** 0x9

**Format:**
```
MUL dst, src0, src1
```

---

## Memory Instructions

### LOAD - Load from DDR

**Opcode:** 0x5

**Format:**
```
LOAD dst, ddr_addr, length
```

**Fields:**
| Field | Bits | Description |
|-------|------|-------------|
| DST | 55:48 | Destination buffer (0=Weight, 1=Act) |
| Immediate[23:0] | - | Length in bytes |
| SRC0, SRC1 | - | DDR address (combined 16-bit) |

**Flags:**
| Bit | Name | Description |
|-----|------|-------------|
| 0 | 2D | 2D strided transfer |
| 1 | ASYNC | Non-blocking |

---

### STORE - Store to DDR

**Opcode:** 0x6

**Format:**
```
STORE ddr_addr, src, length
```

---

## Data Instructions

### CONCAT - Concatenation

**Opcode:** 0xA

**Format:**
```
CONCAT dst, src0, src1 [, axis]
```

**Immediate Field:**
| Bits | Description |
|------|-------------|
| 1:0 | Concatenation axis |
| 15:2 | Size of src0 along axis |
| 31:16 | Size of src1 along axis |

---

### SPLIT - Tensor Split

**Opcode:** 0xB

**Format:**
```
SPLIT dst0, dst1, src [, axis]
```

---

## Instruction Encoding Examples

### Example 1: Convolution with ReLU

```
Operation: Conv2D 3x3, 64 input channels, 128 output channels, ReLU

Instruction: 0x1100_0001_0000_1000

Breakdown:
  Opcode     = 0x1 (CONV)
  Flags      = 0x1 (RELU enabled)
  DST        = 0x00 (Output buffer 0)
  SRC0       = 0x01 (Activation buffer 1)
  SRC1       = 0x00 (Weight buffer 0)
  Immediate  = 0x0000_1000 (parameter descriptor at 0x1000)
```

### Example 2: Load Weights

```
Operation: Load 16KB weights from DDR 0x8000_0000

Instruction: 0x5000_8000_0000_4000

Breakdown:
  Opcode     = 0x5 (LOAD)
  Flags      = 0x0
  DST        = 0x00 (Weight buffer)
  SRC0:SRC1  = 0x8000:0x0000 (DDR address)
  Immediate  = 0x4000 (16KB length)
```

---

## Assembly Syntax

EdgeNPU assembly uses the following syntax:

```asm
; Comments start with semicolon
; Labels end with colon

start:
    ; Load weights
    LOAD    WB, 0x80000000, 65536
    SYNC    WAIT_DMA
    
    ; Load activations
    LOAD    AB, 0x80010000, 16384
    SYNC    WAIT_DMA
    
    ; Run convolution
    CONV    AB[1], AB[0], WB[0], RELU
    SYNC    WAIT_COMPUTE
    
    ; Store output
    STORE   0x80020000, AB[1], 16384
    SYNC    WAIT_DMA | IRQ
    
    ; Done
    NOP     0
```

---

## Instruction Latencies

| Instruction | Latency (cycles) | Notes |
|-------------|------------------|-------|
| NOP | 1 | |
| LOAD | Variable | Depends on size |
| STORE | Variable | Depends on size |
| CONV (3×3) | H×W×Ci×Co/256 | Pipelined |
| FC | M×N/256 | Pipelined |
| POOL | H×W | |
| ACT | H×W×C/16 | |
| ADD/MUL | H×W×C/16 | |
| SYNC | 1+ | Waits for pending |

---

*© 2026 EdgeNPU Project. All rights reserved.*
