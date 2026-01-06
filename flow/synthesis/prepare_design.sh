#!/bin/bash
#=============================================================================
# Prepare NPU design for OpenLane
#=============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
DESIGN_DIR="$SCRIPT_DIR/npu_top/src"

echo "========================================="
echo "  Preparing NPU Design for OpenLane"
echo "========================================="

# Clean and create src directory
rm -rf "$DESIGN_DIR"
mkdir -p "$DESIGN_DIR"

# Copy RTL files
echo "Copying RTL files..."

# Top level
cp "$PROJECT_ROOT/rtl/top/npu_pkg.sv" "$DESIGN_DIR/"
cp "$PROJECT_ROOT/rtl/top/npu_top.sv" "$DESIGN_DIR/"

# Core modules
cp "$PROJECT_ROOT/rtl/core/pe_array/pe.sv" "$DESIGN_DIR/"
cp "$PROJECT_ROOT/rtl/core/pe_array/pe_array.sv" "$DESIGN_DIR/"
cp "$PROJECT_ROOT/rtl/core/activation/activation_unit.sv" "$DESIGN_DIR/"
cp "$PROJECT_ROOT/rtl/core/pooling/pooling_unit.sv" "$DESIGN_DIR/"
cp "$PROJECT_ROOT/rtl/core/controller/npu_controller.sv" "$DESIGN_DIR/"

# Memory modules
cp "$PROJECT_ROOT/rtl/memory/sram/sram_sp.sv" "$DESIGN_DIR/"
cp "$PROJECT_ROOT/rtl/memory/buffer/weight_buffer.sv" "$DESIGN_DIR/"
cp "$PROJECT_ROOT/rtl/memory/buffer/activation_buffer.sv" "$DESIGN_DIR/"
cp "$PROJECT_ROOT/rtl/memory/dma/dma_engine.sv" "$DESIGN_DIR/"

echo "RTL files copied to: $DESIGN_DIR"

# Convert SystemVerilog to Verilog using sv2v (handles unpacked arrays, packages, etc.)
echo ""
echo "Converting SystemVerilog to Yosys-compatible Verilog..."

SV2V="${SV2V:-$HOME/.local/bin/sv2v}"
if [ -x "$SV2V" ] || command -v sv2v &> /dev/null; then
    [ -x "$SV2V" ] || SV2V="sv2v"
    # sv2v is available - use it for proper conversion
    cd "$DESIGN_DIR"
    $SV2V -w adjacent *.sv
    # Remove original .sv files, keep .v files
    rm -f *.sv
    echo "Converted using sv2v"
else
    echo "WARNING: sv2v not found. Attempting basic sed fixes..."
    # Basic fixes without sv2v
    for sv_file in "$DESIGN_DIR"/*.sv; do
        if [ -f "$sv_file" ]; then
            filename=$(basename "$sv_file")
            # Remove import statements
            sed -i '/^\s*import\s/d' "$sv_file"
            # Remove 'logic' keyword -> 'wire' or 'reg' (simplified)
            echo "Basic fix: $filename"
        fi
    done
    echo ""
    echo "For best results, install sv2v: https://github.com/zachjs/sv2v"
fi

echo ""
ls -la "$DESIGN_DIR"

echo ""
echo "========================================="
echo "  Design prepared successfully!"
echo "========================================="
echo ""
echo "To run OpenLane:"
echo "  cd ~/OpenLane"
echo "  make mount"
echo "  ./flow.tcl -design $SCRIPT_DIR/npu_top"
echo ""
echo "Or with Docker:"
echo "  cd ~/OpenLane"
echo "  docker run -it -v \$(pwd):/openlane -v $SCRIPT_DIR:/design efabless/openlane:latest"
echo "  ./flow.tcl -design /design/npu_top"
