#!/bin/bash
#=============================================================================
# Run UVM Tests Script
# Usage: ./run_uvm.sh [test_name]
#=============================================================================

set -e

# Configuration
SIMULATOR="${SIMULATOR:-vcs}"
TEST_NAME="${1:-npu_sanity_test}"
UVM_DIR="../../verification/uvm"
RTL_DIR="../../rtl"
BUILD_DIR="./build"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  EdgeNPU UVM Test${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Simulator: $SIMULATOR"
echo "Test: $TEST_NAME"
echo ""

mkdir -p $BUILD_DIR

#-----------------------------------------------------------------------------
# Compile
#-----------------------------------------------------------------------------
echo -e "${YELLOW}Compiling...${NC}"

case $SIMULATOR in
    vcs)
        vcs -full64 -sverilog -ntb_opts uvm-1.2 \
            +incdir+$UVM_DIR \
            +incdir+$UVM_DIR/agents/axil_agent \
            +incdir+$UVM_DIR/sequences \
            +incdir+$UVM_DIR/env \
            +incdir+$UVM_DIR/tests \
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
            $UVM_DIR/agents/axil_agent/axil_if.sv \
            $UVM_DIR/npu_pkg.sv \
            $UVM_DIR/tb/npu_uvm_tb.sv \
            -o $BUILD_DIR/simv \
            -l $BUILD_DIR/compile.log
        ;;
    
    questa|modelsim)
        vlib $BUILD_DIR/work
        vlog -sv +incdir+$UVM_DIR +incdir+$RTL_DIR/top \
            $RTL_DIR/top/npu_pkg.sv \
            $RTL_DIR/top/npu_top.sv \
            $UVM_DIR/npu_pkg.sv \
            $UVM_DIR/tb/npu_uvm_tb.sv \
            -work $BUILD_DIR/work
        ;;
    
    xcelium)
        xrun -compile -uvm -uvmhome CDNS-1.2 \
            +incdir+$UVM_DIR \
            +incdir+$RTL_DIR/top \
            $RTL_DIR/top/npu_pkg.sv \
            $RTL_DIR/top/npu_top.sv \
            $UVM_DIR/npu_pkg.sv \
            $UVM_DIR/tb/npu_uvm_tb.sv \
            -xmlibdirpath $BUILD_DIR
        ;;
    
    *)
        echo -e "${RED}Unknown simulator: $SIMULATOR${NC}"
        echo "Supported: vcs, questa, modelsim, xcelium"
        exit 1
        ;;
esac

echo -e "${GREEN}Compilation successful!${NC}"
echo ""

#-----------------------------------------------------------------------------
# Run simulation
#-----------------------------------------------------------------------------
echo -e "${YELLOW}Running simulation...${NC}"
echo ""

case $SIMULATOR in
    vcs)
        $BUILD_DIR/simv +UVM_TESTNAME=$TEST_NAME +UVM_VERBOSITY=UVM_MEDIUM \
            -l $BUILD_DIR/sim.log
        ;;
    
    questa|modelsim)
        vsim -c -L $BUILD_DIR/work npu_uvm_tb \
            +UVM_TESTNAME=$TEST_NAME \
            -do "run -all; quit" \
            -l $BUILD_DIR/sim.log
        ;;
    
    xcelium)
        xrun -R -uvm -uvmhome CDNS-1.2 \
            +UVM_TESTNAME=$TEST_NAME \
            -xmlibdirpath $BUILD_DIR \
            -l $BUILD_DIR/sim.log
        ;;
esac

#-----------------------------------------------------------------------------
# Check results
#-----------------------------------------------------------------------------
echo ""
if grep -q "TEST PASSED" $BUILD_DIR/sim.log 2>/dev/null; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  TEST PASSED${NC}"
    echo -e "${GREEN}========================================${NC}"
elif grep -q "TEST FAILED" $BUILD_DIR/sim.log 2>/dev/null; then
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}  TEST FAILED${NC}"
    echo -e "${RED}========================================${NC}"
else
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}  Test completed (check log for results)${NC}"
    echo -e "${YELLOW}========================================${NC}"
fi

echo ""
echo "Log file: $BUILD_DIR/sim.log"
