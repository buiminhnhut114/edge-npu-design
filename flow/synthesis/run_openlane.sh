#!/bin/bash
#=============================================================================
# Run OpenLane for NPU design
#=============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPENLANE_DIR="${OPENLANE_DIR:-$HOME/OpenLane}"
DESIGN="${1:-pe}"

echo "========================================="
echo "  Running OpenLane for: $DESIGN"
echo "========================================="

# Prepare design files
$SCRIPT_DIR/prepare_design.sh

# Copy specific design files
if [ "$DESIGN" == "pe" ]; then
    cp "$SCRIPT_DIR/../rtl/top/npu_pkg.sv" "$SCRIPT_DIR/pe/src/"
    cp "$SCRIPT_DIR/../rtl/core/pe_array/pe.sv" "$SCRIPT_DIR/pe/src/"
fi

# Check if OpenLane exists
if [ ! -d "$OPENLANE_DIR" ]; then
    echo "Error: OpenLane not found at $OPENLANE_DIR"
    echo "Set OPENLANE_DIR environment variable to your OpenLane installation"
    exit 1
fi

cd "$OPENLANE_DIR"

# Run with Docker
echo ""
echo "Running OpenLane flow..."
echo ""

# Option 1: Using make mount (interactive)
# make mount
# ./flow.tcl -design $SCRIPT_DIR/$DESIGN

# Option 2: Direct docker run
# Find PDK path - look for directory containing sky130A
PDK_VERSION_DIR=$(ls -d ~/.ciel/ciel/sky130/versions/*/ 2>/dev/null | head -1)
if [ -z "$PDK_VERSION_DIR" ]; then
    echo "Error: PDK not found at ~/.ciel/ciel/sky130/versions/"
    exit 1
fi
echo "Using PDK: $PDK_VERSION_DIR"

docker run --rm \
    -v "$OPENLANE_DIR:/openlane" \
    -v "$SCRIPT_DIR:/design" \
    -v "$PDK_VERSION_DIR:/PDK" \
    -e PDK_ROOT=/PDK \
    -e PDK=sky130A \
    -w /openlane \
    ghcr.io/the-openroad-project/openlane:ff5509f65b17bfa4068d5336495ab1718987ff69 \
    bash -c "cd /openlane && ./flow.tcl -design /design/$DESIGN -tag run_$(date +%Y%m%d_%H%M%S)"

echo ""
echo "========================================="
echo "  OpenLane flow completed!"
echo "========================================="
echo "Results in: $SCRIPT_DIR/$DESIGN/runs/"
