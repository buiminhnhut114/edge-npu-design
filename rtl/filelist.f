// EdgeNPU RTL File List (V2 - Complete)
// Use with: iverilog -f filelist.f -o npu_sim

// Include paths
+incdir+rtl/top
+incdir+ip/third_party/pe_array

// Package (must be first)
rtl/top/npu_pkg.sv

// Core modules - PE Array
rtl/core/pe_array/pe.sv
rtl/core/pe_array/pe_array.sv

// Core modules - Compute Units
rtl/core/activation/activation_unit.sv
rtl/core/accumulator/accumulator.sv
rtl/core/pooling/pooling_unit.sv
rtl/core/batchnorm/batchnorm_unit.sv
rtl/core/softmax/softmax_unit.sv
rtl/core/elementwise/elementwise_unit.sv
rtl/core/bias/bias_add.sv

// Core modules - Convolution
rtl/core/conv/conv_controller.sv
rtl/core/conv/depthwise_conv.sv

// Core modules - Tensor Operations
rtl/core/reshape/tensor_reshape.sv

// Core modules - Control
rtl/core/controller/npu_controller.sv
rtl/core/decoder/instruction_decoder.sv
rtl/core/scheduler/instruction_scheduler.sv

// Memory modules
rtl/memory/sram/sram_sp.sv
rtl/memory/buffer/weight_buffer.sv
rtl/memory/buffer/activation_buffer.sv
rtl/memory/buffer/instruction_buffer.sv
rtl/memory/buffer/output_buffer.sv
rtl/memory/dma/dma_engine.sv

// Interconnect
rtl/interconnect/axi/axi_lite_slave.sv

// Debug Interface
rtl/debug/npu_debug_if.sv

// Top level
rtl/top/npu_top.sv
rtl/top/npu_top_v2.sv

// IP cores - Memory
ip/memory/sync_fifo.sv
ip/memory/async_fifo.sv
ip/memory/sram_dp.sv
ip/memory/mem_arbiter.sv

// IP cores - NPU specific
ip/npu/quantizer.sv
ip/npu/dequantizer.sv
ip/npu/data_reshaper.sv
ip/npu/perf_counter.sv

// IP cores - Clock/Reset
ip/clk_rst/clk_rst_gen.sv
ip/clk_rst/reset_sync.sv
ip/clk_rst/cdc_sync.sv

// IP cores - AXI
ip/axi/axi4_master.sv
ip/axi/axi4_slave.sv
ip/axi/axi4_stream_master.sv
ip/axi/axi4_stream_slave.sv

// Third-party - PE Array (DSP48E2 based)
ip/third_party/pe_array/alu.v
ip/third_party/pe_array/complex_alu.v
ip/third_party/pe_array/sdp_bram.v
ip/third_party/pe_array/pe_array_wrapper.sv
ip/third_party/pe_array/complex_alu_wrapper.sv

// Third-party - CDC
ip/third_party/syncflop.v
ip/third_party/syncreg.v

// Third-party - Memory models
ip/third_party/memory_models/npu_fpga_sram.v
ip/third_party/memory_models/npu_ahb_ram_beh.v

// Third-party - Bus components
ip/third_party/bus_components/npu_ahb_to_sram.v
