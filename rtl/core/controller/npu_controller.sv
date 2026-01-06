//=============================================================================
// NPU Controller
// Main control unit for NPU operations
//=============================================================================

module npu_controller
    import npu_pkg::*;
#(
    parameter int PE_ROWS = 16,
    parameter int PE_COLS = 16
)(
    input  logic                    clk,
    input  logic                    rst_n,
    
    // Control interface
    input  logic                    start,
    input  logic                    enable,
    output logic                    busy,
    output logic                    done,
    output logic [3:0]              state_out,
    
    // Instruction interface
    input  instruction_t            instruction,
    input  logic                    inst_valid,
    output logic                    inst_ready,
    
    // PE Array control
    output logic                    pe_enable,
    output logic                    pe_clear_acc,
    output logic [PE_ROWS-1:0]      pe_load_weight,
    
    // Activation control
    output activation_t             act_type,
    output logic                    act_enable,
    
    // Pooling control
    output pooling_t                pool_type,
    output logic                    pool_start,
    input  logic                    pool_done,
    
    // Memory control
    output logic                    weight_buf_rd_en,
    output logic [17:0]             weight_buf_addr,
    output logic                    act_buf_rd_en,
    output logic                    act_buf_wr_en,
    output logic [17:0]             act_buf_addr,
    
    // DMA control
    output logic                    dma_start,
    output logic [1:0]              dma_channel,
    input  logic                    dma_done,
    
    // Interrupt
    output logic                    irq_done,
    output logic                    irq_error
);

    //=========================================================================
    // State Machine
    //=========================================================================
    
    typedef enum logic [3:0] {
        ST_IDLE       = 4'h0,
        ST_FETCH      = 4'h1,
        ST_DECODE     = 4'h2,
        ST_LOAD_WEIGHT= 4'h3,
        ST_LOAD_ACT   = 4'h4,
        ST_COMPUTE    = 4'h5,
        ST_ACCUMULATE = 4'h6,
        ST_ACTIVATE   = 4'h7,
        ST_POOL       = 4'h8,
        ST_STORE      = 4'h9,
        ST_DONE       = 4'hA,
        ST_ERROR      = 4'hF
    } state_t;
    
    state_t state, next_state;
    
    //=========================================================================
    // Internal Registers
    //=========================================================================
    
    instruction_t   inst_reg;
    opcode_t        current_op;
    logic [15:0]    compute_count;
    logic [15:0]    compute_total;
    logic [7:0]     weight_row_count;
    
    //=========================================================================
    // State Register
    //=========================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= ST_IDLE;
        else
            state <= next_state;
    end
    
    assign state_out = state;
    
    //=========================================================================
    // Next State Logic
    //=========================================================================
    
    always_comb begin
        next_state = state;
        
        case (state)
            ST_IDLE: begin
                if (start && enable)
                    next_state = ST_FETCH;
            end
            
            ST_FETCH: begin
                if (inst_valid)
                    next_state = ST_DECODE;
            end
            
            ST_DECODE: begin
                case (inst_reg.opcode)
                    OP_NOP:   next_state = ST_FETCH;
                    OP_CONV:  next_state = ST_LOAD_WEIGHT;
                    OP_FC:    next_state = ST_LOAD_WEIGHT;
                    OP_POOL:  next_state = ST_LOAD_ACT;
                    OP_ACT:   next_state = ST_LOAD_ACT;
                    OP_LOAD:  next_state = ST_LOAD_ACT;
                    OP_STORE: next_state = ST_STORE;
                    OP_SYNC:  next_state = ST_DONE;
                    default:  next_state = ST_ERROR;
                endcase
            end
            
            ST_LOAD_WEIGHT: begin
                if (weight_row_count >= PE_ROWS)
                    next_state = ST_LOAD_ACT;
            end
            
            ST_LOAD_ACT: begin
                next_state = ST_COMPUTE;
            end
            
            ST_COMPUTE: begin
                if (compute_count >= compute_total)
                    next_state = ST_ACCUMULATE;
            end
            
            ST_ACCUMULATE: begin
                if (inst_reg.opcode == OP_POOL)
                    next_state = ST_POOL;
                else
                    next_state = ST_ACTIVATE;
            end
            
            ST_ACTIVATE: begin
                next_state = ST_STORE;
            end
            
            ST_POOL: begin
                if (pool_done)
                    next_state = ST_STORE;
            end
            
            ST_STORE: begin
                next_state = ST_FETCH;
            end
            
            ST_DONE: begin
                next_state = ST_IDLE;
            end
            
            ST_ERROR: begin
                next_state = ST_IDLE;
            end
            
            default: next_state = ST_IDLE;
        endcase
    end
    
    //=========================================================================
    // Instruction Latch
    //=========================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            inst_reg <= '0;
        end else if (state == ST_FETCH && inst_valid) begin
            inst_reg <= instruction;
        end
    end
    
    assign current_op = inst_reg.opcode;
    
    //=========================================================================
    // Compute Counter
    //=========================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            compute_count <= '0;
            compute_total <= '0;
        end else begin
            case (state)
                ST_DECODE: begin
                    compute_count <= '0;
                    compute_total <= inst_reg.immediate[15:0];
                end
                ST_COMPUTE: begin
                    if (pe_enable)
                        compute_count <= compute_count + 1'b1;
                end
            endcase
        end
    end
    
    //=========================================================================
    // Weight Loading Counter
    //=========================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            weight_row_count <= '0;
        end else begin
            case (state)
                ST_DECODE: weight_row_count <= '0;
                ST_LOAD_WEIGHT: weight_row_count <= weight_row_count + 1'b1;
            endcase
        end
    end
    
    //=========================================================================
    // Output Control Signals
    //=========================================================================
    
    // Status
    assign busy = (state != ST_IDLE);
    assign done = (state == ST_DONE);
    assign inst_ready = (state == ST_FETCH);
    
    // PE Array
    assign pe_enable = (state == ST_COMPUTE);
    assign pe_clear_acc = (state == ST_DECODE);
    
    always_comb begin
        pe_load_weight = '0;
        if (state == ST_LOAD_WEIGHT && weight_row_count < PE_ROWS)
            pe_load_weight[weight_row_count] = 1'b1;
    end
    
    // Activation
    always_comb begin
        case (inst_reg.flags[2:0])
            3'h0: act_type = ACT_NONE;
            3'h1: act_type = ACT_RELU;
            3'h2: act_type = ACT_RELU6;
            3'h3: act_type = ACT_SIGMOID;
            3'h4: act_type = ACT_TANH;
            3'h5: act_type = ACT_SWISH;
            3'h6: act_type = ACT_GELU;
            default: act_type = ACT_NONE;
        endcase
    end
    assign act_enable = (state == ST_ACTIVATE);
    
    // Pooling - use case instead of cast for iverilog compatibility
    always_comb begin
        case (inst_reg.flags[1:0])
            2'h0: pool_type = POOL_MAX;
            2'h1: pool_type = POOL_AVG;
            2'h2: pool_type = POOL_GLOBAL;
            default: pool_type = POOL_MAX;
        endcase
    end
    assign pool_start = (state == ST_POOL) && (next_state != ST_POOL);
    
    // Memory
    assign weight_buf_rd_en = (state == ST_LOAD_WEIGHT);
    assign weight_buf_addr = inst_reg.src1_addr + weight_row_count;
    assign act_buf_rd_en = (state == ST_LOAD_ACT) || (state == ST_COMPUTE);
    assign act_buf_wr_en = (state == ST_STORE);
    assign act_buf_addr = (state == ST_STORE) ? inst_reg.dst_addr : inst_reg.src0_addr;
    
    // DMA
    assign dma_start = (state == ST_LOAD_ACT) && (current_op == OP_LOAD);
    assign dma_channel = inst_reg.flags[1:0];
    
    // Interrupts
    assign irq_done = (state == ST_DONE);
    assign irq_error = (state == ST_ERROR);

endmodule
