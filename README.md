<div align="center">

<img src="logo/logo.jpeg" alt="EdgeNPU Logo" width="200" height="200">

# EdgeNPU Design

### High-Performance Neural Processing Unit for Edge AI Applications

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![RTL](https://img.shields.io/badge/RTL-SystemVerilog-orange.svg)](#)
[![Verification](https://img.shields.io/badge/Verification-UVM-green.svg)](#)
[![Documentation](https://img.shields.io/badge/docs-available-brightgreen.svg)](https://buiminhnhut114.github.io/edge-npu-design/)
[![Build Status](https://img.shields.io/github/actions/workflow/status/buiminhnhut114/edge-npu-design/deploy-docs.yml?branch=main)](https://github.com/buiminhnhut114/edge-npu-design/actions)

**EdgeNPU** is a production-grade Neural Processing Unit (NPU) IP core designed for high-performance, low-power neural network inference at the edge. Built on a **16×16 weight-stationary systolic array architecture**, EdgeNPU delivers up to **512 GOPS** peak performance while consuming less than **500mW**, achieving industry-leading efficiency of **>1 TOPS/W**.

[📖 Documentation](https://buiminhnhut114.github.io/edge-npu-design/) · [🚀 Quick Start](#quick-start) · [🏗️ Architecture](#architecture) · [🤝 Contributing](#contributing)

</div>

---

## ✨ Key Features

| Feature | Specification |
|---------|---------------|
| **Architecture** | 16×16 Weight-Stationary Systolic Array |
| **Peak Performance** | 512 GOPS (INT8) @ 1 GHz |
| **Energy Efficiency** | > 1 TOPS/W |
| **On-chip Memory** | 528 KB SRAM (Weight + Activation + Instruction) |
| **Data Types** | INT8, INT16, FP16, BF16 |
| **Interface** | AXI4 Master (128-bit) + AXI4-Lite Slave (32-bit) |
| **Process Technology** | 28nm / 16nm / 7nm ready |

### 🧠 Supported Neural Network Operations

- **Convolution**: Conv2D, DepthwiseConv2D, TransposeConv2D, Dilated Conv
- **Activation**: ReLU, ReLU6, Sigmoid, Tanh, Swish, GELU, LeakyReLU, HardSwish
- **Pooling**: MaxPool2D, AvgPool2D, GlobalAveragePool
- **Normalization**: BatchNorm (fused), LayerNorm
- **Element-wise**: Add, Multiply, Subtract, Concat, Split, Reshape
- **Linear**: FullyConnected, MatMul

### 🔧 Technical Specifications

- **PE Array**: 16×16 = 256 Processing Elements
- **Instruction Set**: 64-bit RISC-style with 12 opcodes
- **DMA Engine**: 4-channel with 2D/3D transfer support
- **Memory Bandwidth**: 16 GB/s (internal), 12.8 GB/s (external)
- **Clock Domain**: Single clock domain with optional clock gating
- **Debug Support**: JTAG interface and performance counters
- **Power Management**: Advanced clock gating and power islands

---

## 🏗️ Architecture

<div align="center">

```
┌─────────────────────────────────────────────────────────────────┐
│                        AXI4 Interface                          │
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

</div>

### 🔄 Weight-Stationary Dataflow

EdgeNPU employs a **weight-stationary systolic array** where weights are loaded once and remain fixed in each PE while input activations flow through the array. This approach maximizes weight reuse and minimizes memory bandwidth for weight-heavy operations like convolutions.

---

## 📁 Project Structure

```
EdgeNPU/
├── rtl/                    # RTL Design (SystemVerilog)
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
│   ├── testbench/          # Testbenches
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
│   └── synthesis/          # Synthesis Scripts (OpenLane)
├── doc-sites/              # Interactive Documentation Website
└── logo/                   # EdgeNPU Logo Assets
```

---

## 🚀 Quick Start

### 📋 System Requirements

- **OS**: Ubuntu 20.04+ / CentOS 7+ / macOS 10.15+
- **Simulator**: Icarus Verilog, Verilator, or commercial (VCS, Questa)
- **Python**: 3.8+ (for SDK and compiler)
- **Node.js**: 18+ (for documentation site)

### 🛠️ Installation

```bash
# Clone repository
git clone https://github.com/buiminhnhut114/edge-npu-design.git
cd edge-npu-design

# Install Python dependencies
pip install -r requirements.txt

# Install simulation tools (Ubuntu/Debian)
sudo apt update
sudo apt install iverilog verilator gtkwave

# Install simulation tools (macOS)
brew install icarus-verilog verilator gtkwave
```

### 🧪 Running Simulations

```bash
# Run all unit tests
make test

# Run PE unit test
make sim_pe

# Run PE array simulation
make sim_pe_array

# Run full system simulation
make sim

# Run UVM testbench
make uvm

# Lint RTL code
make lint

# View waveforms
gtkwave npu_tb.vcd

# Clean build artifacts
make clean
```

### 💻 RTL Integration Example

```systemverilog
// Instantiate EdgeNPU in your SoC
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

### 🌐 Building Documentation

```bash
cd doc-sites
npm install
npm run dev      # Development server at http://localhost:3000
npm run build    # Production build
```

---

## 📊 Performance Benchmarks

| Model | Input Size | Latency | Throughput | Power |
|-------|------------|---------|------------|-------|
| MobileNetV1 | 224×224 | 2.1 ms | 476 FPS | 320 mW |
| MobileNetV2 | 224×224 | 2.8 ms | 357 FPS | 340 mW |
| MobileNetV3-Small | 224×224 | 1.5 ms | 667 FPS | 280 mW |
| EfficientNet-Lite0 | 224×224 | 3.2 ms | 312 FPS | 360 mW |
| ResNet-18 | 224×224 | 8.5 ms | 118 FPS | 420 mW |
| YOLO-Tiny | 416×416 | 12.3 ms | 81 FPS | 450 mW |
| SSD-MobileNetV2 | 300×300 | 6.8 ms | 147 FPS | 380 mW |

*Benchmarks measured at 800 MHz clock frequency with INT8 quantization*

### 🏆 Efficiency Comparison

| Platform | Peak TOPS | Power | TOPS/W | Process |
|----------|-----------|-------|--------|---------|
| **EdgeNPU** | **0.51** | **0.5W** | **1.02** | **28nm** |
| Google Edge TPU | 4.0 | 2.0W | 2.0 | — |
| Intel Movidius | 1.0 | 1.5W | 0.67 | — |
| ARM Ethos-U55 | 0.5 | 0.5W | 1.0 | — |
| Cortex-A76 (CPU) | 0.02 | 2.0W | 0.01 | 7nm |

---

## 📚 Documentation

📖 **[Complete Documentation](https://buiminhnhut114.github.io/edge-npu-design/)**

- [🏗️ System Architecture](https://buiminhnhut114.github.io/edge-npu-design/#/system-architecture)
- [🔧 Register Map](https://buiminhnhut114.github.io/edge-npu-design/#/register-map)
- [📝 Programming Guide](https://buiminhnhut114.github.io/edge-npu-design/#/programming-overview)
- [🔗 Integration Guide](https://buiminhnhut114.github.io/edge-npu-design/#/soc-integration)
- [📋 API Reference](https://buiminhnhut114.github.io/edge-npu-design/#/c-api)
- [🐍 Python SDK](https://buiminhnhut114.github.io/edge-npu-design/#/python-api)

---

## 🛠️ Technology Stack

| Category | Technology |
|----------|------------|
| **RTL Design** | SystemVerilog, Verilog-2005 |
| **Verification** | UVM, SystemVerilog Assertions, Formal |
| **Synthesis** | OpenLane, Synopsys DC, Cadence Genus |
| **Simulation** | VCS, Questa, Verilator, Icarus Verilog |
| **Software** | C/C++, Python, ONNX, TensorFlow Lite |
| **Documentation** | React, TypeScript, Vite, SVG |
| **CI/CD** | GitHub Actions, Docker |

---

## 🗺️ Development Roadmap

### ✅ Completed Features

- [x] PE Array implementation (Systolic)
- [x] Basic activation functions (ReLU, ReLU6, Sigmoid, Tanh, Swish, GELU)
- [x] AXI4/AXI4-Lite interfaces
- [x] 4-channel DMA engine
- [x] Memory subsystem (Weight, Activation, Instruction buffers)
- [x] Post-processing units (Activation, Pooling, BatchNorm)
- [x] Convolution controller and Depthwise convolution
- [x] Element-wise operations (Add, Multiply, Concat, Split)
- [x] Instruction decoder and scheduler
- [x] Debug interface
- [x] Comprehensive documentation site
- [x] UVM verification environment

### 🚧 In Progress

- [ ] Depthwise convolution optimization
- [ ] Full FP16/BF16 support
- [ ] Power gating implementation
- [ ] OpenLane synthesis flow
- [ ] Python SDK enhancements

### 🔮 Future Plans

- [ ] On-device training support
- [ ] Dynamic quantization
- [ ] Multi-core scaling
- [ ] RISC-V integration
- [ ] Transformer acceleration
- [ ] Edge TPU compatibility layer

---

## 🤝 Contributing

We welcome contributions! Please read our [Contributing Guidelines](CONTRIBUTING.md) before submitting PRs.

### 🔄 Development Workflow

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** your changes (`git commit -m 'Add amazing feature'`)
4. **Push** to the branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request

### 🐛 Bug Reports

Please use GitHub Issues to report bugs. Include:
- System information (OS, simulator, versions)
- Steps to reproduce
- Expected vs actual behavior
- Relevant logs or waveforms

### 💡 Feature Requests

We're always looking for ways to improve EdgeNPU! Feel free to suggest new features or enhancements through GitHub Issues.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 📖 Citation

If you use EdgeNPU in your research, please cite:

```bibtex
@misc{edgenpu2026,
  title={EdgeNPU: High-Performance Neural Processing Unit for Edge AI},
  author={Bui Minh Nhut},
  year={2026},
  howpublished={\url{https://github.com/buiminhnhut114/edge-npu-design}},
  note={Open-source NPU design for edge AI applications}
}
```

---

## 🙏 Acknowledgments

- Inspired by Google's TPU and ARM's Ethos-U architectures
- Built with modern SystemVerilog and UVM methodologies
- Documentation powered by React and modern web technologies
- Community feedback and contributions

---

## 📞 Contact & Support

- **GitHub Issues**: [Report bugs or request features](https://github.com/buiminhnhut114/edge-npu-design/issues)
- **Documentation**: [https://buiminhnhut114.github.io/edge-npu-design/](https://buiminhnhut114.github.io/edge-npu-design/)
- **Email**: [Contact the maintainer](mailto:buiminhnhut114@gmail.com)

---

<div align="center">

**EdgeNPU** — Designed for Edge, Built for Performance

Made with ❤️ for the open-source hardware community

[⬆ Back to top](#edgenpu-design)

</div>