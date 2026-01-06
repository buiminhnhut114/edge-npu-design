//=============================================================================
// PE Array Testbench
// Verify systolic array matrix multiplication
//=============================================================================

`timescale 1ns/1ps

module pe_array_tb;

    //=========================================================================
    // Parameters
    //=========================================================================
    
    parameter int CLK_PERIOD = 10;
    parameter int ROWS = 4;  // Smaller for testing
    parameter int COLS = 4;
    parameter int DATA_WIDTH = 8;
    parameter int ACC_WIDTH = 32;
    
    //=========================================================================
    // Signals
    //=========================================================================
    
    logic clk;
    logic rst_n;
    logic enable;
    logic clear_acc;
    logic [ROWS-1:0] load_weight;
    
    logic signed [DATA_WIDTH-1:0] data_in [ROWS];
    logic signed [DATA_WIDTH-1:0] weight_in [COLS];
    logic signed [ACC_WIDTH-1:0]  acc_out [ROWS][COLS];
    logic                         acc_valid [ROWS][COLS];
    
    //=========================================================================
    // DUT
    //=========================================================================
    
    pe_array #(
        .ROWS         (ROWS),
        .COLS         (COLS),
        .DATA_WIDTH   (DATA_WIDTH),
        .WEIGHT_WIDTH (DATA_WIDTH),
        .ACC_WIDTH    (ACC_WIDTH)
    ) dut (
        .clk         (clk),
        .rst_n       (rst_n),
        .enable      (enable),
        .clear_acc   (clear_acc),
        .load_weight (load_weight),
        .data_in     (data_in),
        .weight_in   (weight_in),
        .acc_out     (acc_out),
        .acc_valid   (acc_valid)
    );
    
    //=========================================================================
    // Clock Generation
    //=========================================================================
    
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    //=========================================================================
    // Test Data
    //=========================================================================
    
    // Test matrices (4x4)
    // A = [[1,2,3,4], [5,6,7,8], [9,10,11,12], [13,14,15,16]]
    // W = [[1,0,0,0], [0,1,0,0], [0,0,1,0], [0,0,0,1]] (identity)
    // Result should be A
    
    logic signed [DATA_WIDTH-1:0] matrix_a [ROWS][COLS];
    logic signed [DATA_WIDTH-1:0] matrix_w [ROWS][COLS];
    logic signed [ACC_WIDTH-1:0]  expected [ROWS][COLS];
    
    initial begin
        // Initialize test matrices
        for (int i = 0; i < ROWS; i++) begin
            for (int j = 0; j < COLS; j++) begin
                matrix_a[i][j] = i * COLS + j + 1;
                matrix_w[i][j] = (i == j) ? 8'sd1 : 8'sd0;
            end
        end
        
        // Expected result (A * I = A)
        for (int i = 0; i < ROWS; i++) begin
            for (int j = 0; j < COLS; j++) begin
                expected[i][j] = 0;
                for (int k = 0; k < COLS; k++) begin
                    expected[i][j] += matrix_a[i][k] * matrix_w[k][j];
                end
            end
        end
    end
    
    //=========================================================================
    // Test Sequence
    //=========================================================================
    
    int errors;
    
    initial begin
        $display("===========================================");
        $display("PE Array Testbench");
        $display("===========================================");
        
        // Initialize
        rst_n = 0;
        enable = 0;
        clear_acc = 0;
        load_weight = 0;
        for (int i = 0; i < ROWS; i++) data_in[i] = 0;
        for (int i = 0; i < COLS; i++) weight_in[i] = 0;
        errors = 0;
        
        // Reset
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);
        
        $display("[%0t] Reset complete", $time);
        
        //---------------------------------------------------------------------
        // Load Weights (row by row)
        //---------------------------------------------------------------------
        $display("\n[Phase 1] Loading weights...");
        
        for (int row = 0; row < ROWS; row++) begin
            @(posedge clk);
            load_weight = (1 << row);
            for (int col = 0; col < COLS; col++) begin
                weight_in[col] = matrix_w[row][col];
            end
            $display("  Loading row %0d: [%0d, %0d, %0d, %0d]", 
                     row, weight_in[0], weight_in[1], weight_in[2], weight_in[3]);
        end
        
        @(posedge clk);
        load_weight = 0;
        
        //---------------------------------------------------------------------
        // Clear Accumulator
        //---------------------------------------------------------------------
        $display("\n[Phase 2] Clearing accumulator...");
        @(posedge clk);
        clear_acc = 1;
        @(posedge clk);
        clear_acc = 0;
        
        //---------------------------------------------------------------------
        // Feed Data (systolic flow)
        //---------------------------------------------------------------------
        $display("\n[Phase 3] Computing matrix multiplication...");
        
        // For systolic array, data needs to be skewed
        // Row 0 starts at cycle 0, row 1 at cycle 1, etc.
        for (int cycle = 0; cycle < ROWS + COLS; cycle++) begin
            @(posedge clk);
            enable = 1;
            
            for (int row = 0; row < ROWS; row++) begin
                int col_idx = cycle - row;
                if (col_idx >= 0 && col_idx < COLS)
                    data_in[row] = matrix_a[row][col_idx];
                else
                    data_in[row] = 0;
            end
            
            $display("  Cycle %0d: data_in = [%0d, %0d, %0d, %0d]",
                     cycle, data_in[0], data_in[1], data_in[2], data_in[3]);
        end
        
        @(posedge clk);
        enable = 0;
        
        //---------------------------------------------------------------------
        // Wait for results
        //---------------------------------------------------------------------
        repeat(5) @(posedge clk);
        
        //---------------------------------------------------------------------
        // Check Results
        //---------------------------------------------------------------------
        $display("\n[Phase 4] Checking results...");
        
        for (int i = 0; i < ROWS; i++) begin
            for (int j = 0; j < COLS; j++) begin
                $display("  acc_out[%0d][%0d] = %0d (expected %0d) %s",
                         i, j, acc_out[i][j], expected[i][j],
                         (acc_out[i][j] == expected[i][j]) ? "PASS" : "FAIL");
                if (acc_out[i][j] != expected[i][j])
                    errors++;
            end
        end
        
        //---------------------------------------------------------------------
        // Summary
        //---------------------------------------------------------------------
        $display("\n===========================================");
        if (errors == 0)
            $display("TEST PASSED!");
        else
            $display("TEST FAILED: %0d errors", errors);
        $display("===========================================");
        
        $finish;
    end
    
    //=========================================================================
    // Timeout
    //=========================================================================
    
    initial begin
        #10000;
        $display("ERROR: Testbench timeout!");
        $finish;
    end

endmodule
