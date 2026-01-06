//=============================================================================
// Instruction Buffer
// FIFO buffer for NPU instructions
//=============================================================================

module instruction_buffer
    import npu_pkg::*;
#(
    parameter int DEPTH = 64,
    parameter int INST_WIDTH = 64
)(
    input  logic                    clk,
    input  logic                    rst_n,
    
    // Write interface (from DMA/AXI)
    input  logic                    wr_en,
    input  logic [INST_WIDTH-1:0]   wr_data,
    output logic                    full,
    
    // Read interface (to decoder)
    input  logic                    rd_en,
    output logic [INST_WIDTH-1:0]   rd_data,
    output logic                    empty,
    output logic                    valid,
    
    // Status
    output logic [$clog2(DEPTH):0]  count,
    
    // Control
    input  logic                    flush
);

    //=========================================================================
    // FIFO Storage
    //=========================================================================
    
    logic [INST_WIDTH-1:0] fifo_mem [DEPTH];
    logic [$clog2(DEPTH)-1:0] wr_ptr, rd_ptr;
    logic [$clog2(DEPTH):0] fifo_count;
    
    assign count = fifo_count;
    assign empty = (fifo_count == 0);
    assign full  = (fifo_count == DEPTH);
    
    //=========================================================================
    // Write Logic
    //=========================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= '0;
        end else if (flush) begin
            wr_ptr <= '0;
        end else if (wr_en && !full) begin
            fifo_mem[wr_ptr] <= wr_data;
            wr_ptr <= wr_ptr + 1'b1;
        end
    end
    
    //=========================================================================
    // Read Logic
    //=========================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr <= '0;
            valid  <= 1'b0;
        end else if (flush) begin
            rd_ptr <= '0;
            valid  <= 1'b0;
        end else begin
            valid <= 1'b0;
            if (rd_en && !empty) begin
                rd_ptr <= rd_ptr + 1'b1;
                valid  <= 1'b1;
            end
        end
    end
    
    assign rd_data = fifo_mem[rd_ptr];
    
    //=========================================================================
    // Count Management
    //=========================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fifo_count <= '0;
        end else if (flush) begin
            fifo_count <= '0;
        end else begin
            case ({wr_en && !full, rd_en && !empty})
                2'b10:   fifo_count <= fifo_count + 1'b1;
                2'b01:   fifo_count <= fifo_count - 1'b1;
                default: fifo_count <= fifo_count;
            endcase
        end
    end

endmodule
