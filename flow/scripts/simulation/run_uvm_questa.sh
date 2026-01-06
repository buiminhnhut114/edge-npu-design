#!/bin/bash
#=============================================================================
# Run UVM Tests with Questa/ModelSim
# Usage: ./run_uvm_questa.sh [test_name]
#=============================================================================

set -e

# Configuration
VSIM="/home/minhnhut/Downloads/mentor_graphic/questasim/install/questasim/linux_x86_64/vsim"
VLOG="/home/minhnhut/Downloads/mentor_graphic/questasim/install/questasim/linux_x86_64/vlog"
VLIB="/home/minhnhut/Downloads/mentor_graphic/questasim/install/questasim/linux_x86_64/vlib"

TEST_NAME="${1:-npu_sanity_test}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
UVM_DIR="$PROJECT_ROOT/verification/uvm"
RTL_DIR="$PROJECT_ROOT/rtl"
BUILD_DIR="$PROJECT_ROOT/build/uvm"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  EdgeNPU UVM Test (Questa)${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Test: $TEST_NAME"
echo "Build dir: $BUILD_DIR"
echo ""

mkdir -p $BUILD_DIR

#-----------------------------------------------------------------------------
# Create work library
#-----------------------------------------------------------------------------
echo -e "${YELLOW}Creating work library...${NC}"

if [ ! -d "$BUILD_DIR/work" ]; then
    $VLIB $BUILD_DIR/work
fi

#-----------------------------------------------------------------------------
# Compile RTL
#-----------------------------------------------------------------------------
echo -e "${YELLOW}Compiling RTL...${NC}"

$VLOG -sv -work $BUILD_DIR/work \
    +incdir+$RTL_DIR/top \
    $RTL_DIR/top/npu_pkg.sv \
    $RTL_DIR/core/pe_array/pe.sv \
    $RTL_DIR/core/pe_array/pe_array.sv \
    $RTL_DIR/core/activation/activation_unit.sv \
    $RTL_DIR/core/pooling/pooling_unit.sv \
    $RTL_DIR/core/controller/npu_controller.sv \
    $RTL_DIR/memory/sram/sram_sp.sv \
    $RTL_DIR/memory/buffer/weight_buffer.sv \
    $RTL_DIR/memory/buffer/activation_buffer.sv \
    $RTL_DIR/memory/dma/dma_engine.sv \
    $RTL_DIR/top/npu_top.sv \
    -l $BUILD_DIR/compile_rtl.log

#-----------------------------------------------------------------------------
# Compile UVM Testbench
#-----------------------------------------------------------------------------
echo -e "${YELLOW}Compiling UVM testbench...${NC}"

$VLOG -sv -work $BUILD_DIR/work \
    +incdir+$UVM_DIR \
    +incdir+$UVM_DIR/agents/axil_agent \
    +incdir+$UVM_DIR/sequences \
    +incdir+$UVM_DIR/env \
    +incdir+$UVM_DIR/tests \
    +incdir+$RTL_DIR/top \
    $UVM_DIR/agents/axil_agent/axil_if.sv \
    $UVM_DIR/npu_pkg.sv \
    $UVM_DIR/tb/npu_uvm_tb.sv \
    -l $BUILD_DIR/compile_uvm.log

echo -e "${GREEN}Compilation successful!${NC}"
echo ""

#-----------------------------------------------------------------------------
# Run simulation
#-----------------------------------------------------------------------------
echo -e "${YELLOW}Running simulation...${NC}"
echo ""

$VSIM -c -L $BUILD_DIR/work -work $BUILD_DIR/work npu_uvm_tb \
    +UVM_TESTNAME=$TEST_NAME \
    +UVM_VERBOSITY=UVM_MEDIUM \
    -do "run -all; quit -f" \
    -l $BUILD_DIR/sim_${TEST_NAME}.log

#-----------------------------------------------------------------------------
# Show results
#-----------------------------------------------------------------------------
echo ""
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}  Test Results${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

# Extract key results from log
if [ -f "$BUILD_DIR/sim_${TEST_NAME}.log" ]; then
    echo "Key messages from log:"
    echo ""
    grep -E "UVM_INFO|UVM_WARNING|UVM_ERROR|UVM_FATAL|PASSED|FAILED" $BUILD_DIR/sim_${TEST_NAME}.log | tail -30
    echo ""
    
    # Check pass/fail
    if grep -q "TEST PASSED" $BUILD_DIR/sim_${TEST_NAME}.log; then
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}  ✓ TEST PASSED${NC}"
        echo -e "${GREEN}========================================${NC}"
    elif grep -q "TEST FAILED\|UVM_FATAL\|UVM_ERROR" $BUILD_DIR/sim_${TEST_NAME}.log; then
        echo -e "${RED}========================================${NC}"
        echo -e "${RED}  ✗ TEST FAILED${NC}"
        echo -e "${RED}========================================${NC}"
    else
        echo -e "${YELLOW}========================================${NC}"
        echo -e "${YELLOW}  Test completed (check log for details)${NC}"
        echo -e "${YELLOW}========================================${NC}"
    fi
fi

echo ""
echo "Full log: $BUILD_DIR/sim_${TEST_NAME}.log"
echo ""
echo "Available tests:"
echo "  - npu_sanity_test"
echo "  - npu_reg_test"
echo "  - npu_conv_test"
