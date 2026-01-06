//=============================================================================
// AXI4 Slave Interface
// Full AXI4 Slave with memory-mapped access
//=============================================================================

module axi4_slave #(
    parameter int AXI_DATA_WIDTH = 128,
    parameter int AXI_ADDR_WIDTH = 40,
    parameter int AXI_ID_WIDTH   = 8,
    parameter int MEM_DEPTH      = 4096
)(
    input  logic                            clk,
    input  logic                            rst_n,
    
    //=========================================================================
    // AXI4 Slave Interface
    //=========================================================================
    
    // Write address channel
    input  logic [AXI_ID_WIDTH-1:0]         s_axi_awid,
    input  logic [AXI_ADDR_WIDTH-1:0]       s_axi_awaddr,
    input  logic [7:0]                      s_axi_awlen,
    input  logic [2:0]                      s_axi_awsize,
    input  logic [1:0]                      s_axi_awburst,
    input  logic                            s_axi_awvalid,
    output logic                            s_axi_awready,
    
    // Write data channel
    input  logic [AXI_DATA_WIDTH-1:0]       s_axi_wdata,
    input  logic [AXI_DATA_WIDTH/8-1:0]     s_axi_wstrb,
    input  logic                            s_axi_wlast,
    input  logic                            s_axi_wvalid,
    output logic                            s_axi_wready,
    
    // Write response channel
    output logic [AXI_ID_WIDTH-1:0]         s_axi_bid,
    output logic [1:0]                      s_axi_bresp,
    output logic                            s_axi_bvalid,
    input  logic                            s_axi_bready,
    
    // Read address channel
    input  logic [AXI_ID_WIDTH-1:0]         s_axi_arid,
    input  logic [AXI_ADDR_WIDTH-1:0]       s_axi_araddr,
    input  logic [7:0]                      s_axi_arlen,
    input  logic [2:0]                      s_axi_arsize,
    input  logic [1:0]                      s_axi_arburst,
    input  logic                            s_axi_arvalid,
    output logic                            s_axi_arready,
    
    // Read data channel
    output logic [AXI_ID_WIDTH-1:0]         s_axi_rid,
    output logic [AXI_DATA_WIDTH-1:0]       s_axi_rdata,
    output logic [1:0]                      s_axi_rresp,
    output logic                            s_axi_rlast,
    output logic                            s_axi_rvalid,
    input  logic                            s_axi_rready,
    
    //=========================================================================
    // Memory Interface (to external memory or register file)
    //=========================================================================
    
    output logic                            mem_wr_en,
    output logic [$clog2(MEM_DEPTH)-1:0]    mem_wr_addr,
    output logic [AXI_DATA_WIDTH-1:0]       mem_wr_data,
    output logic [AXI_DATA_WIDTH/8-1:0]     mem_wr_strb,
    
    output logic                            mem_rd_en,
    output logic [$clog2(MEM_DEPTH)-1:0]    mem_rd_addr,
    input  logic [AXI_DATA_WIDTH-1:0]       mem_rd_data
);

    localparam ADDR_LSB = $clog2(AXI_DATA_WIDTH/8);
    localparam MEM_ADDR_WIDTH = $clog2(MEM_DEPTH);
    
    //=========================================================================
    // Write FSM
    //=========================================================================
    
    typedef enum logic [2:0] {
        WR_IDLE,
        WR_ADDR,
        WR_DATA,
        WR_RESP
    } wr_state_t;
    
    wr_state_t wr_state;
    
    logic [AXI_ID_WIDTH-1:0]   wr_id;
    logic [AXI_ADDR_WIDTH-1:0] wr_addr;
    logic [7:0]                wr_len;
    logic [7:0]                wr_cnt;
    logic [1:0]                wr_burst;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_state      <= WR_IDLE;
            s_axi_awready <= 1'b0;
            s_axi_wready  <= 1'b0;
            s_axi_bvalid  <= 1'b0;
            s_axi_bid     <= '0;
            s_axi_bresp   <= 2'b00;
            wr_id         <= '0;
            wr_addr       <= '0;
            wr_len        <= '0;
            wr_cnt        <= '0;
            wr_burst      <= '0;
            mem_wr_en     <= 1'b0;
        end else begin
            mem_wr_en <= 1'b0;
            
            case (wr_state)
                WR_IDLE: begin
                    s_axi_awready <= 1'b1;
                    s_axi_bvalid  <= 1'b0;
                    if (s_axi_awvalid && s_axi_awready) begin
                        wr_id         <= s_axi_awid;
                        wr_addr       <= s_axi_awaddr;
                        wr_len        <= s_axi_awlen;
                        wr_burst      <= s_axi_awburst;
                        wr_cnt        <= '0;
                        s_axi_awready <= 1'b0;
                        s_axi_wready  <= 1'b1;
                        wr_state      <= WR_DATA;
                    end
                end
                
                WR_DATA: begin
                    if (s_axi_wvalid && s_axi_wready) begin
                        mem_wr_en   <= 1'b1;
                        mem_wr_addr <= wr_addr[ADDR_LSB +: MEM_ADDR_WIDTH];
                        mem_wr_data <= s_axi_wdata;
                        mem_wr_strb <= s_axi_wstrb;
                        
                        // Address increment for INCR burst
                        if (wr_burst == 2'b01) begin
                            wr_addr <= wr_addr + (AXI_DATA_WIDTH/8);
                        end
                        
                        wr_cnt <= wr_cnt + 1;
                        
                        if (s_axi_wlast) begin
                            s_axi_wready <= 1'b0;
                            s_axi_bvalid <= 1'b1;
                            s_axi_bid    <= wr_id;
                            s_axi_bresp  <= 2'b00;  // OKAY
                            wr_state     <= WR_RESP;
                        end
                    end
                end
                
                WR_RESP: begin
                    if (s_axi_bvalid && s_axi_bready) begin
                        s_axi_bvalid <= 1'b0;
                        wr_state     <= WR_IDLE;
                    end
                end
                
                default: wr_state <= WR_IDLE;
            endcase
        end
    end
    
    //=========================================================================
    // Read FSM
    //=========================================================================
    
    typedef enum logic [2:0] {
        RD_IDLE,
        RD_ADDR,
        RD_DATA
    } rd_state_t;
    
    rd_state_t rd_state;
    
    logic [AXI_ID_WIDTH-1:0]   rd_id;
    logic [AXI_ADDR_WIDTH-1:0] rd_addr;
    logic [7:0]                rd_len;
    logic [7:0]                rd_cnt;
    logic [1:0]                rd_burst;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_state      <= RD_IDLE;
            s_axi_arready <= 1'b0;
            s_axi_rvalid  <= 1'b0;
            s_axi_rid     <= '0;
            s_axi_rdata   <= '0;
            s_axi_rresp   <= 2'b00;
            s_axi_rlast   <= 1'b0;
            rd_id         <= '0;
            rd_addr       <= '0;
            rd_len        <= '0;
            rd_cnt        <= '0;
            rd_burst      <= '0;
            mem_rd_en     <= 1'b0;
        end else begin
            mem_rd_en <= 1'b0;
            
            case (rd_state)
                RD_IDLE: begin
                    s_axi_arready <= 1'b1;
                    s_axi_rvalid  <= 1'b0;
                    s_axi_rlast   <= 1'b0;
                    if (s_axi_arvalid && s_axi_arready) begin
                        rd_id         <= s_axi_arid;
                        rd_addr       <= s_axi_araddr;
                        rd_len        <= s_axi_arlen;
                        rd_burst      <= s_axi_arburst;
                        rd_cnt        <= '0;
                        s_axi_arready <= 1'b0;
                        mem_rd_en     <= 1'b1;
                        mem_rd_addr   <= s_axi_araddr[ADDR_LSB +: MEM_ADDR_WIDTH];
                        rd_state      <= RD_DATA;
                    end
                end
                
                RD_DATA: begin
                    s_axi_rvalid <= 1'b1;
                    s_axi_rid    <= rd_id;
                    s_axi_rdata  <= mem_rd_data;
                    s_axi_rresp  <= 2'b00;
                    s_axi_rlast  <= (rd_cnt == rd_len);
                    
                    if (s_axi_rvalid && s_axi_rready) begin
                        if (rd_cnt == rd_len) begin
                            s_axi_rvalid <= 1'b0;
                            s_axi_rlast  <= 1'b0;
                            rd_state     <= RD_IDLE;
                        end else begin
                            rd_cnt <= rd_cnt + 1;
                            
                            // Address increment
                            if (rd_burst == 2'b01) begin
                                rd_addr <= rd_addr + (AXI_DATA_WIDTH/8);
                            end
                            
                            mem_rd_en   <= 1'b1;
                            mem_rd_addr <= rd_addr[ADDR_LSB +: MEM_ADDR_WIDTH] + 1;
                        end
                    end
                end
                
                default: rd_state <= RD_IDLE;
            endcase
        end
    end

endmodule
