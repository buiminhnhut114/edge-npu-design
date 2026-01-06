//=============================================================================
// Activation Unit
// Supports ReLU, ReLU6, Sigmoid, Tanh, Swish, GELU
//=============================================================================

module activation_unit
    import npu_pkg::*;
#(
    parameter int DATA_WIDTH = 8
)(
    input  logic                            clk,
    input  logic                            rst_n,
    
    // Control
    input  activation_t                     act_type,
    input  logic                            valid_in,
    
    // Data
    input  logic signed [DATA_WIDTH-1:0]    data_in,
    output logic signed [DATA_WIDTH-1:0]    data_out,
    output logic                            valid_out
);

    //=========================================================================
    // Internal Signals
    //=========================================================================
    
    logic signed [DATA_WIDTH-1:0] relu_out;
    logic signed [DATA_WIDTH-1:0] relu6_out;
    logic signed [DATA_WIDTH-1:0] sigmoid_out;
    logic signed [DATA_WIDTH-1:0] tanh_out;
    logic signed [DATA_WIDTH-1:0] result;
    
    // Constants for INT8
    localparam logic signed [DATA_WIDTH-1:0] ZERO = '0;
    localparam logic signed [DATA_WIDTH-1:0] SIX  = 8'sd6;
    localparam logic signed [DATA_WIDTH-1:0] MAX_VAL = 8'sd127;
    
    //=========================================================================
    // ReLU: max(0, x)
    //=========================================================================
    
    assign relu_out = (data_in[DATA_WIDTH-1]) ? ZERO : data_in;
    
    //=========================================================================
    // ReLU6: min(max(0, x), 6)
    //=========================================================================
    
    always_comb begin
        if (data_in[DATA_WIDTH-1])
            relu6_out = ZERO;
        else if (data_in > SIX)
            relu6_out = SIX;
        else
            relu6_out = data_in;
    end
    
    //=========================================================================
    // Sigmoid LUT (approximation)
    // sigmoid(x) ≈ 0.5 + 0.25*x for small x, saturates at 0/1
    //=========================================================================
    
    always_comb begin
        if (data_in < -8'sd64)
            sigmoid_out = ZERO;
        else if (data_in > 8'sd64)
            sigmoid_out = MAX_VAL;
        else
            // Linear approximation: 64 + x/2
            sigmoid_out = 8'sd64 + (data_in >>> 1);
    end
    
    //=========================================================================
    // Tanh LUT (approximation)
    // tanh(x) ≈ x for small x, saturates at -1/1
    //=========================================================================
    
    always_comb begin
        if (data_in < -8'sd64)
            tanh_out = -MAX_VAL;
        else if (data_in > 8'sd64)
            tanh_out = MAX_VAL;
        else
            // Linear approximation scaled
            tanh_out = data_in <<< 1;
    end
    
    //=========================================================================
    // Output Mux
    //=========================================================================
    
    always_comb begin
        case (act_type)
            ACT_NONE:    result = data_in;
            ACT_RELU:    result = relu_out;
            ACT_RELU6:   result = relu6_out;
            ACT_SIGMOID: result = sigmoid_out;
            ACT_TANH:    result = tanh_out;
            ACT_SWISH:   result = (data_in[DATA_WIDTH-1]) ? ZERO : data_in; // Simplified
            ACT_GELU:    result = (data_in[DATA_WIDTH-1]) ? ZERO : data_in; // Simplified
            default:     result = data_in;
        endcase
    end
    
    //=========================================================================
    // Pipeline Register
    //=========================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out  <= '0;
            valid_out <= 1'b0;
        end else begin
            data_out  <= result;
            valid_out <= valid_in;
        end
    end

endmodule
