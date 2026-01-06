//=============================================================================
// PE Array (Systolic Array)
// 16x16 Processing Element array for matrix multiplication
//=============================================================================

module pe_array
    import npu_pkg::*;
#(
    parameter int ROWS         = 16,
    parameter int COLS         = 16,
    parameter int DATA_WIDTH   = 8,
    parameter int WEIGHT_WIDTH = 8,
    parameter int ACC_WIDTH    = 32
)(
    input  logic                                clk,
    input  logic                                rst_n,
    
    // Control
    input  logic                                enable,
    input  logic                                clear_acc,
    input  logic [ROWS-1:0]                     load_weight,
    
    // Data inputs
    input  logic signed [DATA_WIDTH-1:0]        data_in [ROWS],
    input  logic signed [WEIGHT_WIDTH-1:0]      weight_in [COLS],
    
    // Outputs
    output logic signed [ACC_WIDTH-1:0]         acc_out [ROWS][COLS],
    output logic                                acc_valid [ROWS][COLS]
);

    //=========================================================================
    // Internal Signals
    //=========================================================================
    
    // Horizontal data flow (left to right)
    logic signed [DATA_WIDTH-1:0] data_h [ROWS][COLS+1];
    
    // Vertical weight flow (top to bottom) - for weight loading
    logic signed [WEIGHT_WIDTH-1:0] weight_v [ROWS+1][COLS];
    
    //=========================================================================
    // Input Connections
    //=========================================================================
    
    // Connect input data to leftmost column
    generate
        for (genvar r = 0; r < ROWS; r++) begin : gen_data_in
            assign data_h[r][0] = data_in[r];
        end
    endgenerate
    
    // Connect weight inputs to top row
    generate
        for (genvar c = 0; c < COLS; c++) begin : gen_weight_in
            assign weight_v[0][c] = weight_in[c];
        end
    endgenerate
    
    //=========================================================================
    // PE Array Instantiation
    //=========================================================================
    
    generate
        for (genvar r = 0; r < ROWS; r++) begin : gen_row
            for (genvar c = 0; c < COLS; c++) begin : gen_col
                pe #(
                    .DATA_WIDTH   (DATA_WIDTH),
                    .WEIGHT_WIDTH (WEIGHT_WIDTH),
                    .ACC_WIDTH    (ACC_WIDTH)
                ) u_pe (
                    .clk         (clk),
                    .rst_n       (rst_n),
                    .enable      (enable),
                    .clear_acc   (clear_acc),
                    .load_weight (load_weight[r]),
                    .data_in     (data_h[r][c]),
                    .weight_in   (weight_v[r][c]),
                    .data_out    (data_h[r][c+1]),
                    .acc_out     (acc_out[r][c]),
                    .acc_valid   (acc_valid[r][c])
                );
                
                // Pass weight down for loading
                assign weight_v[r+1][c] = weight_v[r][c];
            end
        end
    endgenerate

endmodule
