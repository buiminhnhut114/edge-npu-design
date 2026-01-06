# EdgeNPU Register Reference Manual

**Version 1.0.0**

---

## Overview

EdgeNPU provides a memory-mapped register interface accessible via AXI4-Lite bus. All registers are 32-bit aligned.

### Base Address Regions

| Region | Offset Range | Description |
|--------|--------------|-------------|
| Control | 0x000 - 0x0FF | Core control and status |
| DMA | 0x100 - 0x1FF | DMA engine registers |
| Compute | 0x200 - 0x2FF | Compute configuration |
| Debug | 0x300 - 0x3FF | Debug and performance |

---

## Control Registers (0x000 - 0x0FF)

### CTRL (0x000) - Control Register

| Bits | Name | Access | Reset | Description |
|------|------|--------|-------|-------------|
| 0 | START | R/W | 0 | Start inference execution |
| 1 | STOP | R/W | 0 | Stop current execution |
| 2 | RESET | R/W | 0 | Soft reset (auto-clear) |
| 3 | IRQ_EN | R/W | 0 | Global interrupt enable |
| 7:4 | MODE | R/W | 0 | Operating mode |
| 31:8 | Reserved | - | 0 | Reserved |

**MODE Field:**
| Value | Mode |
|-------|------|
| 0x0 | Inference |
| 0x1 | Debug |
| 0x2 | Test |

---

### STATUS (0x004) - Status Register

| Bits | Name | Access | Reset | Description |
|------|------|--------|-------|-------------|
| 0 | BUSY | R | 0 | NPU is executing |
| 1 | DONE | R | 0 | Execution complete |
| 2 | ERROR | R | 0 | Error occurred |
| 3 | DMA_BUSY | R | 0 | DMA transfer active |
| 7:4 | STATE | R | 0 | FSM state |
| 15:8 | ERROR_CODE | R | 0 | Error code |
| 31:16 | Reserved | - | 0 | Reserved |

**Error Codes:**
| Code | Description |
|------|-------------|
| 0x00 | No error |
| 0x01 | Invalid opcode |
| 0x02 | Memory access fault |
| 0x03 | DMA timeout |
| 0x04 | Arithmetic overflow |

---

### IRQ_ENABLE (0x008) - Interrupt Enable Register

| Bits | Name | Access | Reset | Description |
|------|------|--------|-------|-------------|
| 0 | DONE_EN | R/W | 0 | Enable completion interrupt |
| 1 | ERROR_EN | R/W | 0 | Enable error interrupt |
| 2 | DMA_DONE_EN | R/W | 0 | Enable DMA done interrupt |
| 3 | LAYER_DONE_EN | R/W | 0 | Enable layer completion IRQ |
| 31:4 | Reserved | - | 0 | Reserved |

---

### IRQ_STATUS (0x00C) - Interrupt Status Register

| Bits | Name | Access | Reset | Description |
|------|------|--------|-------|-------------|
| 0 | DONE | R/W1C | 0 | Execution complete |
| 1 | ERROR | R/W1C | 0 | Error occurred |
| 2 | DMA_DONE | R/W1C | 0 | DMA transfer complete |
| 3 | LAYER_DONE | R/W1C | 0 | Layer complete |
| 31:4 | Reserved | - | 0 | Reserved |

> **Note:** Write 1 to clear (W1C) bits.

---

### VERSION (0x010) - Version Register

| Bits | Name | Access | Reset | Description |
|------|------|--------|-------|-------------|
| 7:0 | PATCH | R | 0x00 | Patch version |
| 15:8 | MINOR | R | 0x00 | Minor version |
| 23:16 | MAJOR | R | 0x01 | Major version |
| 31:24 | VARIANT | R | 0x00 | Variant ID |

**Current Version:** 1.0.0 (0x00010000)

---

### CONFIG (0x014) - Configuration Register

| Bits | Name | Access | Reset | Description |
|------|------|--------|-------|-------------|
| 7:0 | PE_ROWS | R | 16 | Number of PE rows |
| 15:8 | PE_COLS | R | 16 | Number of PE columns |
| 17:16 | DATA_FMT | R | 0 | Default data format |
| 31:18 | Reserved | - | 0 | Reserved |

---

### PERF_CTRL (0x020) - Performance Counter Control

