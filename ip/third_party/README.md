# Third-Party IP Cores

This directory contains open-source IP cores integrated into EdgeNPU.

## 1. Advanced Debug Interface (`adv_dbg_if`)

**Source:** [OpenCores / ETH-Zurich](https://github.com/RoaLogic/adv_dbg_if)

**License:** LGPL

**Description:** Universal Advanced JTAG Debug Interface for SoC debugging.

### Files:
- `adbg_bus_module_core.sv` - Bus interface debug module
- `adbg_crc32.v` - CRC32 calculation for JTAG
- `adbg_jsp_module_core.sv` - JTAG Serial Port module
- `adbg_pkg.sv` - Package definitions
- `syncflop.v`, `syncreg.v` - CDC synchronizers
- `bytefifo.v` - Byte FIFO for JSP

### Integration:
Used in `rtl/debug/npu_debug_if.sv` as reference for JTAG TAP controller.

---

## 2. PE Array (`pe_array`)

**Source:** [GitHub pe_array-master](https://github.com/...)

**License:** MIT

**Description:** Linear array of RISC-V style Processing Elements with:
- Complex number ALU (4x DSP48E2)
- Instruction ROM
- Data memory (BRAM)
- SIPO/PISO for streaming I/O

### Files:
- `pe.v` - Single Processing Element
- `pe_array.v` - Array of PEs
- `complex_alu.v` - Complex number ALU
- `alu.v` - Basic ALU using DSP48E2
- `control.v` - Instruction decoder
- `data_mem.v` - Data memory
- `inst_rom.v` - Instruction ROM
- `sdp_bram.v` - Simple Dual Port BRAM
- `SIPO.v`, `PISO.v` - Serial/Parallel converters
- `parameters.vh` - Configuration parameters

### Wrappers:
- `pe_array_wrapper.sv` - Adapts to EdgeNPU interface
- `complex_alu_wrapper.sv` - Standalone complex ALU

### Specifications:
| Config | LUTs | FFs | BRAMs | DSPs | Fmax |
|--------|------|-----|-------|------|------|
| 8-PE   | 5,278 | 4,844 | 16 | 32 | 600MHz |
| 32-PE  | 21,584 | 18,775 | 64 | 128 | 600MHz |
| 128-PE | 80,725 | 71,898 | 256 | 512 | 500MHz |

### Operations Supported:
| Opcode | Operation | Description |
|--------|-----------|-------------|
| 001 | ADD | Complex addition |
| 010 | SUB | Complex subtraction |
| 100 | MUL | Complex multiplication |
| 101 | MULADD | Multiply-accumulate |
| 110 | MULSUB | Multiply-subtract |
| 111 | MAX | Maximum (magnitude) |

---

## Usage in EdgeNPU

### PE Array Integration

```systemverilog
// Use wrapper for NPU integration
pe_array_wrapper #(
    .PE_NUM     (8),
    .DATA_WIDTH (16)
) u_pe_array_ext (
    .clk            (clk),
    .rst_n          (rst_n),
    .enable         (pe_ext_enable),
    .start          (pe_ext_start),
    .done           (pe_ext_done),
    .busy           (pe_ext_busy),
    .data_valid     (data_valid),
    .data_in        (data_in),
    .data_out_valid (data_out_valid),
    .data_out       (data_out),
    .num_iterations (8'd16)
);
```

### Complex ALU for FP16/Complex Operations

```systemverilog
// Standalone complex ALU
complex_alu_wrapper #(
    .DATA_WIDTH (16)
) u_complex_alu (
    .clk       (clk),
    .rst_n     (rst_n),
    .opcode    (3'b100),  // MUL
    .valid_in  (valid_in),
    .operand_a ({real_a, imag_a}),
    .operand_b ({real_b, imag_b}),
    .operand_c (32'b0),
    .result    (result),
    .valid_out (valid_out)
);
```

---

## Notes

1. **DSP48E2 Dependency**: The `alu.v` and `complex_alu.v` use Xilinx DSP48E2 primitives. For other FPGAs, these need to be replaced with equivalent DSP blocks.

2. **BRAM Inference**: `sdp_bram.v` and `data_mem.v` are designed for Xilinx BRAM inference. May need adjustment for other vendors.

3. **Clock Domain**: All modules assume single clock domain. CDC handled separately.
