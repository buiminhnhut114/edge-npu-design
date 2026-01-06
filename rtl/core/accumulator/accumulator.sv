//=============================================================================
// Accumulator Unit
// Collects and processes outputs from PE array
//=============================================================================

module accumulator
    import npu_pkg::*;
#(
    parameter int DATA_WIDTH = 8,
    parameter int ACC_WIDTH  = 32,
    parameter int NUM_INPUTS = 16
)(
    input  logic                            clk,
    input  logic                            rst_n,
    
    // Control
    input  logic                            enable,
    input  logic                            clear,
    input  logic                            output_enable,
    
    // Quantization control
    input  logic [4:0]                      shift_amount,  // Right shift for quantization
    input  logic                            saturate_en,
    
    // Data inputs from PE array
    input  logic signed [ACC_WIDTH-1:0]     acc_in [NUM_INPUTS],
    input  logic                            valid_in [NUM_INPUTS],
    
    // Bias addition
    input  logic signed [ACC_WIDTH-1:0]     bias_in,
    input  logic                            bias_valid,
    
    // Output
    output logic signed [DATA_WIDTH-1:0]    data_out [NUM_INPUTS],
    output logic                            valid_out
);

    //=========================================================================
    // Internal Signals
    //=========================================================================
    
    logic signed [ACC_WIDTH-1:0]   acc_reg [NUM_INPUTS];
    logic signed [ACC_WIDTH-1:0]   biased [NUM_INPUTS];
    logic signed [ACC_WIDTH-1:0]   shifted [NUM_INPUTS];
    logic signed [DATA_WIDTH-1:0]  saturated [NUM_INPUTS];
    logic                          all_valid;
    
    // Saturation bounds
    localparam logic signed [ACC_WIDTH-1:0] MAX_VAL = {{(ACC_WIDTH-DATA_WIDTH){1'b0}}, {DATA_WIDTH{1'b1}}} >> 1;
    localparam logic signed [ACC_WIDTH-1:0] MIN_VAL = -MAX_VAL - 1;
    
    //=========================================================================
    // Check all inputs valid
    //=========================================================================
    
    always_comb begin
        all_valid = 1'b1;
        for (int i = 0; i < NUM_INPUTS; i++) begin
            all_valid = all_valid & valid_in[i];
        end
    end
    
    //=========================================================================
    // Accumulator Registers
    //=========================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < NUM_INPUTS; i++)
                acc_reg[i] <= '0;
        end else if (clear) begin
            for (int i = 0; i < NUM_INPUTS; i++)
                acc_reg[i] <= '0;
        end else if (enable && all_valid) begin
            for (int i = 0; i < NUM_INPUTS; i++)
                acc_reg[i] <= acc_in[i];
        end
    end
    
    //=========================================================================
    // Bias Addition
    //=========================================================================
    
    always_comb begin
        for (int i = 0; i < NUM_INPUTS; i++) begin
            if (bias_valid)
                biased[i] = acc_reg[i] + bias_in;
            else
                biased[i] = acc_reg[i];
        end
    end
    
    //=========================================================================
    // Quantization (Right Shift)
    //=========================================================================
    
    always_comb begin
        for (int i = 0; i < NUM_INPUTS; i++) begin
            shifted[i] = biased[i] >>> shift_amount;
        end
    end
    
    //=========================================================================
    // Saturation
    //=========================================================================
    
    always_comb begin
        for (int i = 0; i < NUM_INPUTS; i++) begin
            if (saturate_en) begin
                if (shifted[i] > MAX_VAL)
                    saturated[i] = MAX_VAL[DATA_WIDTH-1:0];
                else if (shifted[i] < MIN_VAL)
                    saturated[i] = MIN_VAL[DATA_WIDTH-1:0];
                else
                    saturated[i] = shifted[i][DATA_WIDTH-1:0];
            end else begin
                saturated[i] = shifted[i][DATA_WIDTH-1:0];
            end
        end
    end
    
    //=========================================================================
    // Output Register
    //=========================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < NUM_INPUTS; i++)
                data_out[i] <= '0;
            valid_out <= 1'b0;
        end else if (output_enable) begin
            for (int i = 0; i < NUM_INPUTS; i++)
                data_out[i] <= saturated[i];
            valid_out <= 1'b1;
        end else begin
            valid_out <= 1'b0;
        end
    end

endmodule