| Bits | Name | Access | Reset | Description |
|------|------|--------|-------|-------------|
| 0 | EN | R/W | 0 | Enable counters |
| 1 | RESET | R/W | 0 | Reset counters |
| 2 | FREEZE | R/W | 0 | Freeze counters |
| 31:3 | Reserved | - | 0 | Reserved |

---

### CYCLE_COUNT (0x024-0x028) - Cycle Counter

| Offset | Bits | Name | Access | Description |
|--------|------|------|--------|-------------|
| 0x024 | 31:0 | CYCLE_LO | R | Lower 32 bits |
| 0x028 | 15:0 | CYCLE_HI | R | Upper 16 bits |

---

## DMA Registers (0x100 - 0x1FF)

### DMA_CTRL (0x100) - DMA Control Register

| Bits | Name | Access | Reset | Description |
|------|------|--------|-------|-------------|
| 0 | START | R/W | 0 | Start DMA transfer |
| 1 | ABORT | R/W | 0 | Abort current transfer |
| 3:2 | DIR | R/W | 0 | Transfer direction |
| 5:4 | MODE | R/W | 0 | Transfer mode |
| 31:6 | Reserved | - | 0 | Reserved |

**Direction Field (DIR):**
| Value | Direction |
|-------|-----------|
| 0 | DDR → Weight Buffer |
| 1 | DDR → Activation Buffer |
| 2 | Output Buffer → DDR |
| 3 | Reserved |

**Mode Field:**
| Value | Mode |
|-------|------|
| 0 | Linear |
| 1 | 2D Stride |
| 2 | Scatter-Gather |
| 3 | Reserved |

---

### DMA_STATUS (0x104) - DMA Status Register

| Bits | Name | Access | Reset | Description |
|------|------|--------|-------|-------------|
| 0 | BUSY | R | 0 | Transfer in progress |
| 1 | DONE | R | 0 | Transfer complete |
| 2 | ERROR | R | 0 | Transfer error |
| 7:4 | STATE | R | 0 | DMA FSM state |
| 31:8 | BYTES_DONE | R | 0 | Bytes transferred |

---

### DMA_SRC_ADDR (0x108-0x10C) - DMA Source Address

| Offset | Bits | Name | Access | Description |
|--------|------|------|--------|-------------|
| 0x108 | 31:0 | SRC_LO | R/W | Source address [31:0] |
| 0x10C | 7:0 | SRC_HI | R/W | Source address [39:32] |

---

### DMA_DST_ADDR (0x110-0x114) - DMA Destination Address

| Offset | Bits | Name | Access | Description |
|--------|------|------|--------|-------------|
| 0x110 | 31:0 | DST_LO | R/W | Destination address [31:0] |
| 0x114 | 7:0 | DST_HI | R/W | Destination address [39:32] |

---

### DMA_LENGTH (0x118) - DMA Transfer Length

| Bits | Name | Access | Reset | Description |
|------|------|--------|-------|-------------|
| 23:0 | LENGTH | R/W | 0 | Transfer length in bytes |
| 31:24 | Reserved | - | 0 | Reserved |

---

### DMA_STRIDE (0x11C) - DMA 2D Stride

| Bits | Name | Access | Reset | Description |
|------|------|--------|-------|-------------|
| 15:0 | SRC_STRIDE | R/W | 0 | Source stride (bytes) |
| 31:16 | DST_STRIDE | R/W | 0 | Destination stride (bytes) |

---

## Compute Registers (0x200 - 0x2FF)

### CONV_CTRL (0x200) - Convolution Control

| Bits | Name | Access | Reset | Description |
|------|------|--------|-------|-------------|
| 0 | START | R/W | 0 | Start convolution |
| 2:1 | ACT_FUNC | R/W | 0 | Activation function |
| 4:3 | DATA_FMT | R/W | 0 | Data format |
| 5 | BIAS_EN | R/W | 0 | Enable bias addition |
| 31:6 | Reserved | - | 0 | Reserved |

---

### CONV_INPUT_DIM (0x204) - Input Dimensions

| Bits | Name | Access | Reset | Description |
|------|------|--------|-------|-------------|
| 15:0 | HEIGHT | R/W | 0 | Input height |
| 31:16 | WIDTH | R/W | 0 | Input width |

