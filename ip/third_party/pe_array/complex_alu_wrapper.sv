//=============================================================================
// Complex ALU Wrapper
// Adapts opensource complex_alu for EdgeNPU
// Supports: ADD, SUB, MUL, MULADD, MULSUB, MAX operations
// Uses 4 DSP48E2 blocks for complex number arithmetic
//=============================================================================

module complex_alu_wrapper
    import npu_pkg::*;
#(
    parameter int DATA_WIDTH = 16
)(
    input  logic                            clk,
    input  logic                            rst_n,
    
    // Control
    input  logic [2:0]                      opcode,     // Operation select
    input  logic                            valid_in,
    
    // Operand A (complex: {real, imag})
    input  logic [DATA_WIDTH*2-1:0]         operand_a,
    
    // Operand B (complex: {real, imag})
    input  logic [DATA_WIDTH*2-1:0]         operand_b,
    
    // Operand C (for MULADD/MULSUB)
    input  logic [DATA_WIDTH*2-1:0]         operand_c,
    
    // Result (complex: {real, imag})
    output logic [DATA_WIDTH*2-1:0]         result,
    output logic                            valid_out
);

    //=========================================================================
    // Operation Codes (matching original complex_alu)
    //=========================================================================
    
    localparam logic [2:0] OP_ADD    = 3'b001;
    localparam logic [2:0] OP_SUB    = 3'b010;
    localparam logic [2:0] OP_MUL    = 3'b100;
    localparam logic [2:0] OP_MULADD = 3'b101;
    localparam logic [2:0] OP_MULSUB = 3'b110;
    localparam logic [2:0] OP_MAX    = 3'b111;
    
    //=========================================================================
    // Control Signal Generation
    //=========================================================================
    
    // DSP48E2 control signals (4 DSPs)
    logic [15:0] alumode;   // 4-bit * 4
    logic [19:0] inmode;    // 5-bit * 4
    logic [27:0] opmode;    // 7-bit * 4
    logic [3:0]  cea2;
    logic [3:0]  ceb2;
    logic [3:0]  usemult;
    
    // Generate control signals based on opcode
    always_comb begin
        case (opcode)
            OP_ADD: begin
                alumode = 16'b0000_0000_0000_0000;
                inmode  = 20'b00000_00000_00000_00000;
                opmode  = 28'b0110011_0110011_0110011_0110011;
                cea2    = 4'b1111;
                ceb2    = 4'b1111;
                usemult = 4'b0000;
            end
            OP_SUB: begin
                alumode = 16'b0011_0011_0011_0011;
                inmode  = 20'b00000_00000_00000_00000;
                opmode  = 28'b0110011_0110011_0110011_0110011;
                cea2    = 4'b1111;
                ceb2    = 4'b1111;
                usemult = 4'b0000;
            end
            OP_MUL: begin
                alumode = 16'b0000_0000_0000_0000;
                inmode  = 20'b10001_10001_10001_10001;
                opmode  = 28'b0000101_0000101_0000101_0000101;
                cea2    = 4'b0000;
                ceb2    = 4'b0000;
                usemult = 4'b1111;
            end
            OP_MULADD: begin
                alumode = 16'b0000_0000_0000_0000;
                inmode  = 20'b10001_10001_10001_10001;
                opmode  = 28'b0110101_0000101_0110101_0000101;
                cea2    = 4'b0000;
                ceb2    = 4'b0000;
                usemult = 4'b1111;
            end
            OP_MULSUB: begin
                alumode = 16'b0011_0000_0011_0000;
                inmode  = 20'b10001_10001_10001_10001;
                opmode  = 28'b0110101_0000101_0110101_0000101;
                cea2    = 4'b0000;
                ceb2    = 4'b0000;
                usemult = 4'b1111;
            end
            OP_MAX: begin
                alumode = 16'b0000_0000_0000_0000;
                inmode  = 20'b10001_10001_10001_10001;
                opmode  = 28'b0000101_0000101_0000101_0000101;
                cea2    = 4'b0000;
                ceb2    = 4'b0000;
                usemult = 4'b1111;
            end
            default: begin
                alumode = 16'b0000_0000_0000_0000;
                inmode  = 20'b00000_00000_00000_00000;
                opmode  = 28'b0000000_0000000_0000000_0000000;
                cea2    = 4'b0000;
                ceb2    = 4'b0000;
                usemult = 4'b0000;
            end
        endcase
    end
    
    //=========================================================================
    // Valid Pipeline
    //=========================================================================
    
    // Complex ALU has ~7 cycle latency
    logic [7:0] valid_pipe;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            valid_pipe <= '0;
        else
            valid_pipe <= {valid_pipe[6:0], valid_in};
    end
    
    assign valid_out = valid_pipe[7];
    
    //=========================================================================
    // Instantiate Original Complex ALU
    //=========================================================================
    
    complex_alu u_complex_alu (
        .clk     (clk),
        .rst     (~rst_n),
        .opcode  (opcode),
        .alumode (alumode),
        .inmode  (inmode),
        .opmode  (opmode),
        .cea2    (cea2),
        .ceb2    (ceb2),
        .usemult (usemult),
        .din_1   (operand_a),
        .din_2   (operand_b),
        .din_3   (operand_c),
        .dout    (result)
    );

endmodule
