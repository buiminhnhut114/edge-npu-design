#!/bin/bash
#=============================================================================
# Run Simulation Script
# Usage: ./run_sim.sh [testname]
#=============================================================================

set -e

# Configuration
SIMULATOR="${SIMULATOR:-iverilog}"
TOP_MODULE="${1:-tb_pe}"
RTL_DIR="../../rtl"
TB_DIR="../../verification/tb"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  EdgeNPU Simulation${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Simulator: $SIMULATOR"
echo "Test: $TOP_MODULE"
echo ""

# Find source files
RTL_FILES=$(find $RTL_DIR -name "*.sv" -o -name "*.v" | tr '\n' ' ')
TB_FILES=$(find $TB_DIR -name "*.sv" -o -name "*.v" | tr '\n' ' ')

case $SIMULATOR in
    iverilog)
        echo -e "${YELLOW}Compiling with Icarus Verilog...${NC}"
        iverilog -g2012 -o sim.vvp \
            -I$RTL_DIR/top \
            $RTL_FILES \
            $TB_FILES
        
        echo -e "${YELLOW}Running simulation...${NC}"
        vvp sim.vvp
        ;;
        
    verilator)
        echo -e "${YELLOW}Compiling with Verilator...${NC}"
        verilator --binary --timing \
            -I$RTL_DIR/top \
            -Wno-fatal \
            --top-module $TOP_MODULE \
            $RTL_FILES $TB_FILES
        
        echo -e "${YELLOW}Running simulation...${NC}"
        ./obj_dir/V${TOP_MODULE}
        ;;
        
    vcs)
        echo -e "${YELLOW}Compiling with VCS...${NC}"
        vcs -full64 -sverilog \
            +incdir+$RTL_DIR/top \
            -o simv \
            $RTL_FILES $TB_FILES
        
        echo -e "${YELLOW}Running simulation...${NC}"
        ./simv
        ;;
        
    *)
        echo -e "${RED}Unknown simulator: $SIMULATOR${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Simulation Complete${NC}"
echo -e "${GREEN}========================================${NC}"
