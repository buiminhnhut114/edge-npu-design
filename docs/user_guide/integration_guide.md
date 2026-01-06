# EdgeNPU Integration Guide

**Version 1.0.0**

---

## Overview

This guide covers integrating EdgeNPU into SoC designs using AXI interconnect.

---

## System Architecture

```
┌────────────────────────────────────────────────────────────────────────┐
│                           SoC Top Level                                 │
│                                                                        │
│  ┌──────────────┐    ┌─────────────────┐    ┌────────────────────────┐ │
│  │              │    │                 │    │                        │ │
│  │  Processor   │◄──►│  AXI Interconn  │◄──►│      EdgeNPU           │ │
│  │  (ARM/RISC-V)│    │                 │    │      (Slave)           │ │
│  │              │    │                 │    │                        │ │
│  └──────────────┘    └────────┬────────┘    └───────────┬────────────┘ │
│                               │                         │              │
│                               │                         │ AXI Master   │
│                               │                         ▼              │
│                               │             ┌────────────────────────┐ │
│                               │             │                        │ │
│                               └────────────►│    DDR Controller      │ │
│                                             │                        │ │
│                                             └────────────────────────┘ │
└────────────────────────────────────────────────────────────────────────┘
```

---

## Interface Ports

### AXI4 Master (Data Port)

| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| m_axi_awid | 8 | Out | Write address ID |
| m_axi_awaddr | 40 | Out | Write address |
| m_axi_awlen | 8 | Out | Burst length |
| m_axi_awsize | 3 | Out | Burst size |
| m_axi_awburst | 2 | Out | Burst type |
| m_axi_awvalid | 1 | Out | Address valid |
| m_axi_awready | 1 | In | Address ready |
| m_axi_wdata | 128 | Out | Write data |
| m_axi_wstrb | 16 | Out | Write strobe |
| m_axi_wlast | 1 | Out | Write last |
| m_axi_wvalid | 1 | Out | Write valid |
| m_axi_wready | 1 | In | Write ready |
| m_axi_bid | 8 | In | Response ID |
| m_axi_bresp | 2 | In | Write response |
| m_axi_bvalid | 1 | In | Response valid |
| m_axi_bready | 1 | Out | Response ready |
| m_axi_arid | 8 | Out | Read address ID |
| m_axi_araddr | 40 | Out | Read address |
| m_axi_arlen | 8 | Out | Burst length |
| m_axi_arsize | 3 | Out | Burst size |
| m_axi_arburst | 2 | Out | Burst type |
| m_axi_arvalid | 1 | Out | Address valid |
| m_axi_arready | 1 | In | Address ready |
| m_axi_rid | 8 | In | Read ID |
| m_axi_rdata | 128 | In | Read data |
| m_axi_rresp | 2 | In | Read response |
| m_axi_rlast | 1 | In | Read last |
| m_axi_rvalid | 1 | In | Read valid |
| m_axi_rready | 1 | Out | Read ready |

### AXI4-Lite Slave (Control Port)

| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| s_axil_awaddr | 32 | In | Write address |
| s_axil_awvalid | 1 | In | Address valid |
| s_axil_awready | 1 | Out | Address ready |
| s_axil_wdata | 32 | In | Write data |
| s_axil_wstrb | 4 | In | Write strobe |
| s_axil_wvalid | 1 | In | Write valid |
| s_axil_wready | 1 | Out | Write ready |
| s_axil_bresp | 2 | Out | Write response |
| s_axil_bvalid | 1 | Out | Response valid |
| s_axil_bready | 1 | In | Response ready |
| s_axil_araddr | 32 | In | Read address |
| s_axil_arvalid | 1 | In | Address valid |
| s_axil_arready | 1 | Out | Address ready |
| s_axil_rdata | 32 | Out | Read data |
| s_axil_rresp | 2 | Out | Read response |
| s_axil_rvalid | 1 | Out | Read valid |
| s_axil_rready | 1 | In | Read ready |

### Clock and Reset

| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| clk | 1 | In | Core clock |
| rst_n | 1 | In | Active-low reset |
| axi_clk | 1 | In | AXI clock (optional) |

### Interrupt

| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| irq | 1 | Out | Interrupt request |

---

## Instantiation Example

### SystemVerilog

