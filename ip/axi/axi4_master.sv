//=============================================================================
// AXI4 Master Interface
// Full AXI4 Master with burst support
//=============================================================================

module axi4_master #(
    parameter int AXI_DATA_WIDTH = 128,
    parameter int AXI_ADDR_WIDTH = 40,
    parameter int AXI_ID_WIDTH   = 8,
    parameter int AXI_LEN_WIDTH  = 8,
    parameter int MAX_OUTSTANDING = 4
)(
    input  logic                            clk,
    input  logic                            rst_n,
    
    //=========================================================================
    // User Interface
    //=========================================================================
    
    // Write request
    input  logic                            wr_req,
    input  logic [AXI_ADDR_WIDTH-1:0]       wr_addr,
    input  logic [AXI_LEN_WIDTH-1:0]        wr_len,
    input  logic [2:0]                      wr_size,
    input  logic [1:0]                      wr_burst,
    output logic                            wr_ready,
    
    // Write data
    input  logic                            wd_valid,
    input  logic [AXI_DATA_WIDTH-1:0]       wd_data,
    input  logic [AXI_DATA_WIDTH/8-1:0]     wd_strb,
    input  logic                            wd_last,
    output logic                            wd_ready,
    
    // Write response
    output logic                            wr_done,
    output logic [1:0]                      wr_resp,
    
    // Read request
    input  logic                            rd_req,
    input  logic [AXI_ADDR_WIDTH-1:0]       rd_addr,
    input  logic [AXI_LEN_WIDTH-1:0]        rd_len,
    input  logic [2:0]                      rd_size,
    input  logic [1:0]                      rd_burst,
    output logic                            rd_ready,
    
    // Read data
    output logic                            rd_valid,
    output logic [AXI_DATA_WIDTH-1:0]       rd_data,
    output logic [1:0]                      rd_resp,
    output logic                            rd_last,
    input  logic                            rd_accept,
    
    //=========================================================================
    // AXI4 Master Interface
    //=========================================================================
    
    // Write address channel
    output logic [AXI_ID_WIDTH-1:0]         m_axi_awid,
    output logic [AXI_ADDR_WIDTH-1:0]       m_axi_awaddr,
    output logic [AXI_LEN_WIDTH-1:0]        m_axi_awlen,
    output logic [2:0]                      m_axi_awsize,
    output logic [1:0]                      m_axi_awburst,
    output logic                            m_axi_awlock,
    output logic [3:0]                      m_axi_awcache,
    output logic [2:0]                      m_axi_awprot,
    output logic [3:0]                      m_axi_awqos,
    output logic                            m_axi_awvalid,
    input  logic                            m_axi_awready,
    
    // Write data channel
    output logic [AXI_DATA_WIDTH-1:0]       m_axi_wdata,
    output logic [AXI_DATA_WIDTH/8-1:0]     m_axi_wstrb,
    output logic                            m_axi_wlast,
    output logic                            m_axi_wvalid,
    input  logic                            m_axi_wready,
    
    // Write response channel
    input  logic [AXI_ID_WIDTH-1:0]         m_axi_bid,
    input  logic [1:0]                      m_axi_bresp,
    input  logic                            m_axi_bvalid,
    output logic                            m_axi_bready,
    
    // Read address channel
    output logic [AXI_ID_WIDTH-1:0]         m_axi_arid,
    output logic [AXI_ADDR_WIDTH-1:0]       m_axi_araddr,
    output logic [AXI_LEN_WIDTH-1:0]        m_axi_arlen,
    output logic [2:0]                      m_axi_arsize,
    output logic [1:0]                      m_axi_arburst,
    output logic                            m_axi_arlock,
    output logic [3:0]                      m_axi_arcache,
    output logic [2:0]                      m_axi_arprot,
    output logic [3:0]                      m_axi_arqos,
    output logic                            m_axi_arvalid,
    input  logic                            m_axi_arready,
    
    // Read data channel
    input  logic [AXI_ID_WIDTH-1:0]         m_axi_rid,
    input  logic [AXI_DATA_WIDTH-1:0]       m_axi_rdata,
    input  logic [1:0]                      m_axi_rresp,
    input  logic                            m_axi_rlast,
    input  logic                            m_axi_rvalid,
    output logic                            m_axi_rready
);

    //=========================================================================
    // Internal Signals
    //=========================================================================
    
    logic [AXI_ID_WIDTH-1:0] wr_id_cnt;
    logic [AXI_ID_WIDTH-1:0] rd_id_cnt;
    
    //=========================================================================
    // Write Address Channel
    //=========================================================================
    
    typedef enum logic [1:0] {
        AW_IDLE,
        AW_ACTIVE
    } aw_state_t;
    
    aw_state_t aw_state;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            aw_state        <= AW_IDLE;
            m_axi_awvalid   <= 1'b0;
            m_axi_awid      <= '0;
            m_axi_awaddr    <= '0;
            m_axi_awlen     <= '0;
            m_axi_awsize    <= '0;
            m_axi_awburst   <= '0;
            wr_id_cnt       <= '0;
        end else begin
            case (aw_state)
                AW_IDLE: begin
                    if (wr_req) begin
                        m_axi_awvalid <= 1'b1;
                        m_axi_awid    <= wr_id_cnt;
                        m_axi_awaddr  <= wr_addr;
                        m_axi_awlen   <= wr_len;
                        m_axi_awsize  <= wr_size;
                        m_axi_awburst <= wr_burst;
                        aw_state      <= AW_ACTIVE;
                    end
                end
                AW_ACTIVE: begin
                    if (m_axi_awready) begin
                        m_axi_awvalid <= 1'b0;
                        wr_id_cnt     <= wr_id_cnt + 1;
                        aw_state      <= AW_IDLE;
                    end
                end
            endcase
        end
    end
    
    assign wr_ready = (aw_state == AW_IDLE);
    
    // Fixed signals
    assign m_axi_awlock  = 1'b0;
    assign m_axi_awcache = 4'b0011;  // Normal Non-cacheable Bufferable
    assign m_axi_awprot  = 3'b000;
    assign m_axi_awqos   = 4'b0000;
    
    //=========================================================================
    // Write Data Channel
    //=========================================================================
    
    assign m_axi_wdata  = wd_data;
    assign m_axi_wstrb  = wd_strb;
    assign m_axi_wlast  = wd_last;
    assign m_axi_wvalid = wd_valid;
    assign wd_ready     = m_axi_wready;
    
    //=========================================================================
    // Write Response Channel
    //=========================================================================
    
    assign m_axi_bready = 1'b1;
    assign wr_done      = m_axi_bvalid;
    assign wr_resp      = m_axi_bresp;
    
    //=========================================================================
    // Read Address Channel
    //=========================================================================
    
    typedef enum logic [1:0] {
        AR_IDLE,
        AR_ACTIVE
    } ar_state_t;
    
    ar_state_t ar_state;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ar_state        <= AR_IDLE;
            m_axi_arvalid   <= 1'b0;
            m_axi_arid      <= '0;
            m_axi_araddr    <= '0;
            m_axi_arlen     <= '0;
            m_axi_arsize    <= '0;
            m_axi_arburst   <= '0;
            rd_id_cnt       <= '0;
        end else begin
            case (ar_state)
                AR_IDLE: begin
                    if (rd_req) begin
                        m_axi_arvalid <= 1'b1;
                        m_axi_arid    <= rd_id_cnt;
                        m_axi_araddr  <= rd_addr;
                        m_axi_arlen   <= rd_len;
                        m_axi_arsize  <= rd_size;
                        m_axi_arburst <= rd_burst;
                        ar_state      <= AR_ACTIVE;
                    end
                end
                AR_ACTIVE: begin
                    if (m_axi_arready) begin
                        m_axi_arvalid <= 1'b0;
                        rd_id_cnt     <= rd_id_cnt + 1;
                        ar_state      <= AR_IDLE;
                    end
                end
            endcase
        end
    end
    
    assign rd_ready = (ar_state == AR_IDLE);
    
    // Fixed signals
    assign m_axi_arlock  = 1'b0;
    assign m_axi_arcache = 4'b0011;
    assign m_axi_arprot  = 3'b000;
    assign m_axi_arqos   = 4'b0000;
    
    //=========================================================================
    // Read Data Channel
    //=========================================================================
    
    assign rd_valid     = m_axi_rvalid;
    assign rd_data      = m_axi_rdata;
    assign rd_resp      = m_axi_rresp;
    assign rd_last      = m_axi_rlast;
    assign m_axi_rready = rd_accept;

endmodule
