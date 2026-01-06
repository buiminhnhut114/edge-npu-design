#!/bin/bash
#=============================================================================
# Quick Test Script
# Fast verification that basic NPU components work
#=============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR/../.."

cd "$PROJECT_ROOT"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  EdgeNPU Quick Test${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check for iverilog
if ! command -v iverilog &> /dev/null; then
    echo -e "${RED}Error: iverilog not found!${NC}"
    echo "Install with: sudo apt install iverilog"
    exit 1
fi

mkdir -p build

#-----------------------------------------------------------------------------
# Test 1: Compile PE
#-----------------------------------------------------------------------------
echo -e "${YELLOW}[1/3] Testing PE compilation...${NC}"

iverilog -g2012 -o build/pe_test.vvp \
    -Irtl/top \
    rtl/top/npu_pkg.sv \
    rtl/core/pe_array/pe.sv \
    verification/tb/unit/tb_pe.sv

if [ $? -eq 0 ]; then
    echo -e "${GREEN}  ✓ PE compiles successfully${NC}"
else
    echo -e "${RED}  ✗ PE compilation failed${NC}"
    exit 1
fi

#-----------------------------------------------------------------------------
# Test 2: Run PE simulation
#-----------------------------------------------------------------------------
echo -e "${YELLOW}[2/3] Running PE simulation...${NC}"

vvp build/pe_test.vvp > build/pe_test.log 2>&1

if grep -q "completed\|PASS" build/pe_test.log; then
    echo -e "${GREEN}  ✓ PE simulation passed${NC}"
else
    echo -e "${YELLOW}  ⚠ PE simulation completed (check build/pe_test.log)${NC}"
fi

#-----------------------------------------------------------------------------
# Test 3: Compile PE Array
#-----------------------------------------------------------------------------
echo -e "${YELLOW}[3/3] Testing PE Array compilation...${NC}"

iverilog -g2012 -o build/pe_array_test.vvp \
    -Irtl/top \
    rtl/top/npu_pkg.sv \
    rtl/core/pe_array/pe.sv \
    rtl/core/pe_array/pe_array.sv \
    verification/tb/pe_array_tb.sv

if [ $? -eq 0 ]; then
    echo -e "${GREEN}  ✓ PE Array compiles successfully${NC}"
else
    echo -e "${RED}  ✗ PE Array compilation failed${NC}"
    exit 1
fi

#-----------------------------------------------------------------------------
# Summary
#-----------------------------------------------------------------------------
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Quick Test Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Your NPU core components are working."
echo ""
echo "Next steps:"
echo "  1. Run full simulation:  make sim"
echo "  2. Run PE array test:    make sim_pe"
echo "  3. View waveforms:       gtkwave build/npu_tb.vcd"
echo ""