```systemverilog
edge_npu #(
    .AXI_DATA_WIDTH (128),
    .AXI_ADDR_WIDTH (40),
    .PE_ROWS        (16),
    .PE_COLS        (16)
) u_npu (
    // Clock and Reset
    .clk            (npu_clk),
    .rst_n          (npu_rst_n),
    
    // AXI Master (to DDR)
    .m_axi_awid     (npu_m_axi_awid),
    .m_axi_awaddr   (npu_m_axi_awaddr),
    .m_axi_awlen    (npu_m_axi_awlen),
    .m_axi_awsize   (npu_m_axi_awsize),
    .m_axi_awburst  (npu_m_axi_awburst),
    .m_axi_awvalid  (npu_m_axi_awvalid),
    .m_axi_awready  (npu_m_axi_awready),
    .m_axi_wdata    (npu_m_axi_wdata),
    .m_axi_wstrb    (npu_m_axi_wstrb),
    .m_axi_wlast    (npu_m_axi_wlast),
    .m_axi_wvalid   (npu_m_axi_wvalid),
    .m_axi_wready   (npu_m_axi_wready),
    .m_axi_bid      (npu_m_axi_bid),
    .m_axi_bresp    (npu_m_axi_bresp),
    .m_axi_bvalid   (npu_m_axi_bvalid),
    .m_axi_bready   (npu_m_axi_bready),
    .m_axi_arid     (npu_m_axi_arid),
    .m_axi_araddr   (npu_m_axi_araddr),
    .m_axi_arlen    (npu_m_axi_arlen),
    .m_axi_arsize   (npu_m_axi_arsize),
    .m_axi_arburst  (npu_m_axi_arburst),
    .m_axi_arvalid  (npu_m_axi_arvalid),
    .m_axi_arready  (npu_m_axi_arready),
    .m_axi_rid      (npu_m_axi_rid),
    .m_axi_rdata    (npu_m_axi_rdata),
    .m_axi_rresp    (npu_m_axi_rresp),
    .m_axi_rlast    (npu_m_axi_rlast),
    .m_axi_rvalid   (npu_m_axi_rvalid),
    .m_axi_rready   (npu_m_axi_rready),
    
    // AXI-Lite Slave (from CPU)
    .s_axil_awaddr  (npu_s_axil_awaddr),
    .s_axil_awvalid (npu_s_axil_awvalid),
    .s_axil_awready (npu_s_axil_awready),
    .s_axil_wdata   (npu_s_axil_wdata),
    .s_axil_wstrb   (npu_s_axil_wstrb),
    .s_axil_wvalid  (npu_s_axil_wvalid),
    .s_axil_wready  (npu_s_axil_wready),
    .s_axil_bresp   (npu_s_axil_bresp),
    .s_axil_bvalid  (npu_s_axil_bvalid),
    .s_axil_bready  (npu_s_axil_bready),
    .s_axil_araddr  (npu_s_axil_araddr),
    .s_axil_arvalid (npu_s_axil_arvalid),
    .s_axil_arready (npu_s_axil_arready),
    .s_axil_rdata   (npu_s_axil_rdata),
    .s_axil_rresp   (npu_s_axil_rresp),
    .s_axil_rvalid  (npu_s_axil_rvalid),
    .s_axil_rready  (npu_s_axil_rready),
    
    // Interrupt
    .irq            (npu_irq)
);
```

---

## Address Map

| Base Address | Size | Description |
|--------------|------|-------------|
| 0x4000_0000 | 4 KB | NPU Control Registers |
| 0x4000_1000 | 256 KB | Weight Buffer (optional direct access) |
| 0x4000_4_1000 | 256 KB | Activation Buffer (optional) |

---

## Clock & Reset Requirements

### Clock Domains

| Domain | Frequency | Description |
|--------|-----------|-------------|
| Core | 500-1000 MHz | PE array, compute |
| AXI | 200-400 MHz | Memory interface |

### Reset Sequence

1. Assert `rst_n` low for minimum 16 cycles
2. Deassert `rst_n` synchronously
3. Wait for `STATUS.READY` bit

---

## Interrupt Handling

### Edge-Triggered Mode

```c
void npu_isr(void) {
    uint32_t status = NPU_IRQ_STATUS;
    
    if (status & IRQ_DONE) {
        // Inference complete
        inference_done = true;
    }
    
    if (status & IRQ_ERROR) {
        // Handle error
        handle_error(NPU_STATUS >> 8);
    }
    
    // Clear interrupts
    NPU_IRQ_STATUS = status;
}
```

---

## Timing Constraints (SDC)

```tcl
# Create clocks
create_clock -period 2.0 -name npu_clk [get_ports clk]
create_clock -period 5.0 -name axi_clk [get_ports axi_clk]

# Clock domain crossing
set_clock_groups -asynchronous \
    -group [get_clocks npu_clk] \
    -group [get_clocks axi_clk]

# Input delays
set_input_delay -clock axi_clk -max 1.0 [get_ports s_axil_*]
set_input_delay -clock axi_clk -min 0.2 [get_ports s_axil_*]

# Output delays
set_output_delay -clock axi_clk -max 1.0 [get_ports m_axi_*]
set_output_delay -clock axi_clk -min 0.2 [get_ports m_axi_*]
```

---

## Power Management

### Power States

| State | Description | Wake Latency |
|-------|-------------|--------------|
| Active | Full operation | - |
| Idle | Clock gated | 1 cycle |
| Sleep | Power gated | 100 cycles |

### Entering Sleep Mode

```c
void npu_enter_sleep(void) {
    // Ensure idle
    while (NPU_STATUS & STATUS_BUSY);
    
    // Enable sleep
    NPU_CTRL = CTRL_SLEEP;
}
```

---

## Design Checklist

- [ ] AXI interconnect configured for 128-bit data width
- [ ] Address decode for 0x4000_0000 range
- [ ] Interrupt connected to CPU IRQ controller
- [ ] Clock and reset domain crossings handled
- [ ] Timing constraints applied
- [ ] Power domain isolation (if using sleep mode)

---

*© 2026 EdgeNPU Project. All rights reserved.*
