//=============================================================================
// Dequantizer
// Convert INT8 quantized values back to higher precision
//=============================================================================

module dequantizer
    import npu_pkg::*;
#(
    parameter int INPUT_WIDTH   = 8,    // Quantized input (INT8)
    parameter int OUTPUT_WIDTH  = 32,   // Dequantized output
    parameter int SCALE_WIDTH   = 16,   // Scale factor precision
    parameter int NUM_CHANNELS  = 16    // Number of channels
)(
    input  logic                            clk,
    input  logic                            rst_n,
    
    // Control
    input  logic                            enable,
    input  logic                            per_channel,
    
    // Dequantization parameters
    input  logic signed [SCALE_WIDTH-1:0]   scale,
    input  logic signed [INPUT_WIDTH-1:0]   zero_point,
    input  logic signed [SCALE_WIDTH-1:0]   ch_scales [NUM_CHANNELS],
    input  logic signed [INPUT_WIDTH-1:0]   ch_zero_points [NUM_CHANNELS],
    
    // Data input
    input  logic                            valid_in,
    input  logic signed [INPUT_WIDTH-1:0]   data_in,
    input  logic [$clog2(NUM_CHANNELS)-1:0] channel_id,
    
    // Data output
    output logic                            valid_out,
    output logic signed [OUTPUT_WIDTH-1:0]  data_out
);

    //=========================================================================
    // Internal Signals
    //=========================================================================
    
    logic signed [SCALE_WIDTH-1:0]  active_scale;
    logic signed [INPUT_WIDTH-1:0]  active_zp;
    
    logic [1:0] valid_pipe;
    logic signed [OUTPUT_WIDTH-1:0] sub_zp;
    logic signed [OUTPUT_WIDTH-1:0] result;
    
    //=========================================================================
    // Scale and Zero-Point Selection
    //=========================================================================
    
    always_comb begin
        if (per_channel) begin
            active_scale = ch_scales[channel_id];
            active_zp    = ch_zero_points[channel_id];
        end else begin
            active_scale = scale;
            active_zp    = zero_point;
        end
    end
    
    //=========================================================================
    // Stage 1: Subtract zero-point
    //=========================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sub_zp       <= '0;
            valid_pipe[0] <= 1'b0;
        end else if (enable) begin
            sub_zp       <= $signed({{(OUTPUT_WIDTH-INPUT_WIDTH){data_in[INPUT_WIDTH-1]}}, data_in}) - 
                            $signed({{(OUTPUT_WIDTH-INPUT_WIDTH){active_zp[INPUT_WIDTH-1]}}, active_zp});
            valid_pipe[0] <= valid_in;
        end else begin
            valid_pipe[0] <= 1'b0;
        end
    end
    
    //=========================================================================
    // Stage 2: Multiply by scale
    //=========================================================================
    
    logic signed [OUTPUT_WIDTH+SCALE_WIDTH-1:0] mult_result;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result        <= '0;
            valid_pipe[1] <= 1'b0;
        end else begin
            mult_result   = sub_zp * active_scale;
            result        <= mult_result[OUTPUT_WIDTH-1:0];  // Take lower bits
            valid_pipe[1] <= valid_pipe[0];
        end
    end
    
    //=========================================================================
    // Output
    //=========================================================================
    
    assign data_out  = result;
    assign valid_out = valid_pipe[1];

endmodule
