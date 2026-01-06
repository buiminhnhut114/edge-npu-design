//=============================================================================
// Depthwise Convolution Unit
// Efficient implementation for MobileNet-style depthwise separable convolutions
//=============================================================================

module depthwise_conv
    import npu_pkg::*;
#(
    parameter int DATA_WIDTH    = 8,
    parameter int KERNEL_MAX    = 7,    // Max kernel size (7x7)
    parameter int CHANNELS      = 16    // Parallel channels
)(
    input  logic                            clk,
    input  logic                            rst_n,
    
    // Control
    input  logic                            start,
    input  logic [2:0]                      kernel_size,    // 1,3,5,7
    input  logic [1:0]                      stride,         // 1,2
    input  logic [2:0]                      padding,
    input  logic [7:0]                      num_channels,
    output logic                            done,
    output logic                            busy,
    
    // Weight interface (one kernel per channel)
    input  logic                            weight_valid,
    input  logic signed [DATA_WIDTH-1:0]    weight_in [KERNEL_MAX*KERNEL_MAX],
    
    // Input data interface
    input  logic                            data_valid,
    input  logic signed [DATA_WIDTH-1:0]    data_in [CHANNELS],
    
    // Output interface
    output logic                            out_valid,
    output logic signed [31:0]              data_out [CHANNELS]
);

    //=========================================================================
    // Weight Storage (per channel)
    //=========================================================================
    
    logic signed [DATA_WIDTH-1:0] weights [CHANNELS][KERNEL_MAX*KERNEL_MAX];
    logic [7:0] weight_load_ch;
    logic       weights_loaded;
    
    // Load weights
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            weight_load_ch <= '0;
            weights_loaded <= 1'b0;
        end else if (start) begin
            weight_load_ch <= '0;
            weights_loaded <= 1'b0;
        end else if (weight_valid && !weights_loaded) begin
            for (int k = 0; k < KERNEL_MAX*KERNEL_MAX; k++) begin
                weights[weight_load_ch][k] <= weight_in[k];
            end
            
            if (weight_load_ch == num_channels - 1)
                weights_loaded <= 1'b1;
            else
                weight_load_ch <= weight_load_ch + 1'b1;
        end
    end
    
    //=========================================================================
    // Line Buffers for Sliding Window
    //=========================================================================
    
    // Line buffer depth based on max image width (assume 256 max)
    localparam int LINE_BUF_DEPTH = 256;
    
    logic signed [DATA_WIDTH-1:0] line_buf [CHANNELS][KERNEL_MAX-1][LINE_BUF_DEPTH];
    logic [7:0] line_buf_ptr;
    
    // Sliding window registers
    logic signed [DATA_WIDTH-1:0] window [CHANNELS][KERNEL_MAX][KERNEL_MAX];
    
    //=========================================================================
    // State Machine
    //=========================================================================
    
    typedef enum logic [2:0] {
        IDLE,
        LOAD_WEIGHTS,
        FILL_BUFFER,
        COMPUTE,
        OUTPUT,
        COMPLETE
    } state_t;
    
    state_t state, next_state;
    
    logic [15:0] pixel_cnt;
    logic [7:0]  row_cnt;
    logic [7:0]  col_cnt;
    logic [3:0]  kernel_cnt;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end
    
    always_comb begin
        next_state = state;
        case (state)
            IDLE:         if (start) next_state = LOAD_WEIGHTS;
            LOAD_WEIGHTS: if (weights_loaded) next_state = FILL_BUFFER;
            FILL_BUFFER:  if (row_cnt >= kernel_size - 1) next_state = COMPUTE;
            COMPUTE:      if (pixel_cnt >= num_channels * 256 * 256) next_state = COMPLETE;
            COMPLETE:     next_state = IDLE;
            default:      next_state = IDLE;
        endcase
    end
    
    //=========================================================================
    // Sliding Window Update
    //=========================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            line_buf_ptr <= '0;
            pixel_cnt    <= '0;
            row_cnt      <= '0;
            col_cnt      <= '0;
        end else begin
            case (state)
                IDLE: begin
                    line_buf_ptr <= '0;
                    pixel_cnt    <= '0;
                    row_cnt      <= '0;
                    col_cnt      <= '0;
                end
                
                FILL_BUFFER, COMPUTE: begin
                    if (data_valid) begin
                        // Update line buffers and sliding window
                        for (int ch = 0; ch < CHANNELS; ch++) begin
                            // Shift window horizontally
                            for (int r = 0; r < KERNEL_MAX; r++) begin
                                for (int c = 0; c < KERNEL_MAX-1; c++) begin
                                    window[ch][r][c] <= window[ch][r][c+1];
                                end
                            end
                            
                            // Load new column from line buffers and input
                            for (int r = 0; r < KERNEL_MAX-1; r++) begin
                                window[ch][r][KERNEL_MAX-1] <= line_buf[ch][r][line_buf_ptr];
                            end
                            window[ch][KERNEL_MAX-1][KERNEL_MAX-1] <= data_in[ch];
                            
                            // Update line buffers
                            for (int r = 0; r < KERNEL_MAX-2; r++) begin
                                line_buf[ch][r][line_buf_ptr] <= line_buf[ch][r+1][line_buf_ptr];
                            end
                            line_buf[ch][KERNEL_MAX-2][line_buf_ptr] <= data_in[ch];
                        end
                        
                        // Update counters
                        line_buf_ptr <= (line_buf_ptr == LINE_BUF_DEPTH-1) ? '0 : line_buf_ptr + 1'b1;
                        col_cnt <= col_cnt + 1'b1;
                        
                        if (col_cnt == LINE_BUF_DEPTH-1) begin
                            col_cnt <= '0;
                            row_cnt <= row_cnt + 1'b1;
                        end
                        
                        pixel_cnt <= pixel_cnt + 1'b1;
                    end
                end
            endcase
        end
    end
    
    //=========================================================================
    // Depthwise Convolution Computation
    //=========================================================================
    
    logic signed [31:0] conv_result [CHANNELS];
    logic               conv_valid;
    
    // Compute convolution for each channel independently
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int ch = 0; ch < CHANNELS; ch++) begin
                conv_result[ch] <= '0;
            end
            conv_valid <= 1'b0;
        end else if (state == COMPUTE && data_valid) begin
            for (int ch = 0; ch < CHANNELS; ch++) begin
                logic signed [31:0] sum;
                sum = '0;
                
                // Multiply-accumulate over kernel window
                for (int kr = 0; kr < KERNEL_MAX; kr++) begin
                    for (int kc = 0; kc < KERNEL_MAX; kc++) begin
                        if (kr < kernel_size && kc < kernel_size) begin
                            sum = sum + window[ch][kr][kc] * weights[ch][kr*KERNEL_MAX+kc];
                        end
                    end
                end
                
                conv_result[ch] <= sum;
            end
            
            // Output valid based on stride
            conv_valid <= (col_cnt[stride-1:0] == '0) && (row_cnt[stride-1:0] == '0);
        end else begin
            conv_valid <= 1'b0;
        end
    end
    
    //=========================================================================
    // Output
    //=========================================================================
    
    assign data_out  = conv_result;
    assign out_valid = conv_valid;
    assign busy      = (state != IDLE);
    assign done      = (state == COMPLETE);

endmodule
