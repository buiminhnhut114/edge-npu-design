//=============================================================================
// Instruction Decoder
// Decodes NPU instructions and generates control signals
//=============================================================================

module instruction_decoder
    import npu_pkg::*;
#(
    parameter int INST_WIDTH = 64
)(
    input  logic                    clk,
    input  logic                    rst_n,
    
    // Instruction interface
    input  logic                    inst_valid,
    input  instruction_t            inst_in,
    output logic                    inst_ready,
    
    // Decoded control signals
    output opcode_t                 opcode,
    output logic [7:0]              dst_addr,
    output logic [7:0]              src0_addr,
    output logic [7:0]              src1_addr,
    output logic [31:0]             immediate,
    output logic [3:0]              flags,
    
    // Operation-specific controls
    output logic                    is_compute,     // Conv, FC, etc.
    output logic                    is_memory,      // Load, Store
    output logic                    is_activation,  // Activation function
    output logic                    is_pooling,     // Pooling operation
    output logic                    is_elementwise, // Element-wise ops
    output logic                    is_sync,        // Synchronization
    
    // Convolution parameters (extracted from immediate)
    output logic [3:0]              kernel_size,
    output logic [3:0]              stride,
    output logic [3:0]              padding,
    output activation_t             act_type,
    output pooling_t                pool_type,
    
    // Status
    output logic                    decode_valid,
    output logic                    decode_error
);

    //=========================================================================
    // Instruction Decode Logic
    //=========================================================================
    
    // Pipeline registers
    instruction_t inst_reg;
    logic         valid_reg;
    
    // Decode stage 1: Register instruction
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            inst_reg  <= '0;
            valid_reg <= 1'b0;
        end else if (inst_valid && inst_ready) begin
            inst_reg  <= inst_in;
            valid_reg <= 1'b1;
        end else begin
            valid_reg <= 1'b0;
        end
    end
    
    // Always ready to accept new instruction (single-cycle decode)
    assign inst_ready = 1'b1;
    
    //=========================================================================
    // Decode Stage 2: Extract fields and generate controls
    //=========================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            opcode       <= OP_NOP;
            dst_addr     <= '0;
            src0_addr    <= '0;
            src1_addr    <= '0;
            immediate    <= '0;
            flags        <= '0;
            decode_valid <= 1'b0;
            decode_error <= 1'b0;
        end else if (valid_reg) begin
            // Extract instruction fields
            opcode    <= inst_reg.opcode;
            flags     <= inst_reg.flags;
            dst_addr  <= inst_reg.dst_addr;
            src0_addr <= inst_reg.src0_addr;
            src1_addr <= inst_reg.src1_addr;
            immediate <= inst_reg.immediate;
            
            decode_valid <= 1'b1;
            decode_error <= 1'b0;
            
            // Check for invalid opcode
            if (inst_reg.opcode > OP_SPLIT) begin
                decode_error <= 1'b1;
            end
        end else begin
            decode_valid <= 1'b0;
        end
    end
    
    //=========================================================================
    // Operation Type Classification
    //=========================================================================
    
    always_comb begin
        // Default all to 0
        is_compute     = 1'b0;
        is_memory      = 1'b0;
        is_activation  = 1'b0;
        is_pooling     = 1'b0;
        is_elementwise = 1'b0;
        is_sync        = 1'b0;
        
        case (opcode)
            OP_CONV, OP_FC: begin
                is_compute = 1'b1;
            end
            
            OP_LOAD, OP_STORE: begin
                is_memory = 1'b1;
            end
            
            OP_ACT: begin
                is_activation = 1'b1;
            end
            
            OP_POOL: begin
                is_pooling = 1'b1;
            end
            
            OP_ADD, OP_MUL, OP_CONCAT, OP_SPLIT: begin
                is_elementwise = 1'b1;
            end
            
            OP_SYNC: begin
                is_sync = 1'b1;
            end
            
            default: begin
                // NOP or unknown
            end
        endcase
    end
    
    //=========================================================================
    // Parameter Extraction from Immediate Field
    //=========================================================================
    
    // Immediate field format for CONV:
    // [31:28] - kernel_size
    // [27:24] - stride
    // [23:20] - padding
    // [19:17] - activation type
    // [16:0]  - reserved
    
    assign kernel_size = immediate[31:28];
    assign stride      = immediate[27:24];
    assign padding     = immediate[23:20];
    
    // Activation type from immediate or flags
    always_comb begin
        if (is_activation) begin
            act_type = activation_t'(immediate[2:0]);
        end else if (is_compute) begin
            act_type = activation_t'(immediate[19:17]);
        end else begin
            act_type = ACT_NONE;
        end
    end
    
    // Pooling type from immediate
    always_comb begin
        if (is_pooling) begin
            pool_type = pooling_t'(immediate[1:0]);
        end else begin
            pool_type = POOL_MAX;
        end
    end

endmodule
