# EdgeNPU Makefile
# Build and simulation targets for EdgeNPU

#==============================================================================
# Configuration
#==============================================================================

IVERILOG = iverilog
VVP = vvp
VERILATOR = verilator

RTL_DIR = rtl
TB_DIR = verification/tb
BUILD_DIR = build

# File lists
RTL_FILES = -f rtl/filelist.f

#==============================================================================
# Targets
#==============================================================================

.PHONY: all clean sim sim_pe lint help

all: sim

# Create build directory
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

#------------------------------------------------------------------------------
# Simulation
#------------------------------------------------------------------------------

# Full NPU simulation
sim: $(BUILD_DIR)
	$(IVERILOG) -g2012 -Wall $(RTL_FILES) $(TB_DIR)/npu_tb.sv -o $(BUILD_DIR)/npu_sim
	$(VVP) $(BUILD_DIR)/npu_sim

# PE Array unit test
sim_pe: $(BUILD_DIR)
	$(IVERILOG) -g2012 -Wall +incdir+$(RTL_DIR)/top \
		$(RTL_DIR)/top/npu_pkg.sv \
		$(RTL_DIR)/core/pe_array/pe.sv \
		$(RTL_DIR)/core/pe_array/pe_array.sv \
		$(TB_DIR)/pe_array_tb.sv \
		-o $(BUILD_DIR)/pe_array_sim
	$(VVP) $(BUILD_DIR)/pe_array_sim

#------------------------------------------------------------------------------
# Linting
#------------------------------------------------------------------------------

lint:
	$(VERILATOR) --lint-only -Wall $(RTL_FILES)

#------------------------------------------------------------------------------
# Clean
#------------------------------------------------------------------------------

clean:
	rm -rf $(BUILD_DIR)
	rm -f *.vcd

#------------------------------------------------------------------------------
# Help
#------------------------------------------------------------------------------

help:
	@echo "EdgeNPU Build System"
	@echo "===================="
	@echo ""
	@echo "Targets:"
	@echo "  sim      - Run full NPU simulation"
	@echo "  sim_pe   - Run PE array unit test"
	@echo "  lint     - Run Verilator lint check"
	@echo "  clean    - Remove build artifacts"
	@echo "  help     - Show this help"
# Main build system for NPU development

# Directories
RTL_DIR     := rtl
TB_DIR      := verification/tb
UVM_DIR     := verification/uvm
SIM_DIR     := sim
BUILD_DIR   := build
SYN_DIR     := synthesis

# Simulator (iverilog, vcs, xsim, verilator)
SIMULATOR   ?= iverilog

# Default target
.PHONY: all
all: help

# Help
.PHONY: help
help:
	@echo "EdgeNPU Build System"
	@echo "===================="
	@echo ""
	@echo "Simulation:"
	@echo "  make sim          - Run RTL simulation"
	@echo "  make sim_unit     - Run unit tests"
	@echo "  make sim_integ    - Run integration tests"
	@echo "  make sim_uvm      - Run UVM tests"
	@echo ""
	@echo "Synthesis:"
	@echo "  make synth        - Run synthesis"
	@echo "  make synth_fpga   - FPGA synthesis"
	@echo "  make synth_asic   - ASIC synthesis"
	@echo ""
	@echo "Verification:"
	@echo "  make lint         - Run linting"
	@echo "  make formal       - Run formal verification"
	@echo "  make coverage     - Generate coverage report"
	@echo ""
	@echo "Clean:"
	@echo "  make clean        - Clean build artifacts"
	@echo ""

# Simulation
.PHONY: sim
sim:
	@echo "Running RTL simulation..."
	@mkdir -p $(SIM_DIR)
	cd $(SIM_DIR) && ../scripts/simulation/run_sim.sh

.PHONY: sim_unit
sim_unit:
	@echo "Running unit tests..."
	@mkdir -p $(SIM_DIR)/unit
	cd $(SIM_DIR)/unit && ../../scripts/simulation/run_unit_tests.sh

.PHONY: sim_uvm
sim_uvm:
	@echo "Running UVM tests..."
	@mkdir -p $(SIM_DIR)/uvm
	cd $(SIM_DIR)/uvm && ../../scripts/simulation/run_uvm.sh

# Synthesis
.PHONY: synth
synth: synth_fpga

.PHONY: synth_fpga
synth_fpga:
	@echo "Running FPGA synthesis..."
	@mkdir -p $(SYN_DIR)/fpga
	cd $(SYN_DIR)/fpga && ../../scripts/synthesis/run_fpga_synth.sh

.PHONY: synth_asic
synth_asic:
	@echo "Running ASIC synthesis..."
	@mkdir -p $(SYN_DIR)/asic
	cd $(SYN_DIR)/asic && ../../scripts/synthesis/run_asic_synth.sh

# Verification
.PHONY: lint
lint:
	@echo "Running linting..."
	verilator --lint-only -Wall $(RTL_DIR)/top/npu_top.sv

.PHONY: formal
formal:
	@echo "Running formal verification..."
	cd verification/formal && ../../scripts/verification/run_formal.sh

.PHONY: coverage
coverage:
	@echo "Generating coverage report..."
	cd verification/coverage && ../../scripts/verification/gen_coverage.sh

# Clean
.PHONY: clean
clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(SIM_DIR) $(BUILD_DIR) $(SYN_DIR)
	find . -name "*.vcd" -delete
	find . -name "*.log" -delete
