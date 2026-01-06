//=============================================================================
// Output Buffer
// Double-buffered output for NPU results before DMA
//=============================================================================

module output_buffer
    import npu_pkg::*;
#(
    parameter int DATA_WIDTH = 128,
    parameter int SIZE_KB    = 64,
    parameter int ADDR_WIDTH = $clog2(SIZE_KB * 1024 / (DATA_WIDTH/8))
)(
    input  logic                    clk,
    input  logic                    rst_n,
    
    // Write interface (from compute units)
    input  logic                    wr_en,
    input  logic [ADDR_WIDTH-1:0]   wr_addr,
    input  logic [DATA_WIDTH-1:0]   wr_data,
    
    // Read interface (to DMA)
    input  logic                    rd_en,
    input  logic [ADDR_WIDTH-1:0]   rd_addr,
    output logic [DATA_WIDTH-1:0]   rd_data,
    output logic                    rd_valid,
    
    // Double buffer control
    input  logic                    swap_buffers,
    output logic                    buffer_ready,   // Current read buffer has valid data
    output logic                    buffer_id       // Which buffer is being read (0 or 1)
);

    //=========================================================================
    // Double Buffer Memory
    //=========================================================================
    
    localparam int DEPTH = SIZE_KB * 1024 / (DATA_WIDTH/8);
    
    logic [DATA_WIDTH-1:0] buffer0 [DEPTH];
    logic [DATA_WIDTH-1:0] buffer1 [DEPTH];
    
    logic active_wr_buf;  // Which buffer is being written
    logic active_rd_buf;  // Which buffer is being read
    logic buf0_valid, buf1_valid;
    
    assign buffer_id = active_rd_buf;
    assign buffer_ready = active_rd_buf ? buf1_valid : buf0_valid;
    
    //=========================================================================
    // Buffer Swap Logic
    //=========================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            active_wr_buf <= 1'b0;
            active_rd_buf <= 1'b1;
            buf0_valid    <= 1'b0;
            buf1_valid    <= 1'b0;
        end else if (swap_buffers) begin
            // Swap buffers
            active_wr_buf <= ~active_wr_buf;
            active_rd_buf <= ~active_rd_buf;
            
            // Mark write buffer as valid, read buffer as invalid
            if (active_wr_buf)
                buf1_valid <= 1'b1;
            else
                buf0_valid <= 1'b1;
                
            if (active_rd_buf)
                buf1_valid <= 1'b0;
            else
                buf0_valid <= 1'b0;
        end
    end
    
    //=========================================================================
    // Write Logic
    //=========================================================================
    
    always_ff @(posedge clk) begin
        if (wr_en) begin
            if (active_wr_buf)
                buffer1[wr_addr] <= wr_data;
            else
                buffer0[wr_addr] <= wr_data;
        end
    end
    
    //=========================================================================
    // Read Logic
    //=========================================================================
    
    logic [DATA_WIDTH-1:0] rd_data_reg;
    logic                  rd_valid_reg;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_data_reg  <= '0;
            rd_valid_reg <= 1'b0;
        end else begin
            rd_valid_reg <= rd_en;
            if (rd_en) begin
                if (active_rd_buf)
                    rd_data_reg <= buffer1[rd_addr];
                else
                    rd_data_reg <= buffer0[rd_addr];
            end
        end
    end
    
    assign rd_data  = rd_data_reg;
    assign rd_valid = rd_valid_reg;

endmodule
