# EdgeNPU Setup Guide

**Version 1.0.0**

---

## Prerequisites

### System Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| OS | Ubuntu 20.04 LTS | Ubuntu 22.04 LTS |
| RAM | 8 GB | 16 GB |
| Disk | 10 GB | 50 GB |
| CPU | x86_64 / ARM64 | - |

### Required Tools

```bash
# Essential packages
sudo apt update
sudo apt install -y \
    build-essential \
    git \
    python3 \
    python3-pip \
    python3-venv

# HDL simulation tools
sudo apt install -y iverilog gtkwave

# Optional: Verilator for linting
sudo apt install -y verilator
```

---

## Quick Setup

### 1. Clone Repository

```bash
git clone https://github.com/your-org/EdgeNPU.git
cd EdgeNPU
```

### 2. Install Python Dependencies

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### 3. Verify Installation

```bash
make help
```

Expected output:
```
EdgeNPU Build System
====================

Simulation:
  make sim          - Run RTL simulation
  make sim_pe       - Run PE array unit test
  make sim_unit     - Run unit tests

Synthesis:
  make synth        - Run synthesis

Verification:
  make lint         - Run linting
  make formal       - Run formal verification

Clean:
  make clean        - Clean build artifacts
```

---

## Project Structure

```
EdgeNPU/
├── rtl/                    # RTL Design
│   ├── core/               # NPU Core
│   ├── memory/             # Memory Subsystem
│   ├── interconnect/       # Bus Interfaces
│   └── top/                # Top-level
├── ip/                     # IP Cores Library
├── verification/           # Verification
├── software/               # Software Stack
├── docs/                   # Documentation
├── scripts/                # Build Scripts
├── constraints/            # Design Constraints
└── models/                 # Reference Models
```

---

## Running Simulations

### PE Array Test

```bash
make sim_pe
```

### Full NPU Simulation

```bash
make sim
```

### View Waveforms

```bash
gtkwave build/*.vcd
```

---

## Synthesis

### FPGA Synthesis (Vivado)

1. Create project:
   ```bash
   cd scripts/synthesis
   vivado -mode batch -source create_project.tcl
   ```

2. Run synthesis:
   ```bash
   vivado -mode batch -source run_synth.tcl
   ```

### ASIC Synthesis (Design Compiler)

```bash
cd scripts/synthesis/asic
dc_shell -f synth.tcl
```

---

## SDK Installation

### Install EdgeNPU SDK

```bash
cd software/sdk
pip install -e .
```

### Verify SDK

```python
import edge_npu

# Print version
print(edge_npu.__version__)

# Load example model
model = edge_npu.load_model("examples/mobilenet.onnx")
print(model.summary())
```

---

## Model Compilation

### From ONNX

```bash
edge_npu_compile \
    --input model.onnx \
    --output model.bin \
    --target int8 \
    --calibration calibration_data.npy
```

### From TFLite

```bash
edge_npu_compile \
    --input model.tflite \
    --output model.bin \
    --target int8
```

---

## Hardware Integration

### Vivado Block Design

1. Add EdgeNPU IP to project:
   ```tcl
   add_files -norecurse rtl/filelist.f
   ```

2. Create AXI connections:
   ```tcl
   connect_bd_intf_net [get_bd_intf_pins npu/M_AXI] \
                       [get_bd_intf_pins axi_smc/S00_AXI]
   ```

### Linux Device Tree

```dts
npu@40000000 {
    compatible = "edge,npu-1.0";
    reg = <0x40000000 0x10000>;
    interrupts = <0 32 4>;
    clocks = <&clk 100>;
    clock-names = "axi_clk";
};
```

---

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| `iverilog not found` | `sudo apt install iverilog` |
| Simulation hangs | Check reset signal polarity |
| DMA timeout | Verify AXI connections |
| Incorrect results | Check quantization parameters |

### Debug Commands

```bash
# Run with verbose output
make sim VERBOSE=1

# Generate VCD waveforms
make sim VCD=1

# Run specific test
make sim_unit TEST=pe_test
```

---

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `NPU_HOME` | Project root | `$PWD` |
| `NPU_SIM` | Simulator | `iverilog` |
| `NPU_TARGET` | Synth target | `fpga` |

```bash
# Add to ~/.bashrc
export NPU_HOME=/path/to/EdgeNPU
export PATH=$NPU_HOME/scripts:$PATH
```

---

## Next Steps

1. Read [Programming Guide](programming_guide.md)
2. Review [Architecture Document](../architecture/npu_architecture.md)
3. Run example: `make run_example EXAMPLE=mobilenet`

---

## Support

For issues and questions:
- GitHub Issues: `https://github.com/your-org/EdgeNPU/issues`
- Documentation: `https://edge-npu.readthedocs.io`

---

*© 2026 EdgeNPU Project. All rights reserved.*
