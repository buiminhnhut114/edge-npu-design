//=============================================================================
// AXI-Lite Interface
// SystemVerilog interface for AXI-Lite signals
//=============================================================================

`timescale 1ns/1ps

interface axil_if (input logic clk, input logic rst_n);
    
    //=========================================================================
    // Write Address Channel
    //=========================================================================
    
    logic [31:0] awaddr;
    logic        awvalid;
    logic        awready;
    
    //=========================================================================
    // Write Data Channel
    //=========================================================================
    
    logic [31:0] wdata;
    logic [3:0]  wstrb;
    logic        wvalid;
    logic        wready;
    
    //=========================================================================
    // Write Response Channel
    //=========================================================================
    
    logic [1:0]  bresp;
    logic        bvalid;
    logic        bready;
    
    //=========================================================================
    // Read Address Channel
    //=========================================================================
    
    logic [31:0] araddr;
    logic        arvalid;
    logic        arready;
    
    //=========================================================================
    // Read Data Channel
    //=========================================================================
    
    logic [31:0] rdata;
    logic [1:0]  rresp;
    logic        rvalid;
    logic        rready;
    
    //=========================================================================
    // Clocking Blocks
    //=========================================================================
    
    clocking drv_cb @(posedge clk);
        default input #1 output #1;
        output awaddr, awvalid;
        input  awready;
        output wdata, wstrb, wvalid;
        input  wready;
        input  bresp, bvalid;
        output bready;
        output araddr, arvalid;
        input  arready;
        input  rdata, rresp, rvalid;
        output rready;
    endclocking
    
    clocking mon_cb @(posedge clk);
        default input #1;
        input awaddr, awvalid, awready;
        input wdata, wstrb, wvalid, wready;
        input bresp, bvalid, bready;
        input araddr, arvalid, arready;
        input rdata, rresp, rvalid, rready;
    endclocking
    
    //=========================================================================
    // Modports
    //=========================================================================
    
    modport master (
        output awaddr, awvalid,
        input  awready,
        output wdata, wstrb, wvalid,
        input  wready,
        input  bresp, bvalid,
        output bready,
        output araddr, arvalid,
        input  arready,
        input  rdata, rresp, rvalid,
        output rready
    );
    
    modport slave (
        input  awaddr, awvalid,
        output awready,
        input  wdata, wstrb, wvalid,
        output wready,
        output bresp, bvalid,
        input  bready,
        input  araddr, arvalid,
        output arready,
        output rdata, rresp, rvalid,
        input  rready
    );
    
    //=========================================================================
    // Assertions
    //=========================================================================
    
    // Write address must be stable while valid
    property p_awaddr_stable;
        @(posedge clk) disable iff (!rst_n)
        awvalid && !awready |=> $stable(awaddr);
    endproperty
    assert property (p_awaddr_stable);
    
    // Read address must be stable while valid
    property p_araddr_stable;
        @(posedge clk) disable iff (!rst_n)
        arvalid && !arready |=> $stable(araddr);
    endproperty
    assert property (p_araddr_stable);
    
    // Write data must be stable while valid
    property p_wdata_stable;
        @(posedge clk) disable iff (!rst_n)
        wvalid && !wready |=> $stable(wdata);
    endproperty
    assert property (p_wdata_stable);

endinterface
