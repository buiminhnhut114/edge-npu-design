//=============================================================================
// Max Pooling Module
// Supports 2x2 and 3x3 kernel sizes
//=============================================================================

`include "../top/npu_pkg.sv"

module max_pool
    import npu_pkg::*;
#(
    parameter int DATA_WIDTH  = 8,
    parameter int MAX_KERNEL  = 3
)(
    input  logic                            clk,
    input  logic                            rst_n,
    
    // Control
    input  logic                            enable,
    input  logic [1:0]                      kernel_size,    // 2 or 3
    input  logic                            start,
    
    // Input stream
    input  logic signed [DATA_WIDTH-1:0]    data_in,
    input  logic                            valid_in,
    
    // Output
    output logic signed [DATA_WIDTH-1:0]    data_out,
    output logic                            valid_out
);

    //=========================================================================
    // Internal Signals
    //=========================================================================
    
    logic signed [DATA_WIDTH-1:0] window [MAX_KERNEL][MAX_KERNEL];
    logic signed [DATA_WIDTH-1:0] max_val;
    logic [3:0] row_cnt, col_cnt;
    
    //=========================================================================
    // Window Buffer
    //=========================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < MAX_KERNEL; i++) begin
                for (int j = 0; j < MAX_KERNEL; j++) begin
                    window[i][j] <= {DATA_WIDTH{1'b1}}; // Min value
                end
            end
            row_cnt <= '0;
            col_cnt <= '0;
        end else if (start) begin
            for (int i = 0; i < MAX_KERNEL; i++) begin
                for (int j = 0; j < MAX_KERNEL; j++) begin
                    window[i][j] <= {DATA_WIDTH{1'b1}};
                end
            end
            row_cnt <= '0;
            col_cnt <= '0;
        end else if (valid_in && enable) begin
            window[row_cnt][col_cnt] <= data_in;
            
            if (col_cnt == kernel_size - 1) begin
                col_cnt <= '0;
                if (row_cnt == kernel_size - 1) begin
                    row_cnt <= '0;
                end else begin
                    row_cnt <= row_cnt + 1;
                end
            end else begin
                col_cnt <= col_cnt + 1;
            end
        end
    end
    
    //=========================================================================
    // Max Computation
    //=========================================================================
    
    always_comb begin
        max_val = window[0][0];
        
        for (int i = 0; i < MAX_KERNEL; i++) begin
            for (int j = 0; j < MAX_KERNEL; j++) begin
                if (i < kernel_size && j < kernel_size) begin
                    if (window[i][j] > max_val) begin
                        max_val = window[i][j];
                    end
                end
            end
        end
    end
    
    //=========================================================================
    // Output
    //=========================================================================
    
    logic window_complete;
    assign window_complete = (row_cnt == kernel_size - 1) && 
                             (col_cnt == kernel_size - 1) && 
                             valid_in && enable;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out  <= '0;
            valid_out <= 1'b0;
        end else begin
            valid_out <= window_complete;
            if (window_complete) begin
                data_out <= max_val;
            end
        end
    end

endmodule
