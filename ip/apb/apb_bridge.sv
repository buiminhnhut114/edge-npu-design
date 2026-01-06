//=============================================================================
// APB Bridge
// AXI-Lite to APB protocol bridge
//=============================================================================

module apb_bridge #(
    parameter int APB_ADDR_WIDTH = 32,
    parameter int APB_DATA_WIDTH = 32,
    parameter int AXI_ADDR_WIDTH = 32,
    parameter int AXI_DATA_WIDTH = 32
)(
    input  logic                        clk,
    input  logic                        rst_n,
    
    //=========================================================================
    // AXI-Lite Slave Interface
    //=========================================================================
    
    // Write address
    input  logic [AXI_ADDR_WIDTH-1:0]   s_axil_awaddr,
    input  logic [2:0]                  s_axil_awprot,
    input  logic                        s_axil_awvalid,
    output logic                        s_axil_awready,
    
    // Write data
    input  logic [AXI_DATA_WIDTH-1:0]   s_axil_wdata,
    input  logic [AXI_DATA_WIDTH/8-1:0] s_axil_wstrb,
    input  logic                        s_axil_wvalid,
    output logic                        s_axil_wready,
    
    // Write response
    output logic [1:0]                  s_axil_bresp,
    output logic                        s_axil_bvalid,
    input  logic                        s_axil_bready,
    
    // Read address
    input  logic [AXI_ADDR_WIDTH-1:0]   s_axil_araddr,
    input  logic [2:0]                  s_axil_arprot,
    input  logic                        s_axil_arvalid,
    output logic                        s_axil_arready,
    
    // Read data
    output logic [AXI_DATA_WIDTH-1:0]   s_axil_rdata,
    output logic [1:0]                  s_axil_rresp,
    output logic                        s_axil_rvalid,
    input  logic                        s_axil_rready,
    
    //=========================================================================
    // APB Master Interface
    //=========================================================================
    
    output logic [APB_ADDR_WIDTH-1:0]   m_apb_paddr,
    output logic                        m_apb_psel,
    output logic                        m_apb_penable,
    output logic                        m_apb_pwrite,
    output logic [APB_DATA_WIDTH-1:0]   m_apb_pwdata,
    output logic [APB_DATA_WIDTH/8-1:0] m_apb_pstrb,
    output logic [2:0]                  m_apb_pprot,
    input  logic [APB_DATA_WIDTH-1:0]   m_apb_prdata,
    input  logic                        m_apb_pready,
    input  logic                        m_apb_pslverr
);

    //=========================================================================
    // FSM
    //=========================================================================
    
    typedef enum logic [2:0] {
        IDLE,
        WR_SETUP,
        WR_ACCESS,
        WR_RESP,
        RD_SETUP,
        RD_ACCESS,
        RD_RESP
    } state_t;
    
    state_t state;
    
    logic [APB_ADDR_WIDTH-1:0] addr_reg;
    logic [APB_DATA_WIDTH-1:0] wdata_reg;
    logic [APB_DATA_WIDTH-1:0] rdata_reg;
    logic [APB_DATA_WIDTH/8-1:0] strb_reg;
    logic [2:0] prot_reg;
    logic error_reg;
    
    //=========================================================================
    // State Machine
    //=========================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state           <= IDLE;
            s_axil_awready  <= 1'b0;
            s_axil_wready   <= 1'b0;
            s_axil_bvalid   <= 1'b0;
            s_axil_bresp    <= 2'b00;
            s_axil_arready  <= 1'b0;
            s_axil_rvalid   <= 1'b0;
            s_axil_rdata    <= '0;
            s_axil_rresp    <= 2'b00;
            m_apb_psel      <= 1'b0;
            m_apb_penable   <= 1'b0;
            m_apb_pwrite    <= 1'b0;
            m_apb_paddr     <= '0;
            m_apb_pwdata    <= '0;
            m_apb_pstrb     <= '0;
            m_apb_pprot     <= '0;
            addr_reg        <= '0;
            wdata_reg       <= '0;
            rdata_reg       <= '0;
            strb_reg        <= '0;
            prot_reg        <= '0;
            error_reg       <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    s_axil_awready <= 1'b1;
                    s_axil_arready <= 1'b1;
                    s_axil_bvalid  <= 1'b0;
                    s_axil_rvalid  <= 1'b0;
                    
                    // Write has priority
                    if (s_axil_awvalid && s_axil_wvalid) begin
                        s_axil_awready <= 1'b0;
                        s_axil_wready  <= 1'b1;
                        s_axil_arready <= 1'b0;
                        addr_reg       <= s_axil_awaddr[APB_ADDR_WIDTH-1:0];
                        wdata_reg      <= s_axil_wdata;
                        strb_reg       <= s_axil_wstrb;
                        prot_reg       <= s_axil_awprot;
                        state          <= WR_SETUP;
                    end else if (s_axil_arvalid) begin
                        s_axil_arready <= 1'b0;
                        s_axil_awready <= 1'b0;
                        addr_reg       <= s_axil_araddr[APB_ADDR_WIDTH-1:0];
                        prot_reg       <= s_axil_arprot;
                        state          <= RD_SETUP;
                    end
                end
                
                WR_SETUP: begin
                    s_axil_wready <= 1'b0;
                    m_apb_psel    <= 1'b1;
                    m_apb_pwrite  <= 1'b1;
                    m_apb_paddr   <= addr_reg;
                    m_apb_pwdata  <= wdata_reg;
                    m_apb_pstrb   <= strb_reg;
                    m_apb_pprot   <= prot_reg;
                    state         <= WR_ACCESS;
                end
                
                WR_ACCESS: begin
                    m_apb_penable <= 1'b1;
                    if (m_apb_pready) begin
                        m_apb_psel    <= 1'b0;
                        m_apb_penable <= 1'b0;
                        error_reg     <= m_apb_pslverr;
                        state         <= WR_RESP;
                    end
                end
                
                WR_RESP: begin
                    s_axil_bvalid <= 1'b1;
                    s_axil_bresp  <= error_reg ? 2'b10 : 2'b00;
                    if (s_axil_bready) begin
                        s_axil_bvalid <= 1'b0;
                        state         <= IDLE;
                    end
                end
                
                RD_SETUP: begin
                    m_apb_psel   <= 1'b1;
                    m_apb_pwrite <= 1'b0;
                    m_apb_paddr  <= addr_reg;
                    m_apb_pprot  <= prot_reg;
                    state        <= RD_ACCESS;
                end
                
                RD_ACCESS: begin
                    m_apb_penable <= 1'b1;
                    if (m_apb_pready) begin
                        m_apb_psel    <= 1'b0;
                        m_apb_penable <= 1'b0;
                        rdata_reg     <= m_apb_prdata;
                        error_reg     <= m_apb_pslverr;
                        state         <= RD_RESP;
                    end
                end
                
                RD_RESP: begin
                    s_axil_rvalid <= 1'b1;
                    s_axil_rdata  <= rdata_reg;
                    s_axil_rresp  <= error_reg ? 2'b10 : 2'b00;
                    if (s_axil_rready) begin
                        s_axil_rvalid <= 1'b0;
                        state         <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
