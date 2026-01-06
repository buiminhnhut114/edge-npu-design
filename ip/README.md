# EdgeNPU IP Cores Library

A comprehensive collection of reusable IP cores designed for the EdgeNPU project.

## IP Catalog

### Clock & Reset (`clk_rst/`)

| IP | Description |
|---|---|
| `clk_rst_gen.sv` | Multi-domain clock generator with configurable dividers |
| `reset_sync.sv` | Reset synchronizer for async reset deassertion |
| `cdc_sync.sv` | CDC synchronizers (2FF, pulse, handshake modes) |

### AXI Interfaces (`axi/`)

| IP | Description |
|---|---|
| `axi4_master.sv` | Full AXI4 Master with burst support |
| `axi4_slave.sv` | AXI4 Slave with memory interface |
| `axi4_stream_master.sv` | AXI4-Stream Master for data streaming |
| `axi4_stream_slave.sv` | AXI4-Stream Slave with FIFO buffering |

### APB Interface (`apb/`)

| IP | Description |
|---|---|
| `apb_bridge.sv` | AXI-Lite to APB protocol bridge |

### Memory Controllers (`memory/`)

| IP | Description |
|---|---|
| `sync_fifo.sv` | Synchronous FIFO with configurable depth |
| `async_fifo.sv` | Async FIFO with Gray-code pointers for CDC |
| `sram_dp.sv` | True dual-port SRAM |
| `mem_arbiter.sv` | Multi-master arbiter (round-robin/priority) |

### Utility IPs (`utils/`)

| IP | Description |
|---|---|
| `interrupt_ctrl.sv` | Interrupt controller with edge/level triggering |
| `gpio_ctrl.sv` | GPIO with direction control and interrupts |
| `timer.sv` | Timer with prescaler and PWM output |
| `watchdog.sv` | Watchdog timer with early warning |

### NPU-Specific IPs (`npu/`)

| IP | Description |
|---|---|
| `quantizer.sv` | INT8 quantization with per-channel support |
| `dequantizer.sv` | Dequantization to higher precision |
| `data_reshaper.sv` | Tensor reshape (NHWC ↔ NCHW) |
| `perf_counter.sv` | Hardware performance monitoring |

## Usage

### Include in Project

Add to `rtl/filelist.f`:
```
// IP Cores
ip/clk_rst/clk_rst_gen.sv
ip/clk_rst/reset_sync.sv
ip/clk_rst/cdc_sync.sv
ip/axi/axi4_master.sv
ip/axi/axi4_slave.sv
ip/axi/axi4_stream_master.sv
ip/axi/axi4_stream_slave.sv
ip/apb/apb_bridge.sv
ip/memory/sync_fifo.sv
ip/memory/async_fifo.sv
ip/memory/sram_dp.sv
ip/memory/mem_arbiter.sv
ip/utils/interrupt_ctrl.sv
ip/utils/gpio_ctrl.sv
ip/utils/timer.sv
ip/utils/watchdog.sv
ip/npu/quantizer.sv
ip/npu/dequantizer.sv
ip/npu/data_reshaper.sv
ip/npu/perf_counter.sv
```

### Example Instantiation

```systemverilog
// Synchronous FIFO
sync_fifo #(
    .DATA_WIDTH(128),
    .DEPTH(32)
) u_fifo (
    .clk(clk),
    .rst_n(rst_n),
    .wr_en(wr_en),
    .wr_data(wr_data),
    .full(full),
    .rd_en(rd_en),
    .rd_data(rd_data),
    .empty(empty)
);
```

## Verification

Run IP testbenches:
```bash
# Individual IP test
make sim_ip IP=sync_fifo

# All IP tests
make sim_ip_all
```

## Directory Structure

```
ip/
├── README.md           # This file
├── clk_rst/           # Clock & Reset
├── axi/               # AXI Interfaces
├── apb/               # APB Interface
├── memory/            # Memory Controllers
├── utils/             # Utility IPs
├── npu/               # NPU-Specific IPs
├── generated/         # Auto-generated IPs
└── third_party/       # Third-party IPs
```

## License

MIT License - See project root LICENSE file.
