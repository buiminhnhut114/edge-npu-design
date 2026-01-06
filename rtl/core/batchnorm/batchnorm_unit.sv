//=============================================================================
// Batch Normalization Unit (Fused with Scale)
// Implements: y = gamma * (x - mean) / sqrt(var + eps) + beta
// For inference: y = scale * x + bias (pre-computed)
//=============================================================================

module batchnorm_unit
    import npu_pkg::*;
#(
    parameter int DATA_WIDTH    = 8,
    parameter int SCALE_WIDTH   = 16,
    parameter int MAX_CHANNELS  = 256
)(
    input  logic                            clk,
    input  logic                            rst_n,
    
    // Control
    input  logic                            enable,
    input  logic                            load_params,    // Load scale/bias parameters
    input  logic [7:0]                      channel_idx,    // Current channel index
    input  logic [7:0]                      num_channels,   // Total channels
    
    // Parameter loading interface
    input  logic                            param_valid,
    input  logic signed [SCALE_WIDTH-1:0]   scale_in,       // Pre-computed: gamma/sqrt(var+eps)
    input  logic signed [SCALE_WIDTH-1:0]   bias_in,        // Pre-computed: beta - gamma*mean/sqrt(var+eps)
    
    // Data interface
    input  logic                            valid_in,
    input  logic signed [DATA_WIDTH-1:0]    data_in,
    output logic                            valid_out,
    output logic signed [DATA_WIDTH-1:0]    data_out,
    
    // Status
    output logic                            ready,
    output logic                            params_loaded
);

    //=========================================================================
    // Parameter Storage (Scale and Bias per channel)
    //=========================================================================
    
    logic signed [SCALE_WIDTH-1:0] scale_mem [MAX_CHANNELS];
    logic signed [SCALE_WIDTH-1:0] bias_mem  [MAX_CHANNELS];
    
    logic [7:0] param_load_idx;
    logic       params_ready;
    
    // Parameter loading FSM
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            param_load_idx <= '0;
            params_ready   <= 1'b0;
        end else if (load_params) begin
            param_load_idx <= '0;
            params_ready   <= 1'b0;
        end else if (param_valid && !params_ready) begin
            scale_mem[param_load_idx] <= scale_in;
            bias_mem[param_load_idx]  <= bias_in;
            
            if (param_load_idx == num_channels - 1) begin
                params_ready <= 1'b1;
            end else begin
                param_load_idx <= param_load_idx + 1'b1;
            end
        end
    end
    
    assign params_loaded = params_ready;
    
    //=========================================================================
    // Pipeline Stage 1: Read parameters and register input
    //=========================================================================
    
    logic signed [DATA_WIDTH-1:0]   data_p1;
    logic signed [SCALE_WIDTH-1:0]  scale_p1;
    logic signed [SCALE_WIDTH-1:0]  bias_p1;
    logic                           valid_p1;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_p1  <= '0;
            scale_p1 <= '0;
            bias_p1  <= '0;
            valid_p1 <= 1'b0;
        end else if (enable) begin
            data_p1  <= data_in;
            scale_p1 <= scale_mem[channel_idx];
            bias_p1  <= bias_mem[channel_idx];
            valid_p1 <= valid_in;
        end else begin
            valid_p1 <= 1'b0;
        end
    end
    
    //=========================================================================
    // Pipeline Stage 2: Multiply (data * scale)
    //=========================================================================
    
    logic signed [DATA_WIDTH+SCALE_WIDTH-1:0] mult_result;
    logic signed [SCALE_WIDTH-1:0]            bias_p2;
    logic                                     valid_p2;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mult_result <= '0;
            bias_p2     <= '0;
            valid_p2    <= 1'b0;
        end else begin
            mult_result <= data_p1 * scale_p1;
            bias_p2     <= bias_p1;
            valid_p2    <= valid_p1;
        end
    end
    
    //=========================================================================
    // Pipeline Stage 3: Add bias and saturate
    //=========================================================================
    
    logic signed [DATA_WIDTH+SCALE_WIDTH:0] add_result;
    logic signed [DATA_WIDTH-1:0]           saturated_result;
    
    // Add bias (scale mult_result to match bias precision)
    assign add_result = (mult_result >>> (SCALE_WIDTH - DATA_WIDTH)) + 
                        {{(DATA_WIDTH+1){bias_p2[SCALE_WIDTH-1]}}, bias_p2};
    
    // Saturation logic for INT8
    always_comb begin
        if (add_result > $signed({{(SCALE_WIDTH-DATA_WIDTH+2){1'b0}}, {(DATA_WIDTH-1){1'b1}}}))
            saturated_result = {1'b0, {(DATA_WIDTH-1){1'b1}}};  // Max positive
        else if (add_result < $signed({{(SCALE_WIDTH-DATA_WIDTH+1){1'b1}}, 1'b0, {(DATA_WIDTH-1){1'b0}}}))
            saturated_result = {1'b1, {(DATA_WIDTH-1){1'b0}}};  // Max negative
        else
            saturated_result = add_result[DATA_WIDTH-1:0];
    end
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out  <= '0;
            valid_out <= 1'b0;
        end else begin
            data_out  <= saturated_result;
            valid_out <= valid_p2;
        end
    end
    
    //=========================================================================
    // Ready signal
    //=========================================================================
    
    assign ready = params_ready && enable;

endmodule
