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

#==============================================================================
# Targets
#==============================================================================

.PHONY: all clean sim sim_pe sim_full lint help test

all: help

# Create build directory
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

#------------------------------------------------------------------------------
# Simulation
#------------------------------------------------------------------------------

# PE unit test
sim_pe: $(BUILD_DIR)
	$(IVERILOG) -g2012 -Wall \
		-I$(RTL_DIR)/top \
		$(RTL_DIR)/top/npu_pkg.sv \
		$(RTL_DIR)/core/pe_array/pe.sv \
		$(TB_DIR)/unit/tb_pe.sv \
		-o $(BUILD_DIR)/pe_sim
	$(VVP) $(BUILD_DIR)/pe_sim

# PE Array test
sim_pe_array: $(BUILD_DIR)
	$(IVERILOG) -g2012 -Wall \
		-I$(RTL_DIR)/top \
		$(RTL_DIR)/top/npu_pkg.sv \
		$(RTL_DIR)/core/pe_array/pe.sv \
		$(RTL_DIR)/core/pe_array/pe_array.sv \
		$(TB_DIR)/pe_array_tb.sv \
		-o $(BUILD_DIR)/pe_array_sim
	$(VVP) $(BUILD_DIR)/pe_array_sim

# Full NPU simulation
sim: sim_full

sim_full: $(BUILD_DIR)
	@echo "Compiling NPU..."
	$(IVERILOG) -g2012 -Wall \
		-I$(RTL_DIR)/top \
		$(RTL_DIR)/top/npu_pkg.sv \
		$(RTL_DIR)/core/pe_array/pe.sv \
		$(RTL_DIR)/core/pe_array/pe_array.sv \
		$(RTL_DIR)/core/activation/activation_unit.sv \
		$(RTL_DIR)/core/pooling/pooling_unit.sv \
		$(RTL_DIR)/core/controller/npu_controller.sv \
		$(RTL_DIR)/memory/sram/sram_sp.sv \
		$(RTL_DIR)/memory/buffer/weight_buffer.sv \
		$(RTL_DIR)/memory/buffer/activation_buffer.sv \
		$(RTL_DIR)/memory/dma/dma_engine.sv \
		$(RTL_DIR)/top/npu_top.sv \
		$(TB_DIR)/npu_tb.sv \
		-o $(BUILD_DIR)/npu_sim
	@echo "Running simulation..."
	$(VVP) $(BUILD_DIR)/npu_sim
	@echo "Waveform saved to: npu_tb.vcd"

#------------------------------------------------------------------------------
# Quick test
#------------------------------------------------------------------------------

test: $(BUILD_DIR)
	@echo "Running quick tests..."
	@./scripts/simulation/run_quick_test.sh

#------------------------------------------------------------------------------
# Linting
#------------------------------------------------------------------------------

lint:
	$(VERILATOR) --lint-only -Wall \
		-I$(RTL_DIR)/top \
		$(RTL_DIR)/top/npu_pkg.sv \
		$(RTL_DIR)/top/npu_top.sv

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
	@echo "Simulation:"
	@echo "  make test         - Run quick tests"
	@echo "  make sim_pe       - Run PE unit test"
	@echo "  make sim_pe_array - Run PE Array test"
	@echo "  make sim          - Run full NPU simulation"
	@echo ""
	@echo "Other:"
	@echo "  make lint         - Run Verilator lint"
	@echo "  make clean        - Clean build artifacts"
	@echo "  make help         - Show this help"
	@echo ""
	@echo "View waveforms:"
	@echo "  gtkwave npu_tb.vcd"
