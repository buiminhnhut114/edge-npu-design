# EdgeNPU UVM Testbench

UVM-based verification environment for EdgeNPU.

## Cấu trúc

```
uvm/
├── npu_pkg.sv              # UVM package với tất cả includes
├── tb/
│   └── npu_uvm_tb.sv       # Top-level testbench
├── agents/
│   └── axil_agent/         # AXI-Lite agent
│       ├── axil_if.sv      # Interface
│       ├── axil_seq_item.sv
│       ├── axil_driver.sv
│       ├── axil_monitor.sv
│       └── axil_agent.sv
├── sequences/
│   ├── npu_seq_item.sv     # NPU transaction
│   ├── npu_base_seq.sv     # Base sequence
│   ├── npu_reg_seq.sv      # Register test sequence
│   └── npu_conv_seq.sv     # Convolution sequence
├── env/
│   ├── npu_env.sv          # Environment
│   ├── npu_scoreboard.sv   # Checker
│   └── npu_coverage.sv     # Coverage
└── tests/
    ├── npu_base_test.sv    # Base test
    ├── npu_reg_test.sv     # Register test
    ├── npu_sanity_test.sv  # Sanity test
    └── npu_conv_test.sv    # Convolution test
```

## Chạy UVM Tests

### Với VCS
```bash
vcs -full64 -sverilog -ntb_opts uvm-1.2 \
    +incdir+verification/uvm \
    verification/uvm/npu_pkg.sv \
    verification/uvm/tb/npu_uvm_tb.sv \
    rtl/top/npu_pkg.sv \
    rtl/top/npu_top.sv \
    -o simv

./simv +UVM_TESTNAME=npu_reg_test
./simv +UVM_TESTNAME=npu_sanity_test
./simv +UVM_TESTNAME=npu_conv_test
```

### Với Questa/ModelSim
```bash
vlog -sv +incdir+verification/uvm \
    verification/uvm/npu_pkg.sv \
    verification/uvm/tb/npu_uvm_tb.sv

vsim -c npu_uvm_tb +UVM_TESTNAME=npu_reg_test -do "run -all"
```

### Với Xcelium
```bash
xrun -uvm -uvmhome CDNS-1.2 \
    +incdir+verification/uvm \
    verification/uvm/npu_pkg.sv \
    verification/uvm/tb/npu_uvm_tb.sv \
    +UVM_TESTNAME=npu_reg_test
```

## Tests có sẵn

| Test | Mô tả |
|------|-------|
| `npu_reg_test` | Test đọc/ghi registers |
| `npu_sanity_test` | Sanity check cơ bản |
| `npu_conv_test` | Test convolution operations |

## Coverage

Coverage được thu thập tự động:
- Register access coverage
- Control register coverage
- Cross coverage

Xem report trong `report_phase`.

## Thêm Test Mới

1. Tạo sequence mới trong `sequences/`
2. Tạo test mới kế thừa `npu_base_test`
3. Override `run_test_sequence()`
4. Include trong `npu_pkg.sv`

## Debug

```bash
# Verbose output
./simv +UVM_TESTNAME=npu_reg_test +UVM_VERBOSITY=UVM_HIGH

# Dump waveform
./simv +UVM_TESTNAME=npu_reg_test +dump_vcd
```
