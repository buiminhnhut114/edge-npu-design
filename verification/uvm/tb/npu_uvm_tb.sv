//=============================================================================
// NPU UVM Testbench Top
// Top-level module for UVM testbench
//=============================================================================

`timescale 1ns/1ps

module npu_uvm_tb;
    
    import uvm_pkg::*;
    import npu_uvm_pkg::*;
    `include "uvm_macros.svh"
    
    //=========================================================================
    // Parameters
    //=========================================================================
    
    parameter int CLK_PERIOD = 10;  // 100MHz
    parameter int PE_ROWS = 16;
    parameter int PE_COLS = 16;
    
    //=========================================================================
    // Clock and Reset
    //=========================================================================
    
    logic clk;
    logic rst_n;
    
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    initial begin
        rst_n = 0;
        repeat(10) @(posedge clk);
        rst_n = 1;
    end
    
    //=========================================================================
    // Interfaces
    //=========================================================================
    
    axil_if axil_vif(clk, rst_n);
    
    //=========================================================================
    // AXI4 Master Signals (stub)
    //=========================================================================
    
    logic [39:0]  m_axi_awaddr;
    logic [7:0]   m_axi_awlen;
    logic [2:0]   m_axi_awsize;
    logic [1:0]   m_axi_awburst;
    logic         m_axi_awvalid;
    logic         m_axi_awready;
    logic [127:0] m_axi_wdata;
    logic [15:0]  m_axi_wstrb;
    logic         m_axi_wlast;
    logic         m_axi_wvalid;
    logic         m_axi_wready;
    logic [1:0]   m_axi_bresp;
    logic         m_axi_bvalid;
    logic         m_axi_bready;
    logic [39:0]  m_axi_araddr;
    logic [7:0]   m_axi_arlen;
    logic [2:0]   m_axi_arsize;
    logic [1:0]   m_axi_arburst;
    logic         m_axi_arvalid;
    logic         m_axi_arready;
    logic [127:0] m_axi_rdata;
    logic [1:0]   m_axi_rresp;
    logic         m_axi_rlast;
    logic         m_axi_rvalid;
    logic         m_axi_rready;
    
    logic irq;
    
    // AXI slave stub
    assign m_axi_awready = 1'b1;
    assign m_axi_wready  = 1'b1;
    assign m_axi_bresp   = 2'b00;
    assign m_axi_bvalid  = 1'b1;
    assign m_axi_arready = 1'b1;
    assign m_axi_rdata   = 128'h0;
    assign m_axi_rresp   = 2'b00;
    assign m_axi_rlast   = 1'b1;
    assign m_axi_rvalid  = 1'b1;
    
    //=========================================================================
    // DUT
    //=========================================================================
    
    npu_top #(
        .PE_ROWS    (PE_ROWS),
        .PE_COLS    (PE_COLS)
    ) dut (
        .clk            (clk),
        .rst_n          (rst_n),
        
        // AXI4 Master
        .m_axi_awaddr   (m_axi_awaddr),
        .m_axi_awlen    (m_axi_awlen),
        .m_axi_awsize   (m_axi_awsize),
        .m_axi_awburst  (m_axi_awburst),
        .m_axi_awvalid  (m_axi_awvalid),
        .m_axi_awready  (m_axi_awready),
        .m_axi_wdata    (m_axi_wdata),
        .m_axi_wstrb    (m_axi_wstrb),
        .m_axi_wlast    (m_axi_wlast),
        .m_axi_wvalid   (m_axi_wvalid),
        .m_axi_wready   (m_axi_wready),
        .m_axi_bresp    (m_axi_bresp),
        .m_axi_bvalid   (m_axi_bvalid),
        .m_axi_bready   (m_axi_bready),
        .m_axi_araddr   (m_axi_araddr),
        .m_axi_arlen    (m_axi_arlen),
        .m_axi_arsize   (m_axi_arsize),
        .m_axi_arburst  (m_axi_arburst),
        .m_axi_arvalid  (m_axi_arvalid),
        .m_axi_arready  (m_axi_arready),
        .m_axi_rdata    (m_axi_rdata),
        .m_axi_rresp    (m_axi_rresp),
        .m_axi_rlast    (m_axi_rlast),
        .m_axi_rvalid   (m_axi_rvalid),
        .m_axi_rready   (m_axi_rready),
        
        // AXI-Lite Slave
        .s_axil_awaddr  (axil_vif.awaddr),
        .s_axil_awvalid (axil_vif.awvalid),
        .s_axil_awready (axil_vif.awready),
        .s_axil_wdata   (axil_vif.wdata),
        .s_axil_wstrb   (axil_vif.wstrb),
        .s_axil_wvalid  (axil_vif.wvalid),
        .s_axil_wready  (axil_vif.wready),
        .s_axil_bresp   (axil_vif.bresp),
        .s_axil_bvalid  (axil_vif.bvalid),
        .s_axil_bready  (axil_vif.bready),
        .s_axil_araddr  (axil_vif.araddr),
        .s_axil_arvalid (axil_vif.arvalid),
        .s_axil_arready (axil_vif.arready),
        .s_axil_rdata   (axil_vif.rdata),
        .s_axil_rresp   (axil_vif.rresp),
        .s_axil_rvalid  (axil_vif.rvalid),
        .s_axil_rready  (axil_vif.rready),
        
        .irq            (irq)
    );
    
    //=========================================================================
    // UVM Configuration
    //=========================================================================
    
    initial begin
        // Set virtual interface
        uvm_config_db#(virtual axil_if)::set(null, "*", "vif", axil_vif);
        
        // Run test
        run_test();
    end
    
    //=========================================================================
    // Waveform Dump
    //=========================================================================
    
    initial begin
        $dumpfile("npu_uvm_tb.vcd");
        $dumpvars(0, npu_uvm_tb);
    end

endmodule
