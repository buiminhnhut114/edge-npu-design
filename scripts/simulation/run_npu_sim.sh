#!/bin/bash
#=============================================================================
# Run NPU Full Simulation
# Complete system-level simulation of EdgeNPU
#=============================================================================

set -e

# Configuration
SIMULATOR="${SIMULATOR:-iverilog}"
RTL_DIR="../../rtl"
IP_DIR="../../ip"
TB_DIR="../../verification/tb"
BUILD_DIR="./build"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  EdgeNPU Full Simulation${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

mkdir -p $BUILD_DIR

#-----------------------------------------------------------------------------
# Collect RTL files
#-----------------------------------------------------------------------------
echo -e "${YELLOW}Collecting RTL files...${NC}"

RTL_FILES="
$RTL_DIR/top/npu_pkg.sv
$RTL_DIR/core/pe_array/pe.sv
$RTL_DIR/core/pe_array/pe_array.sv
$RTL_DIR/core/activation/activation_unit.sv
$RTL_DIR/core/accumulator/accumulator.sv
$RTL_DIR/core/pooling/pooling_unit.sv
$RTL_DIR/core/controller/npu_controller.sv
$RTL_DIR/memory/sram/sram_sp.sv
$RTL_DIR/memory/buffer/weight_buffer.sv
$RTL_DIR/memory/buffer/activation_buffer.sv
$RTL_DIR/memory/dma/dma_engine.sv
$RTL_DIR/top/npu_top.sv
"

TB_FILE="$TB_DIR/npu_tb.sv"

#-----------------------------------------------------------------------------
# Compile
#-----------------------------------------------------------------------------
echo -e "${YELLOW}Compiling...${NC}"

case $SIMULATOR in
    iverilog)
        iverilog -g2012 -Wall \
            -I$RTL_DIR/top \
            -o $BUILD_DIR/npu_sim.vvp \
            $RTL_FILES \
            $TB_FILE \
            2>&1 | tee $BUILD_DIR/compile.log
        
        if [ ${PIPESTATUS[0]} -ne 0 ]; then
            echo -e "${RED}Compilation failed!${NC}"
            exit 1
        fi
        ;;
    
    verilator)
        verilator --binary --timing \
            -I$RTL_DIR/top \
            -Wno-fatal \
            --top-module npu_tb \
            $RTL_FILES $TB_FILE \
            -o $BUILD_DIR/npu_sim
        ;;
    
    *)
        echo -e "${RED}Unknown simulator: $SIMULATOR${NC}"
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
    iverilog)
        vvp $BUILD_DIR/npu_sim.vvp 2>&1 | tee $BUILD_DIR/sim.log
        ;;
    verilator)
        $BUILD_DIR/npu_sim 2>&1 | tee $BUILD_DIR/sim.log
        ;;
esac

#-----------------------------------------------------------------------------
# Check results
#-----------------------------------------------------------------------------
echo ""
if grep -q "PASS\|Complete\|passed" $BUILD_DIR/sim.log; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Simulation PASSED${NC}"
    echo -e "${GREEN}========================================${NC}"
else
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}  Simulation may have issues${NC}"
    echo -e "${RED}========================================${NC}"
fi

# Check for VCD file
if [ -f "npu_tb.vcd" ]; then
    mv npu_tb.vcd $BUILD_DIR/
    echo ""
    echo "Waveform saved to: $BUILD_DIR/npu_tb.vcd"
    echo "View with: gtkwave $BUILD_DIR/npu_tb.vcd"
fi
