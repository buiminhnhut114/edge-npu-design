//=============================================================================
// Quantizer
// INT8 quantization unit with per-channel scale and zero-point
//=============================================================================

module quantizer
    import npu_pkg::*;
#(
    parameter int INPUT_WIDTH   = 32,   // Input precision (e.g., FP32 or higher int)
    parameter int OUTPUT_WIDTH  = 8,    // Quantized output (INT8)
    parameter int SCALE_WIDTH   = 16,   // Scale factor precision
    parameter int NUM_CHANNELS  = 16    // Number of channels for per-channel quant
)(
    input  logic                            clk,
    input  logic                            rst_n,
    
    // Control
    input  logic                            enable,
    input  logic                            per_channel,    // 0=scalar, 1=per-channel
    
    // Quantization parameters
    input  logic signed [SCALE_WIDTH-1:0]   scale,          // Global scale
    input  logic signed [OUTPUT_WIDTH-1:0]  zero_point,     // Global zero point
    input  logic signed [SCALE_WIDTH-1:0]   ch_scales [NUM_CHANNELS],
    input  logic signed [OUTPUT_WIDTH-1:0]  ch_zero_points [NUM_CHANNELS],
    
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
    
    logic signed [SCALE_WIDTH-1:0]   active_scale;
    logic signed [OUTPUT_WIDTH-1:0]  active_zp;
    
    // Pipeline registers
    logic [2:0] valid_pipe;
    logic signed [INPUT_WIDTH+SCALE_WIDTH-1:0] scaled_value;
    logic signed [INPUT_WIDTH+SCALE_WIDTH-1:0] shifted_value;
    logic signed [OUTPUT_WIDTH-1:0] quantized_value;
    
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
    // Stage 1: Multiply by scale
    //=========================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scaled_value <= '0;
            valid_pipe[0] <= 1'b0;
        end else if (enable) begin
            scaled_value <= data_in * active_scale;
            valid_pipe[0] <= valid_in;
        end else begin
            valid_pipe[0] <= 1'b0;
        end
    end
    
    //=========================================================================
    // Stage 2: Shift (divide by scale factor power of 2)
    //=========================================================================
    
    // Assuming scale is in Q8.8 format, shift by 8
    localparam SHIFT_AMOUNT = 8;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shifted_value <= '0;
            valid_pipe[1] <= 1'b0;
        end else begin
            // Arithmetic right shift with rounding
            shifted_value <= (scaled_value + (1 << (SHIFT_AMOUNT-1))) >>> SHIFT_AMOUNT;
            valid_pipe[1] <= valid_pipe[0];
        end
    end
    
    //=========================================================================
    // Stage 3: Add zero-point and saturate
    //=========================================================================
    
    logic signed [INPUT_WIDTH+SCALE_WIDTH-1:0] with_zp;
    
    always_comb begin
        with_zp = shifted_value + active_zp;
    end
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            quantized_value <= '0;
            valid_pipe[2]   <= 1'b0;
        end else begin
            valid_pipe[2] <= valid_pipe[1];
            
            // Saturation
            if (with_zp > $signed({1'b0, {(OUTPUT_WIDTH-1){1'b1}}})) begin
                quantized_value <= {1'b0, {(OUTPUT_WIDTH-1){1'b1}}};  // Max positive
            end else if (with_zp < $signed({1'b1, {(OUTPUT_WIDTH-1){1'b0}}})) begin
                quantized_value <= {1'b1, {(OUTPUT_WIDTH-1){1'b0}}};  // Min negative
            end else begin
                quantized_value <= with_zp[OUTPUT_WIDTH-1:0];
            end
        end
    end
    
    //=========================================================================
    // Output
    //=========================================================================
    
    assign data_out  = quantized_value;
    assign valid_out = valid_pipe[2];

endmodule
