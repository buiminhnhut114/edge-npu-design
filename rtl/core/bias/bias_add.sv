//=============================================================================
// Bias Addition Unit
// Adds bias to convolution/FC output
//=============================================================================

module bias_add
    import npu_pkg::*;
#(
    parameter int DATA_WIDTH    = 32,   // Input accumulator width
    parameter int BIAS_WIDTH    = 32,   // Bias width
    parameter int OUT_WIDTH     = 8,    // Output width (after quantization)
    parameter int MAX_CHANNELS  = 512
)(
    input  logic                            clk,
    input  logic                            rst_n,
    
    // Control
    input  logic                            enable,
    input  logic                            load_bias,
    input  logic [8:0]                      num_channels,
    
    // Bias loading interface
    input  logic                            bias_valid,
    input  logic signed [BIAS_WIDTH-1:0]    bias_in,
    
    // Data interface
    input  logic                            valid_in,
    input  logic [8:0]                      channel_idx,
    input  logic signed [DATA_WIDTH-1:0]    data_in,
    
    output logic                            valid_out,
    output logic signed [DATA_WIDTH-1:0]    data_out,
    
    // Status
    output logic                            bias_loaded
);

    //=========================================================================
    // Bias Storage
    //=========================================================================
    
    logic signed [BIAS_WIDTH-1:0] bias_mem [MAX_CHANNELS];
    logic [8:0] bias_load_idx;
    logic       bias_ready;
    
    // Bias loading
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bias_load_idx <= '0;
            bias_ready    <= 1'b0;
        end else if (load_bias) begin
            bias_load_idx <= '0;
            bias_ready    <= 1'b0;
        end else if (bias_valid && !bias_ready) begin
            bias_mem[bias_load_idx] <= bias_in;
            
            if (bias_load_idx == num_channels - 1)
                bias_ready <= 1'b1;
            else
                bias_load_idx <= bias_load_idx + 1'b1;
        end
    end
    
    assign bias_loaded = bias_ready;
    
    //=========================================================================
    // Bias Addition Pipeline
    //=========================================================================
    
    // Stage 1: Read bias
    logic signed [BIAS_WIDTH-1:0]   bias_val;
    logic signed [DATA_WIDTH-1:0]   data_p1;
    logic                           valid_p1;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bias_val <= '0;
            data_p1  <= '0;
            valid_p1 <= 1'b0;
        end else if (enable) begin
            bias_val <= bias_mem[channel_idx];
            data_p1  <= data_in;
            valid_p1 <= valid_in;
        end else begin
            valid_p1 <= 1'b0;
        end
    end
    
    // Stage 2: Add bias
    logic signed [DATA_WIDTH:0] add_result;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out  <= '0;
            valid_out <= 1'b0;
        end else begin
            add_result = data_p1 + bias_val;
            
            // Saturation
            if (add_result > $signed({1'b0, {(DATA_WIDTH-1){1'b1}}}))
                data_out <= {1'b0, {(DATA_WIDTH-1){1'b1}}};
            else if (add_result < $signed({1'b1, {(DATA_WIDTH-1){1'b0}}}))
                data_out <= {1'b1, {(DATA_WIDTH-1){1'b0}}};
            else
                data_out <= add_result[DATA_WIDTH-1:0];
                
            valid_out <= valid_p1;
        end
    end

endmodule
