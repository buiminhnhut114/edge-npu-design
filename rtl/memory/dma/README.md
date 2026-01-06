# DMA Controller

Direct Memory Access controller for efficient data movement.

## Modules

- `dma_engine.sv` - Main DMA Engine
- `dma_descriptor.sv` - Descriptor Manager
- `dma_channel.sv` - DMA Channel
- `axi_master.sv` - AXI Master Interface

## Features

- Multi-channel support (4 channels)
- Scatter-gather DMA
- 2D/3D transfer support
- Interrupt on completion
- AXI4 interface

## Transfer Modes

1. **Linear** - 1D data transfer
2. **2D** - Feature map transfer
3. **3D** - Tensor transfer
