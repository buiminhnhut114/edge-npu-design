# On-chip SRAM

SRAM modules for weight and activation storage.

## Modules

- `sram_sp.sv` - Single-port SRAM
- `sram_dp.sv` - Dual-port SRAM
- `sram_wrapper.sv` - SRAM Wrapper with ECC
- `memory_bank.sv` - Memory Bank Controller

## Configurations

- Weight Buffer: 256KB
- Activation Buffer: 256KB
- Unified Buffer: 512KB (optional)

## Features

- Single-cycle access
- Optional ECC protection
- Power gating support
