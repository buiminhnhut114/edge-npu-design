//=============================================================================
// Element-wise Operations Unit
// Supports: Add, Sub, Mul, Max, Min for skip connections (ResNet, etc.)
//=============================================================================

module elementwise_unit
    import npu_pkg::*;
#(
    parameter int DATA_WIDTH = 8
)(
    input  logic                            clk,
    input  logic                            rst_n,
    
    // Control
    input  logic [2:0]                      op_type,    // Operation type
    input  logic                            enable,
    
    // Input A
    input  logic                            valid_a,
    input  logic signed [DATA_WIDTH-1:0]    data_a,
    
    // Input B
    input  logic                            valid_b,
    input  logic signed [DATA_WIDTH-1:0]    data_b,
    
    // Output
    output logic                            valid_out,
    output logic signed [DATA_WIDTH-1:0]    data_out
);

    //=========================================================================
    // Operation Types
    //=========================================================================
    
    localparam logic [2:0] EW_ADD = 3'b000;
    localparam logic [2:0] EW_SUB = 3'b001;
    localparam logic [2:0] EW_MUL = 3'b010;
    localparam logic [2:0] EW_MAX = 3'b011;
    localparam logic [2:0] EW_MIN = 3'b100;
    localparam logic [2:0] EW_ABS = 3'b101;
    localparam logic [2:0] EW_NEG = 3'b110;
    
    //=========================================================================
    // Internal Signals
    //=========================================================================
    
    logic signed [DATA_WIDTH:0]     add_result;
    logic signed [DATA_WIDTH:0]     sub_result;
    logic signed [DATA_WIDTH*2-1:0] mul_result;
    logic signed [DATA_WIDTH-1:0]   max_result;
    logic signed [DATA_WIDTH-1:0]   min_result;
    logic signed [DATA_WIDTH-1:0]   abs_result;
    logic signed [DATA_WIDTH-1:0]   neg_result;
    logic signed [DATA_WIDTH-1:0]   result;
    
    logic both_valid;
    
    assign both_valid = valid_a && valid_b;
    
    //=========================================================================
    // Arithmetic Operations
    //=========================================================================
    
    // Addition with overflow detection
    assign add_result = {data_a[DATA_WIDTH-1], data_a} + {data_b[DATA_WIDTH-1], data_b};
    
    // Subtraction with overflow detection
    assign sub_result = {data_a[DATA_WIDTH-1], data_a} - {data_b[DATA_WIDTH-1], data_b};
    
    // Multiplication (take upper bits)
    assign mul_result = data_a * data_b;
    
    // Max/Min
    assign max_result = (data_a > data_b) ? data_a : data_b;
    assign min_result = (data_a < data_b) ? data_a : data_b;
    
    // Absolute value
    assign abs_result = (data_a[DATA_WIDTH-1]) ? -data_a : data_a;
    
    // Negation
    assign neg_result = -data_a;
    
    //=========================================================================
    // Saturation Logic
    //=========================================================================
    
    function automatic logic signed [DATA_WIDTH-1:0] saturate_add(
        input logic signed [DATA_WIDTH:0] val
    );
        if (val > $signed({1'b0, {(DATA_WIDTH-1){1'b1}}}))
            return {1'b0, {(DATA_WIDTH-1){1'b1}}};  // Max positive (127)
        else if (val < $signed({1'b1, {(DATA_WIDTH-1){1'b0}}}))
            return {1'b1, {(DATA_WIDTH-1){1'b0}}};  // Max negative (-128)
        else
            return val[DATA_WIDTH-1:0];
    endfunction
    
    //=========================================================================
    // Output Mux
    //=========================================================================
    
    always_comb begin
        case (op_type)
            EW_ADD:  result = saturate_add(add_result);
            EW_SUB:  result = saturate_add(sub_result);
            EW_MUL:  result = mul_result[DATA_WIDTH+6:7];  // Scale down
            EW_MAX:  result = max_result;
            EW_MIN:  result = min_result;
            EW_ABS:  result = abs_result;
            EW_NEG:  result = neg_result;
            default: result = data_a;
        endcase
    end
    
    //=========================================================================
    // Output Register
    //=========================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out  <= '0;
            valid_out <= 1'b0;
        end else if (enable) begin
            data_out  <= result;
            valid_out <= (op_type == EW_ABS || op_type == EW_NEG) ? valid_a : both_valid;
        end else begin
            valid_out <= 1'b0;
        end
    end

endmodule
