//=============================================================================
// Asynchronous FIFO
// Clock domain crossing FIFO with Gray-code pointers
//=============================================================================

module async_fifo #(
    parameter int DATA_WIDTH = 32,
    parameter int DEPTH      = 16,
    parameter int SYNC_STAGES = 2
)(
    // Write clock domain
    input  logic                        wr_clk,
    input  logic                        wr_rst_n,
    input  logic                        wr_en,
    input  logic [DATA_WIDTH-1:0]       wr_data,
    output logic                        wr_full,
    
    // Read clock domain
    input  logic                        rd_clk,
    input  logic                        rd_rst_n,
    input  logic                        rd_en,
    output logic [DATA_WIDTH-1:0]       rd_data,
    output logic                        rd_empty
);

    localparam ADDR_WIDTH = $clog2(DEPTH);
    localparam PTR_WIDTH  = ADDR_WIDTH + 1;  // Extra bit for wrap detection
    
    //=========================================================================
    // Memory
    //=========================================================================
    
    logic [DATA_WIDTH-1:0] mem [DEPTH];
    
    //=========================================================================
    // Write Domain
    //=========================================================================
    
    logic [PTR_WIDTH-1:0] wr_ptr_bin;
    logic [PTR_WIDTH-1:0] wr_ptr_gray;
    logic [PTR_WIDTH-1:0] rd_ptr_gray_sync;
    
    // Binary to Gray conversion
    function automatic logic [PTR_WIDTH-1:0] bin2gray(logic [PTR_WIDTH-1:0] bin);
        return bin ^ (bin >> 1);
    endfunction
    
    // Gray to Binary conversion
    function automatic logic [PTR_WIDTH-1:0] gray2bin(logic [PTR_WIDTH-1:0] gray);
        logic [PTR_WIDTH-1:0] bin;
        bin[PTR_WIDTH-1] = gray[PTR_WIDTH-1];
        for (int i = PTR_WIDTH-2; i >= 0; i--) begin
            bin[i] = bin[i+1] ^ gray[i];
        end
        return bin;
    endfunction
    
    // Write pointer (binary)
    always_ff @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            wr_ptr_bin <= '0;
        end else if (wr_en && !wr_full) begin
            wr_ptr_bin <= wr_ptr_bin + 1;
        end
    end
    
    // Write pointer (Gray)
    assign wr_ptr_gray = bin2gray(wr_ptr_bin);
    
    // Write to memory
    wire [ADDR_WIDTH-1:0] wr_addr = wr_ptr_bin[ADDR_WIDTH-1:0];
    
    always_ff @(posedge wr_clk) begin
        if (wr_en && !wr_full) begin
            mem[wr_addr] <= wr_data;
        end
    end
    
    // Synchronize read pointer to write domain
    (* ASYNC_REG = "TRUE" *)
    logic [PTR_WIDTH-1:0] rd_ptr_gray_sync_chain [SYNC_STAGES];
    
    always_ff @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            for (int i = 0; i < SYNC_STAGES; i++) begin
                rd_ptr_gray_sync_chain[i] <= '0;
            end
        end else begin
            rd_ptr_gray_sync_chain[0] <= rd_ptr_gray;
            for (int i = 1; i < SYNC_STAGES; i++) begin
                rd_ptr_gray_sync_chain[i] <= rd_ptr_gray_sync_chain[i-1];
            end
        end
    end
    
    assign rd_ptr_gray_sync = rd_ptr_gray_sync_chain[SYNC_STAGES-1];
    
    // Full detection
    assign wr_full = (wr_ptr_gray == {~rd_ptr_gray_sync[PTR_WIDTH-1:PTR_WIDTH-2], 
                                       rd_ptr_gray_sync[PTR_WIDTH-3:0]});
    
    //=========================================================================
    // Read Domain
    //=========================================================================
    
    logic [PTR_WIDTH-1:0] rd_ptr_bin;
    logic [PTR_WIDTH-1:0] rd_ptr_gray;
    logic [PTR_WIDTH-1:0] wr_ptr_gray_sync;
    
    // Read pointer (binary)
    always_ff @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rd_ptr_bin <= '0;
        end else if (rd_en && !rd_empty) begin
            rd_ptr_bin <= rd_ptr_bin + 1;
        end
    end
    
    // Read pointer (Gray)
    assign rd_ptr_gray = bin2gray(rd_ptr_bin);
    
    // Read from memory
    wire [ADDR_WIDTH-1:0] rd_addr = rd_ptr_bin[ADDR_WIDTH-1:0];
    assign rd_data = mem[rd_addr];
    
    // Synchronize write pointer to read domain
    (* ASYNC_REG = "TRUE" *)
    logic [PTR_WIDTH-1:0] wr_ptr_gray_sync_chain [SYNC_STAGES];
    
    always_ff @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            for (int i = 0; i < SYNC_STAGES; i++) begin
                wr_ptr_gray_sync_chain[i] <= '0;
            end
        end else begin
            wr_ptr_gray_sync_chain[0] <= wr_ptr_gray;
            for (int i = 1; i < SYNC_STAGES; i++) begin
                wr_ptr_gray_sync_chain[i] <= wr_ptr_gray_sync_chain[i-1];
            end
        end
    end
    
    assign wr_ptr_gray_sync = wr_ptr_gray_sync_chain[SYNC_STAGES-1];
    
    // Empty detection
    assign rd_empty = (rd_ptr_gray == wr_ptr_gray_sync);

endmodule
