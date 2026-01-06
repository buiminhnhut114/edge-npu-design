//=============================================================================
// Softmax Unit
// Implements softmax using LUT-based exponential approximation
// softmax(x_i) = exp(x_i) / sum(exp(x_j))
//=============================================================================

module softmax_unit
    import npu_pkg::*;
#(
    parameter int DATA_WIDTH  = 8,
    parameter int OUT_WIDTH   = 8,
    parameter int MAX_CLASSES = 1024
)(
    input  logic                        clk,
    input  logic                        rst_n,
    
    // Control
    input  logic                        start,
    input  logic [9:0]                  num_classes,
    output logic                        done,
    output logic                        busy,
    
    // Input interface
    input  logic                        valid_in,
    input  logic signed [DATA_WIDTH-1:0] data_in,
    
    // Output interface  
    output logic                        valid_out,
    output logic [OUT_WIDTH-1:0]        data_out    // Q0.8 format (0-255 = 0.0-1.0)
);

    //=========================================================================
    // State Machine
    //=========================================================================
    
    typedef enum logic [2:0] {
        IDLE,
        FIND_MAX,
        CALC_EXP,
        CALC_SUM,
        NORMALIZE,
        OUTPUT
    } state_t;
    
    state_t state, next_state;
    
    //=========================================================================
    // Internal Storage
    //=========================================================================
    
    logic signed [DATA_WIDTH-1:0]   input_buffer [MAX_CLASSES];
    logic [15:0]                    exp_buffer [MAX_CLASSES];
    logic signed [DATA_WIDTH-1:0]   max_val;
    logic [23:0]                    exp_sum;
    logic [9:0]                     count;
    logic [9:0]                     class_count;
    
    //=========================================================================
    // Exponential LUT (exp(x) for x in [-128, 127], scaled)
    // Using piecewise linear approximation
    //=========================================================================
    
    function automatic logic [15:0] exp_approx(input logic signed [DATA_WIDTH-1:0] x);
        logic signed [DATA_WIDTH-1:0] x_shifted;
        logic [15:0] result;
        
        // Shift to positive range and scale
        x_shifted = x + 8'sd64;  // Shift by 64
        
        if (x_shifted < 0)
            result = 16'd1;      // Very small
        else if (x_shifted > 127)
            result = 16'd65535;  // Saturate
        else begin
            // Piecewise linear approximation
            // exp(x) ≈ 2^(x * 1.4427) for scaled values
            result = 16'd256 + (x_shifted << 3) + (x_shifted << 1);
        end
        
        return result;
    endfunction
    
    //=========================================================================
    // State Machine
    //=========================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end
    
    always_comb begin
        next_state = state;
        case (state)
            IDLE:       if (start) next_state = FIND_MAX;
            FIND_MAX:   if (count >= class_count) next_state = CALC_EXP;
            CALC_EXP:   if (count >= class_count) next_state = CALC_SUM;
            CALC_SUM:   if (count >= class_count) next_state = NORMALIZE;
            NORMALIZE:  if (count >= class_count) next_state = OUTPUT;
            OUTPUT:     if (count >= class_count) next_state = IDLE;
            default:    next_state = IDLE;
        endcase
    end
    
    //=========================================================================
    // Data Path
    //=========================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count       <= '0;
            class_count <= '0;
            max_val     <= {1'b1, {(DATA_WIDTH-1){1'b0}}};  // Min value
            exp_sum     <= '0;
            valid_out   <= 1'b0;
            data_out    <= '0;
            done        <= 1'b0;
        end else begin
            done <= 1'b0;
            valid_out <= 1'b0;
            
            case (state)
                IDLE: begin
                    count       <= '0;
                    class_count <= num_classes;
                    max_val     <= {1'b1, {(DATA_WIDTH-1){1'b0}}};
                    exp_sum     <= '0;
                    
                    // Store input data
                    if (valid_in && count < num_classes) begin
                        input_buffer[count] <= data_in;
                        count <= count + 1'b1;
                    end
                end
                
                FIND_MAX: begin
                    if (count < class_count) begin
                        if (input_buffer[count] > max_val)
                            max_val <= input_buffer[count];
                        count <= count + 1'b1;
                    end else begin
                        count <= '0;
                    end
                end
                
                CALC_EXP: begin
                    if (count < class_count) begin
                        // exp(x - max) for numerical stability
                        exp_buffer[count] <= exp_approx(input_buffer[count] - max_val);
                        count <= count + 1'b1;
                    end else begin
                        count <= '0;
                    end
                end
                
                CALC_SUM: begin
                    if (count < class_count) begin
                        exp_sum <= exp_sum + exp_buffer[count];
                        count <= count + 1'b1;
                    end else begin
                        count <= '0;
                    end
                end
                
                NORMALIZE: begin
                    if (count < class_count) begin
                        // Normalize: exp_buffer[i] / exp_sum, scaled to 0-255
                        exp_buffer[count] <= (exp_buffer[count] << 8) / exp_sum[15:0];
                        count <= count + 1'b1;
                    end else begin
                        count <= '0;
                    end
                end
                
                OUTPUT: begin
                    if (count < class_count) begin
                        valid_out <= 1'b1;
                        data_out  <= exp_buffer[count][OUT_WIDTH-1:0];
                        count     <= count + 1'b1;
                    end else begin
                        done <= 1'b1;
                    end
                end
            endcase
        end
    end
    
    assign busy = (state != IDLE);

endmodule
