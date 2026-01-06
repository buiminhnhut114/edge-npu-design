<div align="center">

# EdgeNPU

### High-Performance Neural Processing Unit for Edge AI

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![RTL](https://img.shields.io/badge/RTL-SystemVerilog-orange.svg)](#)
[![Verification](https://img.shields.io/badge/Verification-UVM-green.svg)](#)
[![Documentation](https://img.shields.io/badge/docs-available-brightgreen.svg)](https://buiminhnhut114.github.io/edge-npu-design/)

**EdgeNPU** is a production-grade Neural Processing Unit IP core designed for high-performance, low-power neural network inference at the edge. Built on a **16×16 systolic array architecture**, EdgeNPU delivers up to **512 GOPS** peak performance while consuming less than **500mW**.

[Documentation](https://buiminhnhut114.github.io/edge-npu-design/) · [Getting Started](#quick-start) · [Architecture](#architecture) · [Contributing](#contributing)

</div>

---

## Key Features

| Feature | Specification |
|---------|--------------|
| **Architecture** | 16×16 Weight-Stationary Systolic Array |
| **Peak Performance** | 512 GOPS (INT8) @ 1 GHz |
| **Power Efficiency** | > 1 TOPS/W |
| **On-Chip Memory** | 528 KB SRAM (Weight + Activation + Instruction) |
| **Data Types** | INT8, INT16, FP16, BF16 |
| **Interface** | AXI4 Master (128-bit) + AXI4-Lite Slave (32-bit) |

### Supported Operations

- **Convolution**: Conv2D, DepthwiseConv2D, TransposeConv2D
- **Activation**: ReLU, ReLU6, Sigmoid, Tanh, Swish, GELU
- **Pooling**: MaxPool2D, AvgPool2D, GlobalAveragePool
- **Other**: FullyConnected, Add, Multiply, Concat, BatchNorm (fused)

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        AXI4 Interface                           │
├─────────────────────────────────────────────────────────────────┤
│  ┌───────────┐  ┌──────────────┐  ┌──────────────┐  ┌────────┐  │
│  │    DMA    │  │ Weight Buf   │  │ Activation   │  │  Inst  │  │
│  │  Engine   │  │   256 KB     │  │  Buf 256 KB  │  │ 16 KB  │  │
│  └─────┬─────┘  └──────┬───────┘  └──────┬───────┘  └────────┘  │
│        │               │                  │                      │
│        ▼               ▼                  ▼                      │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │               PE Array (16×16 Systolic)                 │    │
│  │                    256 MACs                             │    │
│  └─────────────────────────────────────────────────────────┘    │
│        │                                                         │
│        ▼                                                         │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  Post-Processing: Activation | Pooling | Quantization   │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

---

## Project Structure

```
EdgeNPU/
├── rtl/                    # RTL Design (SystemVerilog)
│   ├── core/               # NPU Core (PE Array, Activation, Pooling)
│   ├── memory/             # Memory Subsystem (SRAM, DMA, Buffers)
│   ├── interconnect/       # AXI/APB Interfaces
│   └── top/                # Top-level Integration
├── verification/           # Verification Environment
│   ├── tb/                 # Testbenches (Unit, Integration, System)
│   ├── uvm/                # UVM Environment
│   └── formal/             # Formal Verification
├── software/               # Software Stack
│   ├── driver/             # Linux & Bare-metal Drivers
│   ├── compiler/           # Model Compiler (ONNX, TFLite)
│   └── sdk/                # C/C++/Python SDK
├── docs/                   # Documentation
├── doc-site/               # Interactive Documentation Website
└── scripts/                # Build & Automation Scripts
```

---

## Quick Start

### Prerequisites

- **OS**: Ubuntu 20.04+ / CentOS 7+
- **Simulator**: Icarus Verilog, Verilator, or commercial (VCS, Questa)
- **Python**: 3.8+ (for SDK and compiler)

### Installation

```bash
# Clone repository
git clone https://github.com/buiminhnhut114/edge-npu-design.git
cd edge-npu-design

# Install Python dependencies
pip install -r requirements.txt

# Install simulation tools
sudo apt install iverilog verilator gtkwave
```

### Running Simulation

```bash
# Run all unit tests
make test

# Run PE array simulation
make sim_pe

# Run full system simulation
make sim_system

# View waveforms
make wave
```

### Building Documentation

```bash
cd doc-site
npm install
npm run dev      # Development server
npm run build    # Production build
```

---

## Performance Benchmarks

| Model | Input Size | Latency | Throughput | Power |
|-------|-----------|---------|------------|-------|
| MobileNetV2 | 224×224 | 2.8 ms | 357 FPS | 340 mW |
| MobileNetV3-Small | 224×224 | 1.5 ms | 667 FPS | 280 mW |
| EfficientNet-Lite0 | 224×224 | 3.2 ms | 312 FPS | 360 mW |
| YOLO-Tiny | 416×416 | 12.3 ms | 81 FPS | 450 mW |
| ResNet-18 | 224×224 | 8.5 ms | 118 FPS | 420 mW |

*Benchmarks measured at 800 MHz clock frequency with INT8 quantization*

---

## Documentation

📚 **[Full Documentation](https://buiminhnhut114.github.io/edge-npu-design/)**

- [System Architecture](docs/architecture/system_overview.md)
- [Register Map](docs/specification/register_map.md)
- [Programming Guide](docs/user_guide/programming.md)
- [Integration Guide](docs/user_guide/integration.md)
- [API Reference](docs/api_reference/)

---

## Technology Stack

| Category | Technologies |
|----------|-------------|
| **RTL Design** | SystemVerilog, Verilog-2005 |
| **Verification** | UVM, SystemVerilog Assertions, Formal |
| **Synthesis** | Synopsys DC, Cadence Genus |
| **Simulation** | VCS, Questa, Verilator, Icarus |
| **Software** | C/C++, Python, ONNX, TFLite |
| **Documentation** | React, TypeScript, Vite |

---

## Roadmap

- [x] PE Array (Systolic) implementation
- [x] Basic activation functions (ReLU, ReLU6)
- [x] AXI4/AXI4-Lite interface
- [x] DMA engine
- [x] Python SDK
- [ ] Depthwise convolution optimization
- [ ] FP16/BF16 support
- [ ] Power gating
- [ ] On-device training support

---

## Contributing

Contributions are welcome! Please read our [Contributing Guidelines](CONTRIBUTING.md) before submitting PRs.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## Citation

If you use EdgeNPU in your research, please cite:

```bibtex
@misc{edgenpu2026,
  title={EdgeNPU: High-Performance Neural Processing Unit for Edge AI},
  author={Bui Minh Nhut},
  year={2026},
  howpublished={\url{https://github.com/buiminhnhut114/edge-npu-design}}
}
```

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

<div align="center">

**EdgeNPU** — Designed for the Edge, Built for Performance

[⬆ Back to Top](#edgenpu)

</div>
