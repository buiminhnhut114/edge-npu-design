# Activation Functions

Hardware implementations of neural network activation functions.

## Modules

- `relu.sv` - ReLU activation
- `leaky_relu.sv` - Leaky ReLU
- `sigmoid.sv` - Sigmoid (LUT-based)
- `tanh.sv` - Tanh (LUT-based)
- `swish.sv` - Swish activation
- `gelu.sv` - GELU activation
- `activation_unit.sv` - Top-level activation module

## Implementation Notes

- ReLU: Combinational logic (comparison)
- Sigmoid/Tanh: Look-up table with interpolation
- Configurable precision (8/16-bit)
