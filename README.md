# EdgeNPU - Neural Processing Unit

A high-performance, low-power Neural Processing Unit designed for edge AI applications.

## Project Structure

```
EdgeNPU/
├── rtl/                    # RTL Design (Verilog/SystemVerilog)
│   ├── core/               # NPU Core Components
│   │   ├── pe_array/       # Processing Element Array (Systolic Array)
│   │   ├── activation/     # Activation Functions (ReLU, Sigmoid, etc.)
│   │   ├── pooling/        # Pooling Units (Max, Average)
│   │   ├── accumulator/    # Accumulator and MAC Units
│   │   └── controller/     # Main Controller & Scheduler
│   ├── memory/             # Memory Subsystem
│   │   ├── sram/           # On-chip SRAM
│   │   ├── dma/            # DMA Controller
│   │   └── buffer/         # Weight/Activation Buffers
│   ├── interconnect/       # Interconnect
│   │   ├── noc/            # Network-on-Chip
│   │   ├── axi/            # AXI Interface
│   │   └── apb/            # APB Interface
│   └── top/                # Top-level Modules
│
├── verification/           # Verification Environment
│   ├── tb/                 # Testbenches
│   │   ├── unit/           # Unit Tests
│   │   ├── integration/    # Integration Tests
│   │   └── system/         # System-level Tests
│   ├── uvm/                # UVM Environment
│   │   ├── env/            # UVM Environment
│   │   ├── agents/         # UVM Agents
│   │   ├── sequences/      # UVM Sequences
│   │   └── tests/          # UVM Tests
│   ├── formal/             # Formal Verification
│   └── coverage/           # Coverage Collection
│
├── software/               # Software Stack
│   ├── driver/             # Device Drivers
│   │   ├── linux/          # Linux Driver
│   │   └── baremetal/      # Bare-metal Driver
│   ├── firmware/           # Firmware
│   │   ├── boot/           # Bootloader
│   │   └── runtime/        # Runtime Library
│   ├── compiler/           # NPU Compiler
│   │   ├── frontend/       # Model Parser (ONNX, TFLite)
│   │   ├── backend/        # Code Generator
│   │   └── optimizer/      # Graph Optimizer
│   └── sdk/                # Software Development Kit
│       ├── api/            # C/C++/Python API
│       └── examples/       # Example Applications
│
├── docs/                   # Documentation
│   ├── architecture/       # Architecture Documents
│   ├── specification/      # Hardware Specifications
│   ├── user_guide/         # User Guides
│   └── api_reference/      # API Reference
│
├── scripts/                # Automation Scripts
│   ├── synthesis/          # Synthesis Scripts
│   ├── simulation/         # Simulation Scripts
│   ├── verification/       # Verification Scripts
│   └── build/              # Build Scripts
│
├── tools/                  # Development Tools
│   ├── profiler/           # Performance Profiler
│   ├── debugger/           # Hardware Debugger
│   └── visualizer/         # Visualization Tools
│
├── ip/                     # IP Cores
│   ├── third_party/        # Third-party IPs
│   └── generated/          # Generated IPs
│
├── constraints/            # Design Constraints
│   ├── timing/             # Timing Constraints
│   ├── power/              # Power Constraints
│   └── floorplan/          # Floorplan Constraints
│
├── models/                 # Models
│   ├── behavioral/         # Behavioral Models
│   ├── tlm/                # Transaction-Level Models
│   └── python/             # Python Reference Models
│
└── tests/                  # Test Suite
    ├── unit/               # Unit Tests
    ├── regression/         # Regression Tests
    └── benchmark/          # Benchmark Tests
```

## Key Features

- **Systolic Array Architecture**: Efficient matrix multiplication
- **Flexible Data Path**: Support for INT8/INT16/FP16/BF16
- **On-chip Memory**: Weight and activation buffers
- **DMA Engine**: Efficient data movement
- **Compiler Support**: ONNX and TFLite model support

## Getting Started

1. Clone the repository
2. Install dependencies (see docs/user_guide/setup.md)
3. Run simulation: `make sim`
4. Synthesize: `make synth`

## License

MIT License
