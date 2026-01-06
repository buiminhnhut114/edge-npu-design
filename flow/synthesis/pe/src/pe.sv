//=============================================================================
// Processing Element (PE)
// Basic compute unit with MAC operation for systolic array
//=============================================================================

module pe
#(
    parameter int DATA_WIDTH   = 8,
    parameter int WEIGHT_WIDTH = 8,
    parameter int ACC_WIDTH    = 32
)(
    input  logic                            clk,
    input  logic                            rst_n,
    
    // Control
    input  logic                            enable,
    input  logic                            clear_acc,
    input  logic                            load_weight,
    
    // Data flow (systolic)
    input  wire signed [DATA_WIDTH-1:0]    data_in,      // From left/top
    input  wire signed [WEIGHT_WIDTH-1:0]  weight_in,    // Weight to load
    output wire signed [DATA_WIDTH-1:0]    data_out,     // To right/bottom
    
    // Accumulator output
    output wire signed [ACC_WIDTH-1:0]     acc_out,
    output logic                            acc_valid
);

    //=========================================================================
    // Internal Registers
    //=========================================================================
    
    wire signed [WEIGHT_WIDTH-1:0]  weight_reg;
    wire signed [DATA_WIDTH-1:0]    data_reg;
    wire signed [ACC_WIDTH-1:0]     acc_reg;
    logic                            valid_reg;
    
    // MAC result
    wire signed [DATA_WIDTH+WEIGHT_WIDTH-1:0] mult_result;
    wire signed [ACC_WIDTH-1:0]               add_result;
    
    //=========================================================================
    // MAC Operation
    //=========================================================================
    
    // Multiply
    assign mult_result = data_in * weight_reg;
    
    // Accumulate
    assign add_result = acc_reg + {{(ACC_WIDTH-DATA_WIDTH-WEIGHT_WIDTH){mult_result[DATA_WIDTH+WEIGHT_WIDTH-1]}}, mult_result};
    
    //=========================================================================
    // Sequential Logic
    //=========================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            weight_reg <= '0;
            data_reg   <= '0;
            acc_reg    <= '0;
            valid_reg  <= 1'b0;
        end else begin
            // Load weight
            if (load_weight) begin
                weight_reg <= weight_in;
            end
            
            // Clear accumulator
            if (clear_acc) begin
                acc_reg   <= '0;
                valid_reg <= 1'b0;
            end else if (enable) begin
                // Systolic data flow - pass data to next PE
                data_reg <= data_in;
                
                // MAC operation
                acc_reg   <= add_result;
                valid_reg <= 1'b1;
            end
        end
    end
    
    //=========================================================================
    // Outputs
    //=========================================================================
    
    assign data_out  = data_reg;
    assign acc_out   = acc_reg;
    assign acc_valid = valid_reg;

endmodule
