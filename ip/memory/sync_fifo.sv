//=============================================================================
// Synchronous FIFO
// Generic synchronous FIFO with configurable depth
//=============================================================================

module sync_fifo #(
    parameter int DATA_WIDTH   = 32,
    parameter int DEPTH        = 16,
    parameter int ALMOST_FULL  = DEPTH - 2,
    parameter int ALMOST_EMPTY = 2
)(
    input  logic                        clk,
    input  logic                        rst_n,
    
    // Write interface
    input  logic                        wr_en,
    input  logic [DATA_WIDTH-1:0]       wr_data,
    output logic                        full,
    output logic                        almost_full,
    
    // Read interface
    input  logic                        rd_en,
    output logic [DATA_WIDTH-1:0]       rd_data,
    output logic                        empty,
    output logic                        almost_empty,
    
    // Status
    output logic [$clog2(DEPTH):0]      count
);

    //=========================================================================
    // Memory and Pointers
    //=========================================================================
    
    localparam ADDR_WIDTH = $clog2(DEPTH);
    
    logic [DATA_WIDTH-1:0] mem [DEPTH];
    logic [ADDR_WIDTH-1:0] wr_ptr;
    logic [ADDR_WIDTH-1:0] rd_ptr;
    logic [$clog2(DEPTH):0] cnt;
    
    //=========================================================================
    // Write Logic
    //=========================================================================
    
    wire wr_valid = wr_en && !full;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= '0;
        end else if (wr_valid) begin
            mem[wr_ptr] <= wr_data;
            wr_ptr <= (wr_ptr == DEPTH - 1) ? '0 : wr_ptr + 1;
        end
    end
    
    //=========================================================================
    // Read Logic
    //=========================================================================
    
    wire rd_valid = rd_en && !empty;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr  <= '0;
            rd_data <= '0;
        end else if (rd_valid) begin
            rd_data <= mem[rd_ptr];
            rd_ptr  <= (rd_ptr == DEPTH - 1) ? '0 : rd_ptr + 1;
        end
    end
    
    //=========================================================================
    // Count Logic
    //=========================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt <= '0;
        end else begin
            case ({wr_valid, rd_valid})
                2'b10:   cnt <= cnt + 1;
                2'b01:   cnt <= cnt - 1;
                default: cnt <= cnt;
            endcase
        end
    end
    
    assign count = cnt;
    
    //=========================================================================
    // Status Flags
    //=========================================================================
    
    assign full         = (cnt == DEPTH);
    assign empty        = (cnt == 0);
    assign almost_full  = (cnt >= ALMOST_FULL);
    assign almost_empty = (cnt <= ALMOST_EMPTY);

endmodule
