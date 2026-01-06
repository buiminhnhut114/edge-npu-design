// EdgeNPU RTL File List (V2 - Enhanced)
// Use with: iverilog -f filelist.f -o npu_sim

// Include paths
+incdir+rtl/top

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

// Core modules - Convolution
rtl/core/conv/conv_controller.sv
rtl/core/conv/depthwise_conv.sv

// Core modules - Control
rtl/core/controller/npu_controller.sv
rtl/core/decoder/instruction_decoder.sv
rtl/core/scheduler/instruction_scheduler.sv

// Memory modules
rtl/memory/sram/sram_sp.sv
rtl/memory/buffer/weight_buffer.sv
rtl/memory/buffer/activation_buffer.sv
rtl/memory/dma/dma_engine.sv

// Interconnect
rtl/interconnect/axi/axi_lite_slave.sv

// Debug Interface
rtl/debug/npu_debug_if.sv

// Top level
rtl/top/npu_top.sv
rtl/top/npu_top_v2.sv

// IP cores
ip/memory/sync_fifo.sv
ip/memory/async_fifo.sv
ip/memory/sram_dp.sv
ip/memory/mem_arbiter.sv
ip/npu/quantizer.sv
ip/npu/dequantizer.sv
ip/npu/data_reshaper.sv
ip/npu/perf_counter.sv
ip/clk_rst/clk_rst_gen.sv
ip/clk_rst/reset_sync.sv
ip/clk_rst/cdc_sync.sv
ip/utils/interrupt_ctrl.sv
ip/utils/timer.sv
ip/utils/watchdog.sv
ip/utils/gpio_ctrl.sv

// Third-party IPs - PE Array (from opensource)
+incdir+ip/third_party/pe_array
ip/third_party/pe_array/parameters.vh
ip/third_party/pe_array/alu.v
ip/third_party/pe_array/complex_alu.v
ip/third_party/pe_array/control.v
ip/third_party/pe_array/data_mem.v
ip/third_party/pe_array/inst_rom.v
ip/third_party/pe_array/const_rom.v
ip/third_party/pe_array/sdp_bram.v
ip/third_party/pe_array/SIPO.v
ip/third_party/pe_array/PISO.v
ip/third_party/pe_array/sipo_x.v
ip/third_party/pe_array/sipo_y.v
ip/third_party/pe_array/piso_new.v
ip/third_party/pe_array/srl.v
ip/third_party/pe_array/pe.v
ip/third_party/pe_array/pe_simd.v
ip/third_party/pe_array/pe_array.v
ip/third_party/pe_array/pe_array_wrapper.sv
ip/third_party/pe_array/complex_alu_wrapper.sv

// Third-party IPs - Debug Interface
ip/third_party/adbg_pkg.sv
ip/third_party/adbg_crc32.v
ip/third_party/syncflop.v
ip/third_party/syncreg.v
ip/third_party/bytefifo.v
ip/third_party/adbg_bus_module_core.sv
