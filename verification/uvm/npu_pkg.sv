//=============================================================================
// NPU UVM Package
// Common definitions for UVM testbench
//=============================================================================

`ifndef NPU_UVM_PKG_SV
`define NPU_UVM_PKG_SV

package npu_uvm_pkg;
    
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    
    import npu_pkg::*;
    
    //=========================================================================
    // Configuration
    //=========================================================================
    
    // Testbench parameters
    parameter int TB_CLK_PERIOD = 10;  // 100MHz
    parameter int TB_TIMEOUT = 100000;
    
    // AXI-Lite addresses
    parameter logic [31:0] ADDR_CTRL       = 32'h0000;
    parameter logic [31:0] ADDR_STATUS     = 32'h0004;
    parameter logic [31:0] ADDR_IRQ_EN     = 32'h0008;
    parameter logic [31:0] ADDR_IRQ_STATUS = 32'h000C;
    parameter logic [31:0] ADDR_VERSION    = 32'h0010;
    parameter logic [31:0] ADDR_CONFIG     = 32'h0014;
    parameter logic [31:0] ADDR_DMA_CTRL   = 32'h0100;
    parameter logic [31:0] ADDR_DMA_SRC    = 32'h0108;
    parameter logic [31:0] ADDR_DMA_DST    = 32'h010C;
    parameter logic [31:0] ADDR_DMA_LEN    = 32'h0110;
    
    //=========================================================================
    // Transaction Types
    //=========================================================================
    
    typedef enum {
        NPU_OP_NOP,
        NPU_OP_CONV,
        NPU_OP_FC,
        NPU_OP_POOL,
        NPU_OP_ACT,
        NPU_OP_LOAD,
        NPU_OP_STORE
    } npu_op_type_e;
    
    typedef enum {
        AXI_READ,
        AXI_WRITE
    } axi_op_type_e;
    
    //=========================================================================
    // Include UVM components (ORDER MATTERS!)
    //=========================================================================
    
    // 1. Agent components first (seq_item before others)
    `include "agents/axil_agent/axil_seq_item.sv"
    `include "agents/axil_agent/axil_driver.sv"
    `include "agents/axil_agent/axil_monitor.sv"
    `include "agents/axil_agent/axil_agent.sv"
    
    // 2. NPU sequences (depend on axil_seq_item)
    `include "sequences/npu_seq_item.sv"
    `include "sequences/npu_base_seq.sv"
    `include "sequences/npu_reg_seq.sv"
    `include "sequences/npu_conv_seq.sv"
    
    // 3. Environment components
    `include "env/npu_scoreboard.sv"
    `include "env/npu_coverage.sv"
    `include "env/npu_env.sv"
    
    // 4. Tests
    `include "tests/npu_base_test.sv"
    `include "tests/npu_reg_test.sv"
    `include "tests/npu_sanity_test.sv"
    `include "tests/npu_conv_test.sv"

endpackage

`endif
