//=============================================================================
// NPU Testbench
// Basic verification testbench for EdgeNPU
//=============================================================================

`timescale 1ns/1ps

module npu_tb;

    //=========================================================================
    // Parameters
    //=========================================================================
    
    parameter int CLK_PERIOD = 10;  // 100MHz
    parameter int PE_ROWS = 16;
    parameter int PE_COLS = 16;
    parameter int DATA_WIDTH = 8;
    
    //=========================================================================
    // Signals
    //=========================================================================
    
    logic clk;
    logic rst_n;
    
    // AXI4 Master
    logic [39:0] m_axi_awaddr;
    logic [7:0]  m_axi_awlen;
    logic [2:0]  m_axi_awsize;
    logic [1:0]  m_axi_awburst;
    logic        m_axi_awvalid;
    logic        m_axi_awready;
    logic [127:0] m_axi_wdata;
    logic [15:0] m_axi_wstrb;
    logic        m_axi_wlast;
    logic        m_axi_wvalid;
    logic        m_axi_wready;
    logic [1:0]  m_axi_bresp;
    logic        m_axi_bvalid;
    logic        m_axi_bready;
    logic [39:0] m_axi_araddr;
    logic [7:0]  m_axi_arlen;
    logic [2:0]  m_axi_arsize;
    logic [1:0]  m_axi_arburst;
    logic        m_axi_arvalid;
    logic        m_axi_arready;
    logic [127:0] m_axi_rdata;
    logic [1:0]  m_axi_rresp;
    logic        m_axi_rlast;
    logic        m_axi_rvalid;
    logic        m_axi_rready;
    
    // AXI4-Lite Slave
    logic [31:0] s_axil_awaddr;
    logic        s_axil_awvalid;
    logic        s_axil_awready;
    logic [31:0] s_axil_wdata;
    logic [3:0]  s_axil_wstrb;
    logic        s_axil_wvalid;
    logic        s_axil_wready;
    logic [1:0]  s_axil_bresp;
    logic        s_axil_bvalid;
    logic        s_axil_bready;
    logic [31:0] s_axil_araddr;
    logic        s_axil_arvalid;
    logic        s_axil_arready;
    logic [31:0] s_axil_rdata;
    logic [1:0]  s_axil_rresp;
    logic        s_axil_rvalid;
    logic        s_axil_rready;
    
    logic irq;
    
    //=========================================================================
    // DUT
    //=========================================================================
    
    npu_top #(
        .PE_ROWS    (PE_ROWS),
        .PE_COLS    (PE_COLS),
        .DATA_WIDTH (DATA_WIDTH)
    ) dut (
        .clk            (clk),
        .rst_n          (rst_n),
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
        .s_axil_awaddr  (s_axil_awaddr),
        .s_axil_awvalid (s_axil_awvalid),
        .s_axil_awready (s_axil_awready),
        .s_axil_wdata   (s_axil_wdata),
        .s_axil_wstrb   (s_axil_wstrb),
        .s_axil_wvalid  (s_axil_wvalid),
        .s_axil_wready  (s_axil_wready),
        .s_axil_bresp   (s_axil_bresp),
        .s_axil_bvalid  (s_axil_bvalid),
        .s_axil_bready  (s_axil_bready),
        .s_axil_araddr  (s_axil_araddr),
        .s_axil_arvalid (s_axil_arvalid),
        .s_axil_arready (s_axil_arready),
        .s_axil_rdata   (s_axil_rdata),
        .s_axil_rresp   (s_axil_rresp),
        .s_axil_rvalid  (s_axil_rvalid),
        .s_axil_rready  (s_axil_rready),
        .irq            (irq)
    );
    
    //=========================================================================
    // Clock Generation
    //=========================================================================
    
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    //=========================================================================
    // AXI Slave Stub (simple response)
    //=========================================================================
    
    assign m_axi_awready = 1'b1;
    assign m_axi_wready  = 1'b1;
    assign m_axi_bresp   = 2'b00;
    assign m_axi_bvalid  = 1'b1;
    assign m_axi_arready = 1'b1;
    assign m_axi_rdata   = 128'hDEADBEEF_CAFEBABE_12345678_9ABCDEF0;
    assign m_axi_rresp   = 2'b00;
    assign m_axi_rlast   = 1'b1;
    assign m_axi_rvalid  = 1'b1;
    
    //=========================================================================
    // Tasks
    //=========================================================================
    
    task automatic axil_write(input logic [31:0] addr, input logic [31:0] data);
        @(posedge clk);
        s_axil_awaddr  <= addr;
        s_axil_awvalid <= 1'b1;
        s_axil_wdata   <= data;
        s_axil_wstrb   <= 4'hF;
        s_axil_wvalid  <= 1'b1;
        s_axil_bready  <= 1'b1;
        @(posedge clk);
        s_axil_awvalid <= 1'b0;
        s_axil_wvalid  <= 1'b0;
        @(posedge clk);
    endtask
    
    task automatic axil_read(input logic [31:0] addr, output logic [31:0] data);
        @(posedge clk);
        s_axil_araddr  <= addr;
        s_axil_arvalid <= 1'b1;
        s_axil_rready  <= 1'b1;
        @(posedge clk);
        s_axil_arvalid <= 1'b0;
        @(posedge clk);
        data = s_axil_rdata;
    endtask
    
    //=========================================================================
    // Test Sequence
    //=========================================================================
    
    logic [31:0] read_data;
    
    initial begin
        $display("===========================================");
        $display("EdgeNPU Testbench");
        $display("===========================================");
        
        // Initialize
        rst_n = 0;
        s_axil_awaddr  = 0;
        s_axil_awvalid = 0;
        s_axil_wdata   = 0;
        s_axil_wstrb   = 0;
        s_axil_wvalid  = 0;
        s_axil_bready  = 0;
        s_axil_araddr  = 0;
        s_axil_arvalid = 0;
        s_axil_rready  = 0;
        
        // Reset
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        $display("[%0t] Reset complete", $time);
        
        //---------------------------------------------------------------------
        // Test 1: Read Version Register
        //---------------------------------------------------------------------
        $display("\n[Test 1] Read Version Register");
        axil_read(32'h010, read_data);
        $display("  Version: 0x%08h", read_data);
        if (read_data == 32'h0001_0000)
            $display("  PASS: Version matches expected v1.0.0");
        else
            $display("  FAIL: Version mismatch");
        
        //---------------------------------------------------------------------
        // Test 2: Read Config Register
        //---------------------------------------------------------------------
        $display("\n[Test 2] Read Config Register");
        axil_read(32'h014, read_data);
        $display("  Config: 0x%08h (PE_ROWS=%0d, PE_COLS=%0d)", 
                 read_data, read_data[31:16], read_data[15:0]);
        
        //---------------------------------------------------------------------
        // Test 3: Write/Read Control Register
        //---------------------------------------------------------------------
        $display("\n[Test 3] Write/Read Control Register");
        axil_write(32'h000, 32'h0000_0001);  // Enable NPU
        axil_read(32'h000, read_data);
        $display("  Control: 0x%08h", read_data);
        if (read_data[0] == 1'b1)
            $display("  PASS: NPU enabled");
        else
            $display("  FAIL: NPU not enabled");
        
        //---------------------------------------------------------------------
        // Test 4: Check Status Register
        //---------------------------------------------------------------------
        $display("\n[Test 4] Check Status Register");
        axil_read(32'h004, read_data);
        $display("  Status: 0x%08h (busy=%b, done=%b)", 
                 read_data, read_data[1], read_data[0]);
        
        //---------------------------------------------------------------------
        // Test 5: Enable Interrupts
        //---------------------------------------------------------------------
        $display("\n[Test 5] Enable Interrupts");
        axil_write(32'h008, 32'h0000_000F);  // Enable all interrupts
        axil_read(32'h008, read_data);
        $display("  IRQ Enable: 0x%08h", read_data);
        
        //---------------------------------------------------------------------
        // Test 6: Start NPU (will go to FETCH state)
        //---------------------------------------------------------------------
        $display("\n[Test 6] Start NPU");
        axil_write(32'h000, 32'h0000_0003);  // Enable + Start
        repeat(10) @(posedge clk);
        axil_read(32'h004, read_data);
        $display("  Status after start: 0x%08h", read_data);
        
        //---------------------------------------------------------------------
        // Wait and finish
        //---------------------------------------------------------------------
        repeat(100) @(posedge clk);
        
        $display("\n===========================================");
        $display("Testbench Complete");
        $display("===========================================");
        $finish;
    end
    
    //=========================================================================
    // Timeout
    //=========================================================================
    
    initial begin
        #100000;
        $display("ERROR: Testbench timeout!");
        $finish;
    end
    
    //=========================================================================
    // Waveform Dump
    //=========================================================================
    
    initial begin
        $dumpfile("npu_tb.vcd");
        $dumpvars(0, npu_tb);
    end

endmodule
