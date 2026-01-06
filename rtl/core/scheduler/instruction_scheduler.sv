//=============================================================================
// Instruction Scheduler
// Manages instruction queue and schedules execution
//=============================================================================

module instruction_scheduler
    import npu_pkg::*;
#(
    parameter int QUEUE_DEPTH = 16
)(
    input  logic                    clk,
    input  logic                    rst_n,
    
    // Instruction input (from instruction buffer)
    input  logic                    inst_valid,
    input  instruction_t            inst_in,
    output logic                    inst_ready,
    
    // Instruction output (to decoder)
    output logic                    sched_valid,
    output instruction_t            sched_inst,
    input  logic                    sched_ready,
    
    // Execution unit status
    input  logic                    conv_busy,
    input  logic                    conv_done,
    input  logic                    pool_busy,
    input  logic                    pool_done,
    input  logic                    act_busy,
    input  logic                    dma_busy,
    input  logic                    dma_done,
    
    // Status
    output logic                    queue_empty,
    output logic                    queue_full,
    output logic [4:0]              queue_count
);

    //=========================================================================
    // Instruction Queue (FIFO)
    //=========================================================================
    
    instruction_t queue [QUEUE_DEPTH];
    logic [$clog2(QUEUE_DEPTH)-1:0] wr_ptr, rd_ptr;
    logic [$clog2(QUEUE_DEPTH):0]   count;
    
    assign queue_empty = (count == 0);
    assign queue_full  = (count == QUEUE_DEPTH);
    assign queue_count = count[$clog2(QUEUE_DEPTH):0];
    assign inst_ready  = !queue_full;
    
    // Write to queue
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= '0;
        end else if (inst_valid && !queue_full) begin
            queue[wr_ptr] <= inst_in;
            wr_ptr <= wr_ptr + 1'b1;
        end
    end
    
    // Read from queue
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr <= '0;
        end else if (sched_valid && sched_ready) begin
            rd_ptr <= rd_ptr + 1'b1;
        end
    end
    
    // Count management
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= '0;
        end else begin
            case ({inst_valid && !queue_full, sched_valid && sched_ready})
                2'b10:   count <= count + 1'b1;
                2'b01:   count <= count - 1'b1;
                default: count <= count;
            endcase
        end
    end
    
    //=========================================================================
    // Scheduling Logic
    //=========================================================================
    
    instruction_t next_inst;
    opcode_t      next_opcode;
    logic         can_issue;
    
    assign next_inst   = queue[rd_ptr];
    assign next_opcode = next_inst.opcode;
    
    // Determine if instruction can be issued based on resource availability
    always_comb begin
        can_issue = 1'b0;
        
        if (!queue_empty) begin
            case (next_opcode)
                OP_CONV, OP_FC: begin
                    // Need compute unit free
                    can_issue = !conv_busy;
                end
                
                OP_POOL: begin
                    // Need pooling unit free
                    can_issue = !pool_busy;
                end
                
                OP_ACT: begin
                    // Need activation unit free
                    can_issue = !act_busy;
                end
                
                OP_LOAD, OP_STORE: begin
                    // Need DMA free
                    can_issue = !dma_busy;
                end
                
                OP_ADD, OP_MUL, OP_CONCAT, OP_SPLIT: begin
                    // Element-wise ops can always issue (pipelined)
                    can_issue = 1'b1;
                end
                
                OP_SYNC: begin
                    // Wait for all units to be idle
                    can_issue = !conv_busy && !pool_busy && !dma_busy;
                end
                
                OP_NOP: begin
                    // NOP always issues
                    can_issue = 1'b1;
                end
                
                default: begin
                    can_issue = 1'b1;
                end
            endcase
        end
    end
    
    //=========================================================================
    // Output
    //=========================================================================
    
    assign sched_valid = can_issue && !queue_empty;
    assign sched_inst  = next_inst;

endmodule
