#!/bin/bash
#=============================================================================
# Run Unit Tests Script
# Runs all unit tests for EdgeNPU components
#=============================================================================

set -e

# Configuration
SIMULATOR="${SIMULATOR:-iverilog}"
RTL_DIR="../../rtl"
TB_DIR="../../verification/tb"
BUILD_DIR="./build"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test results
PASSED=0
FAILED=0
TESTS=()

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  EdgeNPU Unit Tests${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

mkdir -p $BUILD_DIR

#-----------------------------------------------------------------------------
# Helper function to run a test
#-----------------------------------------------------------------------------
run_test() {
    local test_name=$1
    local top_module=$2
    local rtl_files=$3
    local tb_file=$4
    
    echo -e "${BLUE}[TEST] $test_name${NC}"
    
    if $SIMULATOR -g2012 -o $BUILD_DIR/${test_name}.vvp \
        -I$RTL_DIR/top \
        $rtl_files \
        $tb_file 2>/dev/null; then
        
        if vvp $BUILD_DIR/${test_name}.vvp 2>&1 | tee $BUILD_DIR/${test_name}.log | grep -q "PASS\|passed\|Complete"; then
            echo -e "${GREEN}  ✓ PASSED${NC}"
            ((PASSED++))
            TESTS+=("$test_name:PASS")
        else
            echo -e "${RED}  ✗ FAILED${NC}"
            ((FAILED++))
            TESTS+=("$test_name:FAIL")
        fi
    else
        echo -e "${RED}  ✗ COMPILE ERROR${NC}"
        ((FAILED++))
        TESTS+=("$test_name:COMPILE_ERROR")
    fi
    echo ""
}

#-----------------------------------------------------------------------------
# Test 1: PE Unit Test
#-----------------------------------------------------------------------------
run_test "pe_unit" "tb_pe" \
    "$RTL_DIR/top/npu_pkg.sv $RTL_DIR/core/pe_array/pe.sv" \
    "$TB_DIR/unit/tb_pe.sv"

#-----------------------------------------------------------------------------
# Test 2: PE Array Test
#-----------------------------------------------------------------------------
run_test "pe_array" "pe_array_tb" \
    "$RTL_DIR/top/npu_pkg.sv $RTL_DIR/core/pe_array/pe.sv $RTL_DIR/core/pe_array/pe_array.sv" \
    "$TB_DIR/pe_array_tb.sv"

#-----------------------------------------------------------------------------
# Test 3: Activation Unit Test (if exists)
#-----------------------------------------------------------------------------
if [ -f "$TB_DIR/unit/tb_activation.sv" ]; then
    run_test "activation" "tb_activation" \
        "$RTL_DIR/top/npu_pkg.sv $RTL_DIR/core/activation/activation_unit.sv" \
        "$TB_DIR/unit/tb_activation.sv"
fi

#-----------------------------------------------------------------------------
# Test 4: Pooling Unit Test (if exists)
#-----------------------------------------------------------------------------
if [ -f "$TB_DIR/unit/tb_pooling.sv" ]; then
    run_test "pooling" "tb_pooling" \
        "$RTL_DIR/top/npu_pkg.sv $RTL_DIR/core/pooling/pooling_unit.sv" \
        "$TB_DIR/unit/tb_pooling.sv"
fi

#-----------------------------------------------------------------------------
# Summary
#-----------------------------------------------------------------------------
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Test Summary${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Results:"
for test in "${TESTS[@]}"; do
    name="${test%%:*}"
    result="${test##*:}"
    if [ "$result" == "PASS" ]; then
        echo -e "  ${GREEN}✓${NC} $name"
    else
        echo -e "  ${RED}✗${NC} $name ($result)"
    fi
done
echo ""
echo -e "Total: $((PASSED + FAILED)) tests"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
