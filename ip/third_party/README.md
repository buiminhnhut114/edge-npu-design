# Third-Party IP Cores for EdgeNPU

IP cores tích hợp từ opensource để hỗ trợ EdgeNPU.

## 1. PE Array (`pe_array/`)

**Source:** GitHub pe_array-master

**Mục đích:** Cung cấp PE Array với Complex ALU sử dụng DSP48E2

### Components chính:
| File | Chức năng |
|------|-----------|
| `pe.v` | Single Processing Element với FSM |
| `pe_array.v` | Linear array of PEs |
| `complex_alu.v` | Complex number ALU (4x DSP48E2) |
| `alu.v` | Basic ALU wrapper cho DSP48E2 |
| `control.v` | Instruction decoder |
| `data_mem.v` | Data memory (BRAM) |
| `sdp_bram.v` | Simple Dual Port BRAM |
| `SIPO.v`, `PISO.v` | Serial/Parallel converters |

### Wrappers cho EdgeNPU:
- `pe_array_wrapper.sv` - Adapt PE array interface
- `complex_alu_wrapper.sv` - Standalone complex ALU

### Specs:
- 8-PE: 5,278 LUTs, 4,844 FFs, 16 BRAMs, 32 DSPs @ 600MHz
- 32-PE: 21,584 LUTs, 18,775 FFs, 64 BRAMs, 128 DSPs @ 600MHz

---

## 2. Debug Interface (`adbg_*.sv/v`)

**Source:** OpenCores adv_dbg_if

**Mục đích:** JTAG debug interface cho NPU

### Files:
- `adbg_bus_module_core.sv` - Bus debug module
- `adbg_crc32.v` - CRC32 for JTAG
- `adbg_pkg.sv` - Package definitions
- `syncflop.v`, `syncreg.v` - CDC synchronizers

---

## 3. Memory Models (`memory_models/`)

**Mục đích:** SRAM models cho simulation và FPGA

| File | Chức năng |
|------|-----------|
| `npu_fpga_sram.v` | FPGA SRAM inference |
| `npu_ahb_ram_beh.v` | Behavioral AHB RAM |

---

## 4. Bus Components (`bus_components/`)

**Mục đích:** Kết nối NPU với memory

| File | Chức năng |
|------|-----------|
| `npu_ahb_to_sram.v` | AHB to SRAM interface |

---

## Lưu ý

- `alu.v` và `complex_alu.v` sử dụng Xilinx DSP48E2. Cần modify cho FPGA khác.
- BRAM modules được thiết kế cho Xilinx inference.
