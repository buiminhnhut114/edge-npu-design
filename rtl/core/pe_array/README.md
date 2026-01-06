# Processing Element Array

This directory contains the RTL for the systolic array - the core compute engine of the NPU.

## Modules

- `pe.sv` - Single Processing Element (MAC unit)
- `pe_array.sv` - 2D Systolic Array (NxN PEs)
- `pe_controller.sv` - PE Array Controller
- `weight_loader.sv` - Weight Loading Logic

## Architecture

```
┌─────┬─────┬─────┬─────┐
│ PE  │ PE  │ PE  │ PE  │ ← Weights
├─────┼─────┼─────┼─────┤
│ PE  │ PE  │ PE  │ PE  │
├─────┼─────┼─────┼─────┤
│ PE  │ PE  │ PE  │ PE  │
├─────┼─────┼─────┼─────┤
│ PE  │ PE  │ PE  │ PE  │
└─────┴─────┴─────┴─────┘
  ↑
Activations
```

## Data Types Supported

- INT8 (default)
- INT16
- FP16
- BF16
