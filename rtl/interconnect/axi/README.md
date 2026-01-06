# AXI Interface

AXI4/AXI4-Lite interfaces for NPU integration.

## Modules

- `axi4_slave.sv` - AXI4 Slave Interface (Data Path)
- `axi4_master.sv` - AXI4 Master Interface (DMA)
- `axi4_lite_slave.sv` - AXI4-Lite Slave (Register Access)
- `axi_crossbar.sv` - AXI Crossbar (Internal)

## Interface Specifications

### AXI4 (Data Path)
- Data Width: 128/256 bits
- Address Width: 40 bits
- Burst Support: INCR, WRAP

### AXI4-Lite (Control)
- Data Width: 32 bits
- Address Width: 32 bits
