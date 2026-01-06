# EdgeNPU Documentation Index

---

## Quick Links

| Document | Description |
|----------|-------------|
| [Datasheet](specification/datasheet.md) | Product overview and specifications |
| [Setup Guide](user_guide/setup.md) | Installation and getting started |
| [Programming Guide](user_guide/programming_guide.md) | How to program the NPU |

---

## Documentation Structure

```
docs/
├── README.md                        # This file
├── architecture/
│   └── npu_architecture.md          # Micro-architecture details
├── specification/
│   ├── datasheet.md                 # Product datasheet
│   ├── register_map.md              # Register reference
│   └── instruction_set.md           # ISA reference
├── user_guide/
│   ├── setup.md                     # Installation guide
│   ├── programming_guide.md         # Programming tutorial
│   └── integration_guide.md         # SoC integration
└── api_reference/
    ├── c_api.md                     # C API reference
    └── python_api.md                # Python API reference
```

---

## Document Categories

### Specifications

Technical specifications and reference documents:

- **[Datasheet](specification/datasheet.md)** - Product overview, block diagram, electrical specs
- **[Register Map](specification/register_map.md)** - Complete register reference with bit fields
- **[Instruction Set](specification/instruction_set.md)** - NPU instruction encoding and examples

### Architecture

Internal design documentation:

- **[NPU Architecture](architecture/npu_architecture.md)** - Micro-architecture, data flow, PE design

### User Guides

Step-by-step guides for users:

- **[Setup Guide](user_guide/setup.md)** - Prerequisites, installation, verification
- **[Programming Guide](user_guide/programming_guide.md)** - Programming model, examples, optimization
- **[Integration Guide](user_guide/integration_guide.md)** - SoC integration, interfaces, constraints

### API Reference

Software API documentation:

- **[C API](api_reference/c_api.md)** - C library functions and types
- **[Python API](api_reference/python_api.md)** - Python SDK classes and methods

---

## Version Information

| Component | Version |
|-----------|---------|
| Hardware | 1.0.0 |
| SDK | 1.0.0 |
| Documentation | 1.0.0 |

---

## Getting Help

1. Check the relevant documentation above
2. Search existing GitHub issues
3. Ask on the discussion forum
4. File a new issue with details

---

*© 2026 EdgeNPU Project. All rights reserved.*
