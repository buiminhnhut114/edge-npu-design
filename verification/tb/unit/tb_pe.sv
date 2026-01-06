//=============================================================================
// PE Testbench
// Unit test for Processing Element
//=============================================================================

`timescale 1ns/1ps

module tb_pe;

    //=========================================================================
    // Parameters
    //=========================================================================
    
    parameter int DATA_WIDTH   = 8;
    parameter int WEIGHT_WIDTH = 8;
    parameter int ACC_WIDTH    = 32;
    parameter int CLK_PERIOD   = 10;
    
    //=========================================================================
    // Signals
    //=========================================================================
    
    logic                           clk;
    logic                           rst_n;
    logic                           enable;
    logic                           clear_acc;
    logic                           load_weight;
    logic signed [DATA_WIDTH-1:0]   data_in;
    logic signed [WEIGHT_WIDTH-1:0] weight_in;
    logic signed [DATA_WIDTH-1:0]   data_out;
    logic signed [WEIGHT_WIDTH-1:0] weight_out;
    logic signed [ACC_WIDTH-1:0]    acc_out;
    logic                           acc_valid;
    
    //=========================================================================
    // DUT
    //=========================================================================
    
    pe #(
        .DATA_WIDTH   (DATA_WIDTH),
        .WEIGHT_WIDTH (WEIGHT_WIDTH),
        .ACC_WIDTH    (ACC_WIDTH)
    ) dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .enable       (enable),
        .clear_acc    (clear_acc),
        .load_weight  (load_weight),
        .data_in      (data_in),
        .weight_in    (weight_in),
        .data_out     (data_out),
        .weight_out   (weight_out),
        .acc_out      (acc_out),
        .acc_valid    (acc_valid)
    );
    
    //=========================================================================
    // Clock Generation
    //=========================================================================
    
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    //=========================================================================
    // Test Stimulus
    //=========================================================================
    
    initial begin
        // Initialize
        rst_n       = 0;
        enable      = 0;
        clear_acc   = 0;
        load_weight = 0;
        data_in     = 0;
        weight_in   = 0;
        
        // Reset
        #(CLK_PERIOD * 5);
        rst_n = 1;
        #(CLK_PERIOD * 2);
        
        // Test 1: Load weight
        $display("Test 1: Load weight = 5");
        weight_in = 8'sd5;
        load_weight = 1;
        #CLK_PERIOD;
        load_weight = 0;
        
        // Test 2: MAC operation
        $display("Test 2: MAC operations");
        clear_acc = 1;
        #CLK_PERIOD;
        clear_acc = 0;
        
        // data_in = 3, weight = 5 => acc = 15
        data_in = 8'sd3;
        enable = 1;
        #CLK_PERIOD;
        $display("  3 * 5 = 15, acc_out = %0d", acc_out);
        
        // data_in = 4, weight = 5 => acc = 15 + 20 = 35
        data_in = 8'sd4;
        #CLK_PERIOD;
        $display("  4 * 5 = 20, acc_out = %0d (expected 35)", acc_out);
        
        // data_in = -2, weight = 5 => acc = 35 - 10 = 25
        data_in = -8'sd2;
        #CLK_PERIOD;
        $display("  -2 * 5 = -10, acc_out = %0d (expected 25)", acc_out);
        
        enable = 0;
        
        // Test 3: Clear accumulator
        $display("Test 3: Clear accumulator");
        clear_acc = 1;
        #CLK_PERIOD;
        clear_acc = 0;
        $display("  After clear, acc_out = %0d (expected 0)", acc_out);
        
        // Test 4: Negative weight
        $display("Test 4: Negative weight = -3");
        weight_in = -8'sd3;
        load_weight = 1;
        #CLK_PERIOD;
        load_weight = 0;
        
        data_in = 8'sd7;
        enable = 1;
        #CLK_PERIOD;
        $display("  7 * (-3) = -21, acc_out = %0d", acc_out);
        
        enable = 0;
        
        // End simulation
        #(CLK_PERIOD * 10);
        $display("\n========================================");
        $display("All tests completed!");
        $display("========================================\n");
        $finish;
    end
    
    //=========================================================================
    // VCD Dump
    //=========================================================================
    
    initial begin
        $dumpfile("tb_pe.vcd");
        $dumpvars(0, tb_pe);
    end

endmodule
