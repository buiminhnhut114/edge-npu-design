//=============================================================================
// Weight Buffer
// 256KB buffer for storing neural network weights
//=============================================================================

module weight_buffer
    import npu_pkg::*;
#(
    parameter int DATA_WIDTH = 128,
    parameter int SIZE_KB    = 256,
    parameter int DEPTH      = (SIZE_KB * 1024 * 8) / DATA_WIDTH,
    parameter int ADDR_WIDTH = $clog2(DEPTH)
)(
    input  logic                    clk,
    input  logic                    rst_n,
    
    // Write port (from DMA)
    input  logic                    wr_en,
    input  logic [ADDR_WIDTH-1:0]   wr_addr,
    input  logic [DATA_WIDTH-1:0]   wr_data,
    
    // Read port (to PE array)
    input  logic                    rd_en,
    input  logic [ADDR_WIDTH-1:0]   rd_addr,
    output logic [DATA_WIDTH-1:0]   rd_data,
    output logic                    rd_valid
);

    //=========================================================================
    // SRAM Instance
    //=========================================================================
    
    logic [DATA_WIDTH-1:0] mem_rdata;
    logic rd_en_d;
    
    sram_sp #(
        .DATA_WIDTH (DATA_WIDTH),
        .DEPTH      (DEPTH)
    ) u_sram (
        .clk   (clk),
        .rst_n (rst_n),
        .en    (wr_en | rd_en),
        .we    (wr_en),
        .addr  (wr_en ? wr_addr : rd_addr),
        .wdata (wr_data),
        .rdata (mem_rdata)
    );
    
    //=========================================================================
    // Read Valid Pipeline
    //=========================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_en_d  <= 1'b0;
            rd_valid <= 1'b0;
            rd_data  <= '0;
        end else begin
            rd_en_d  <= rd_en;
            rd_valid <= rd_en_d;
            rd_data  <= mem_rdata;
        end
    end

endmodule
