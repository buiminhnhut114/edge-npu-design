// EdgeNPU RTL File List
// Use with: iverilog -f filelist.f -o npu_sim

// Include paths
+incdir+rtl/top

// Package (must be first)
rtl/top/npu_pkg.sv

// Core modules
rtl/core/pe_array/pe.sv
rtl/core/pe_array/pe_array.sv
rtl/core/activation/activation_unit.sv
rtl/core/accumulator/accumulator.sv
rtl/core/pooling/pooling_unit.sv
rtl/core/controller/npu_controller.sv

// Memory modules
rtl/memory/sram/sram_sp.sv
rtl/memory/buffer/weight_buffer.sv
rtl/memory/buffer/activation_buffer.sv
rtl/memory/dma/dma_engine.sv

// Interconnect
rtl/interconnect/axi/axi_lite_slave.sv

// Top level
rtl/top/npu_top.sv