---

### CONV_INPUT_CH (0x208) - Input Channels

| Bits | Name | Access | Reset | Description |
|------|------|--------|-------|-------------|
| 15:0 | CHANNELS | R/W | 0 | Number of input channels |
| 31:16 | OUTPUT_CH | R/W | 0 | Number of output channels |

---

### CONV_KERNEL (0x20C) - Kernel Configuration

| Bits | Name | Access | Reset | Description |
|------|------|--------|-------|-------------|
| 3:0 | K_HEIGHT | R/W | 0 | Kernel height |
| 7:4 | K_WIDTH | R/W | 0 | Kernel width |
| 11:8 | STRIDE_H | R/W | 1 | Vertical stride |
| 15:12 | STRIDE_W | R/W | 1 | Horizontal stride |
| 31:16 | Reserved | - | 0 | Reserved |

---

### CONV_PADDING (0x210) - Padding Configuration

| Bits | Name | Access | Reset | Description |
|------|------|--------|-------|-------------|
| 7:0 | PAD_TOP | R/W | 0 | Top padding |
| 15:8 | PAD_BOTTOM | R/W | 0 | Bottom padding |
| 23:16 | PAD_LEFT | R/W | 0 | Left padding |
| 31:24 | PAD_RIGHT | R/W | 0 | Right padding |

---

## Debug Registers (0x300 - 0x3FF)

### DEBUG_CTRL (0x300) - Debug Control

| Bits | Name | Access | Reset | Description |
|------|------|--------|-------|-------------|
| 0 | TRACE_EN | R/W | 0 | Enable trace output |
| 1 | BREAK_EN | R/W | 0 | Enable breakpoints |
| 2 | SINGLE_STEP | R/W | 0 | Single step mode |
| 31:3 | Reserved | - | 0 | Reserved |

---

### DEBUG_PC (0x304) - Program Counter

| Bits | Name | Access | Reset | Description |
|------|------|--------|-------|-------------|
| 15:0 | PC | R | 0 | Current instruction address |
| 31:16 | Reserved | - | 0 | Reserved |

---

### DEBUG_BREAKPOINT (0x308) - Breakpoint Address

| Bits | Name | Access | Reset | Description |
|------|------|--------|-------|-------------|
| 15:0 | BP_ADDR | R/W | 0 | Breakpoint address |
| 16 | BP_EN | R/W | 0 | Breakpoint enable |
| 31:17 | Reserved | - | 0 | Reserved |

---

## Register Access Examples

### C Code Example

```c
#include <stdint.h>

#define NPU_BASE        0x40000000

#define NPU_CTRL        (*(volatile uint32_t *)(NPU_BASE + 0x000))
#define NPU_STATUS      (*(volatile uint32_t *)(NPU_BASE + 0x004))
#define NPU_IRQ_EN      (*(volatile uint32_t *)(NPU_BASE + 0x008))
#define NPU_IRQ_STATUS  (*(volatile uint32_t *)(NPU_BASE + 0x00C))
#define NPU_DMA_CTRL    (*(volatile uint32_t *)(NPU_BASE + 0x100))
#define NPU_DMA_SRC_LO  (*(volatile uint32_t *)(NPU_BASE + 0x108))
#define NPU_DMA_DST_LO  (*(volatile uint32_t *)(NPU_BASE + 0x110))
#define NPU_DMA_LENGTH  (*(volatile uint32_t *)(NPU_BASE + 0x118))

// Start inference
void npu_start(void) {
    NPU_CTRL = 0x01;  // Set START bit
}

// Wait for completion
void npu_wait_done(void) {
    while (!(NPU_STATUS & 0x02));  // Wait for DONE bit
}

// DMA transfer
void npu_dma_transfer(uint32_t src, uint32_t dst, uint32_t len) {
    NPU_DMA_SRC_LO = src;
    NPU_DMA_DST_LO = dst;
    NPU_DMA_LENGTH = len;
    NPU_DMA_CTRL = 0x01;  // Start DMA
    
    while (!(NPU_STATUS & 0x08));  // Wait for DMA complete
}
```

---

## Revision History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-01-06 | Initial release |

---

*© 2026 EdgeNPU Project. All rights reserved.*
