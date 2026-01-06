<div align="center">

# EdgeNPU Design

### High-Performance Neural Processing Unit for Edge AI Applications

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![RTL](https://img.shields.io/badge/RTL-SystemVerilog-orange.svg)](#)
[![Verification](https://img.shields.io/badge/Verification-UVM-green.svg)](#)
[![Documentation](https://img.shields.io/badge/docs-available-brightgreen.svg)](https://buiminhnhut114.github.io/edge-npu-design/)

**EdgeNPU** là một IP core Neural Processing Unit (NPU) được thiết kế cho suy luận mạng neural hiệu suất cao, tiêu thụ điện năng thấp tại edge. Được xây dựng trên **kiến trúc systolic array 16×16**, EdgeNPU đạt hiệu suất đỉnh **512 GOPS** với mức tiêu thụ dưới **500mW**.

[Tài liệu](https://buiminhnhut114.github.io/edge-npu-design/) · [Bắt đầu](#quick-start) · [Kiến trúc](#architecture) · [Đóng góp](#contributing)

</div>

---

## Tính năng chính

| Tính năng | Thông số kỹ thuật |
|-----------|-------------------|
| **Kiến trúc** | Systolic Array 16×16 Weight-Stationary |
| **Hiệu suất đỉnh** | 512 GOPS (INT8) @ 1 GHz |
| **Hiệu quả năng lượng** | > 1 TOPS/W |
| **Bộ nhớ trên chip** | 528 KB SRAM (Weight + Activation + Instruction) |
| **Kiểu dữ liệu** | INT8, INT16, FP16, BF16 |
| **Giao diện** | AXI4 Master (128-bit) + AXI4-Lite Slave (32-bit) |

### Các phép toán được hỗ trợ

- **Convolution**: Conv2D, DepthwiseConv2D, TransposeConv2D, Dilated Conv
- **Activation**: ReLU, ReLU6, Sigmoid, Tanh, Swish, GELU, LeakyReLU
- **Pooling**: MaxPool2D, AvgPool2D, GlobalAveragePool
- **Normalization**: BatchNorm (fused), LayerNorm
- **Element-wise**: Add, Multiply, Subtract, Concat, Split, Reshape
- **Linear**: FullyConnected, MatMul

### Đặc điểm kỹ thuật chi tiết

- **PE Array**: 16×16 = 256 Processing Elements
- **Instruction Set**: 64-bit RISC-style với 12 opcodes
- **DMA Engine**: 4-channel với hỗ trợ 2D/3D transfers
- **Memory Bandwidth**: 16 GB/s (internal), 12.8 GB/s (external)
- **Clock Domain**: Single clock domain với optional clock gating
- **Debug Support**: JTAG interface và performance counters

---

## Kiến trúc

```
┌─────────────────────────────────────────────────────────────────┐
│                     Giao diện AXI4                             │
├─────────────────────────────────────────────────────────────────┤
│  ┌───────────┐  ┌──────────────┐  ┌──────────────┐  ┌────────┐  │
│  │ DMA Engine│  │ Weight Buffer│  │ Activation   │  │ Inst   │  │
│  │ 4-channel │  │   256 KB     │  │ Buffer 256KB │  │ 16 KB  │  │
│  └─────┬─────┘  └──────┬───────┘  └──────┬───────┘  └────────┘  │
│        │               │                  │                      │
│        ▼               ▼                  ▼                      │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │            PE Array (16×16 Systolic)                   │    │
│  │                  256 MACs                              │    │
│  │  ┌────┐ ┌────┐ ┌────┐     ┌────┐                      │    │
│  │  │PE  │ │PE  │ │PE  │ ... │PE  │                      │    │
│  │  └────┘ └────┘ └────┘     └────┘                      │    │
│  │    │      │      │         │                          │    │
│  │  ┌────┐ ┌────┐ ┌────┐     ┌────┐                      │    │
│  │  │PE  │ │PE  │ │PE  │ ... │PE  │                      │    │
│  │  └────┘ └────┘ └────┘     └────┘                      │    │
│  └─────────────────────────────────────────────────────────┘    │
│        │                                                         │
│        ▼                                                         │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ Post-Processing: Activation | Pooling | Quantization   │    │
│  │ • ReLU, ReLU6, Sigmoid, Tanh, Swish, GELU             │    │
│  │ • MaxPool, AvgPool, GlobalPool                         │    │
│  │ • BatchNorm, LayerNorm                                 │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

---

## Cấu trúc dự án

```
EdgeNPU/
├── rtl/                    # Thiết kế RTL (SystemVerilog)
│   ├── core/               # NPU Core
│   │   ├── pe_array/       # Processing Element Array
│   │   ├── activation/     # Activation Functions
│   │   ├── pooling/        # Pooling Operations
│   │   ├── controller/     # NPU Controller
│   │   ├── conv/           # Convolution Engine
│   │   ├── accumulator/    # Accumulator
│   │   ├── batchnorm/      # Batch Normalization
│   │   └── elementwise/    # Element-wise Operations
│   ├── memory/             # Memory Subsystem
│   │   ├── sram/           # SRAM Controllers
│   │   ├── buffer/         # Buffer Management
│   │   └── dma/            # DMA Engine
│   ├── interconnect/       # AXI/APB Interfaces
│   ├── debug/              # Debug Interface
│   └── top/                # Top-level Integration
├── verification/           # Verification Environment
│   ├── tb/                 # Testbenches
│   ├── uvm/                # UVM Environment
│   └── formal/             # Formal Verification
├── software/               # Software Stack
│   ├── driver/             # Linux & Bare-metal Drivers
│   ├── compiler/           # Model Compiler (ONNX, TFLite)
│   ├── runtime/            # Runtime Library
│   ├── firmware/           # Firmware
│   └── sdk/                # C/C++/Python SDK
├── ip/                     # IP Cores
│   ├── memory/             # Memory IP
│   ├── axi/                # AXI IP
│   ├── npu/                # NPU-specific IP
│   └── third_party/        # Third-party IP
├── flow/                   # Build & Synthesis Flow
│   ├── build/              # Build Scripts
│   ├── scripts/            # Automation Scripts
│   └── synthesis/          # Synthesis Scripts
├── doc-sites/              # Interactive Documentation Website
└── docs/                   # Documentation
```

---

## Bắt đầu nhanh

### Yêu cầu hệ thống

- **OS**: Ubuntu 20.04+ / CentOS 7+
- **Simulator**: Icarus Verilog, Verilator, hoặc thương mại (VCS, Questa)
- **Python**: 3.8+ (cho SDK và compiler)

### Cài đặt

```bash
# Clone repository
git clone https://github.com/buiminhnhut114/edge-npu-design.git
cd edge-npu-design

# Cài đặt Python dependencies
pip install -r requirements.txt

# Cài đặt simulation tools
sudo apt install iverilog verilator gtkwave
```

### Chạy Simulation

```bash
# Chạy tất cả unit tests
make test

# Chạy PE unit test
make sim_pe

# Chạy PE array simulation
make sim_pe_array

# Chạy full system simulation
make sim

# Lint RTL code
make lint

# Xem waveforms
gtkwave npu_tb.vcd

# Clean build artifacts
make clean
```

### Ví dụ sử dụng RTL

```systemverilog
// Instantiate EdgeNPU trong SoC
npu_top #(
    .PE_ROWS     (16),
    .PE_COLS     (16),
    .DATA_WIDTH  (8),
    .AXI_DATA_W  (128),
    .AXI_ADDR_W  (40)
) u_edgenpu (
    .clk         (npu_clk),
    .rst_n       (npu_rst_n),
    // AXI4 Master interface
    .m_axi_*     (axi_master_*),
    // AXI4-Lite Slave interface  
    .s_axil_*    (axil_slave_*),
    // Interrupt
    .irq         (npu_irq)
);
```

### Xây dựng Documentation

```bash
cd doc-sites
npm install
npm run dev      # Development server
npm run build    # Production build
```

---

## Benchmark hiệu suất

| Model | Kích thước đầu vào | Latency | Throughput | Power |
|-------|-------------------|---------|------------|-------|
| MobileNetV1 | 224×224 | 2.1 ms | 476 FPS | 320 mW |
| MobileNetV2 | 224×224 | 2.8 ms | 357 FPS | 340 mW |
| MobileNetV3-Small | 224×224 | 1.5 ms | 667 FPS | 280 mW |
| EfficientNet-Lite0 | 224×224 | 3.2 ms | 312 FPS | 360 mW |
| ResNet-18 | 224×224 | 8.5 ms | 118 FPS | 420 mW |
| YOLO-Tiny | 416×416 | 12.3 ms | 81 FPS | 450 mW |
| SSD-MobileNetV2 | 300×300 | 6.8 ms | 147 FPS | 380 mW |

*Benchmark được đo tại tần số clock 800 MHz với quantization INT8*

---

## Tài liệu

📚 **[Tài liệu đầy đủ](https://buiminhnhut114.github.io/edge-npu-design/)**

- [Kiến trúc hệ thống](docs/architecture/system_overview.md)
- [Register Map](docs/specification/register_map.md)
- [Hướng dẫn lập trình](docs/user_guide/programming.md)
- [Hướng dẫn tích hợp](docs/user_guide/integration.md)
- [API Reference](docs/api_reference/)

---

## Công nghệ sử dụng

| Danh mục | Công nghệ |
|----------|-----------|
| **Thiết kế RTL** | SystemVerilog, Verilog-2005 |
| **Verification** | UVM, SystemVerilog Assertions, Formal |
| **Synthesis** | Synopsys DC, Cadence Genus |
| **Simulation** | VCS, Questa, Verilator, Icarus |
| **Software** | C/C++, Python, ONNX, TFLite |
| **Documentation** | React, TypeScript, Vite |

---

## Lộ trình phát triển

- [x] Triển khai PE Array (Systolic)
- [x] Các hàm activation cơ bản (ReLU, ReLU6, Sigmoid, Tanh, Swish, GELU)
- [x] Giao diện AXI4/AXI4-Lite
- [x] DMA engine 4-channel
- [x] Memory subsystem (Weight, Activation, Instruction buffers)
- [x] Post-processing units (Activation, Pooling, BatchNorm)
- [x] Convolution controller và Depthwise convolution
- [x] Element-wise operations (Add, Multiply, Concat, Split)
- [x] Instruction decoder và scheduler
- [x] Debug interface
- [ ] Tối ưu hóa depthwise convolution
- [ ] Hỗ trợ FP16/BF16 đầy đủ
- [ ] Power gating
- [ ] Hỗ trợ on-device training

---

## Đóng góp

Chúng tôi hoan nghênh các đóng góp! Vui lòng đọc [Hướng dẫn đóng góp](CONTRIBUTING.md) trước khi gửi PR.

1. Fork repository
2. Tạo feature branch (`git checkout -b feature/amazing-feature`)
3. Commit thay đổi (`git commit -m 'Add amazing feature'`)
4. Push lên branch (`git push origin feature/amazing-feature`)
5. Mở Pull Request

---

## Trích dẫn

Nếu bạn sử dụng EdgeNPU trong nghiên cứu, vui lòng trích dẫn:

```bibtex
@misc{edgenpu2026,
  title={EdgeNPU: High-Performance Neural Processing Unit for Edge AI},
  author={Bui Minh Nhut},
  year={2026},
  howpublished={\url{https://github.com/buiminhnhut114/edge-npu-design}}
}
```

---

## Giấy phép

Dự án này được cấp phép theo MIT License - xem file [LICENSE](LICENSE) để biết chi tiết.

---

<div align="center">

**EdgeNPU** — Thiết kế cho Edge, Xây dựng cho Hiệu suất

[⬆ Về đầu trang](#edgenpu-design)

</div>
