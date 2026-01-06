# EdgeNPU Firmware

Firmware cho NPU, bao gồm boot code và runtime execution engine.

## Cấu trúc thư mục

```
firmware/
├── include/           # Header files
│   ├── npu_fw_regs.h  # Register definitions
│   ├── npu_fw_inst.h  # Instruction set definitions
│   └── npu_fw_types.h # Common types
├── boot/              # Boot code
│   ├── startup.S      # RISC-V startup assembly
│   ├── npu_boot.h     # Boot API
│   └── npu_boot.c     # Boot implementation
├── runtime/           # Runtime engine
│   ├── npu_runtime_fw.h   # Runtime API
│   ├── npu_runtime_fw.c   # Runtime implementation
│   └── npu_layer_exec.c   # Layer execution
├── Makefile           # Build system
└── linker.ld          # Linker script
```

## Build

### Yêu cầu
- RISC-V toolchain (riscv32-unknown-elf-gcc)

### Compile
```bash
make                    # Build firmware
make clean              # Clean build
make disasm             # Generate disassembly
make size               # Print size info
```

### Output
- `build/npu_firmware.elf` - ELF executable
- `build/npu_firmware.bin` - Binary image
- `build/npu_firmware.hex` - Intel HEX format

## Memory Map

| Region | Address | Size | Description |
|--------|---------|------|-------------|
| ROM | 0x00000000 | 64KB | Firmware code |
| RAM | 0x00010000 | 32KB | Firmware data |
| NPU Regs | 0x40000000 | 4KB | Control registers |
| Inst Buffer | 0x40100000 | 64KB | Instructions |
| Weight Buffer | 0x40200000 | 256KB | Weights |
| Act Buffer | 0x40300000 | 256KB | Activations |

## API

### Boot API
```c
fw_status_t npu_boot_init(void);      // Initialize hardware
fw_status_t npu_boot_selftest(void);  // Run self-test
fw_status_t npu_boot_sleep(void);     // Enter low power
fw_status_t npu_boot_wake(void);      // Wake from sleep
```

### Runtime API
```c
fw_status_t npu_rt_init(const runtime_config_t *config);
fw_status_t npu_rt_load_model(const void *model, uint32_t size);
fw_status_t npu_rt_load_input(const void *input, uint32_t size);
fw_status_t npu_rt_start(void);
fw_status_t npu_rt_wait(uint32_t timeout_us);
fw_status_t npu_rt_read_output(void *output, uint32_t size);
```

## Instruction Set

### Control
- `NOP`, `HALT`, `SYNC`, `WAIT_DMA`, `WAIT_PE`
- `LOOP_START`, `LOOP_END`, `BRANCH`, `JUMP`

### DMA
- `DMA_LOAD_W`, `DMA_LOAD_A`, `DMA_STORE`
- `DMA_2D_LOAD`, `DMA_2D_STORE`

### Compute
- `CONV`, `DWCONV`, `GEMM`, `FC`, `MATMUL`
- `CLEAR_ACC`, `LOAD_WEIGHT`, `COMPUTE`, `DRAIN`

### Activation
- `RELU`, `RELU6`, `SIGMOID`, `TANH`, `LEAKY_RELU`

### Pooling
- `MAXPOOL`, `AVGPOOL`, `GLOBAL_AVGPOOL`

### Element-wise
- `ADD`, `SUB`, `MUL`, `DIV`, `MAX`, `MIN`

## License

Copyright (c) 2024 EdgeNPU Project
