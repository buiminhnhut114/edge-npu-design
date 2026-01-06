//=============================================================================
// DMA Engine
// 4-channel DMA for high-bandwidth data movement
//=============================================================================

module dma_engine
    import npu_pkg::*;
#(
    parameter int AXI_DATA_W = 128,
    parameter int AXI_ADDR_W = 40,
    parameter int NUM_CHANNELS = 4
)(
    input  logic                        clk,
    input  logic                        rst_n,
    
    //=========================================================================
    // Control Interface
    //=========================================================================
    
    input  logic                        start,
    input  logic [1:0]                  channel_sel,
    input  dma_desc_t                   descriptor,
    output logic                        busy,
    output logic                        done,
    output logic                        error,
    
    //=========================================================================
    // AXI4 Master Interface
    //=========================================================================
    
    // Write Address Channel
    output logic [AXI_ADDR_W-1:0]       m_axi_awaddr,
    output logic [7:0]                  m_axi_awlen,
    output logic [2:0]                  m_axi_awsize,
    output logic [1:0]                  m_axi_awburst,
    output logic                        m_axi_awvalid,
    input  logic                        m_axi_awready,
    
    // Write Data Channel
    output logic [AXI_DATA_W-1:0]       m_axi_wdata,
    output logic [AXI_DATA_W/8-1:0]     m_axi_wstrb,
    output logic                        m_axi_wlast,
    output logic                        m_axi_wvalid,
    input  logic                        m_axi_wready,
    
    // Write Response Channel
    input  logic [1:0]                  m_axi_bresp,
    input  logic                        m_axi_bvalid,
    output logic                        m_axi_bready,
    
    // Read Address Channel
    output logic [AXI_ADDR_W-1:0]       m_axi_araddr,
    output logic [7:0]                  m_axi_arlen,
    output logic [2:0]                  m_axi_arsize,
    output logic [1:0]                  m_axi_arburst,
    output logic                        m_axi_arvalid,
    input  logic                        m_axi_arready,
    
    // Read Data Channel
    input  logic [AXI_DATA_W-1:0]       m_axi_rdata,
    input  logic [1:0]                  m_axi_rresp,
    input  logic                        m_axi_rlast,
    input  logic                        m_axi_rvalid,
    output logic                        m_axi_rready,
    
    //=========================================================================
    // Internal Buffer Interface
    //=========================================================================
    
    output logic                        buf_wr_en,
    output logic [17:0]                 buf_wr_addr,
    output logic [AXI_DATA_W-1:0]       buf_wr_data,
    
    output logic                        buf_rd_en,
    output logic [17:0]                 buf_rd_addr,
    input  logic [AXI_DATA_W-1:0]       buf_rd_data,
    input  logic                        buf_rd_valid
);

    //=========================================================================
    // State Machine
    //=========================================================================
    
    typedef enum logic [2:0] {
        IDLE,
        READ_ADDR,
        READ_DATA,
        WRITE_ADDR,
        WRITE_DATA,
        WRITE_RESP,
        COMPLETE
    } state_t;
    
    state_t state, next_state;
    
    //=========================================================================
    // Internal Registers
    //=========================================================================
    
    dma_desc_t          desc_reg;
    logic [39:0]        src_addr_reg;
    logic [39:0]        dst_addr_reg;
    logic [23:0]        remaining;
    logic [7:0]         burst_count;
    logic               is_read;  // 1=read from external, 0=write to external
    
    localparam int BURST_SIZE = AXI_DATA_W / 8;  // Bytes per beat
    localparam int MAX_BURST_LEN = 256;
    
    //=========================================================================
    // State Machine
    //=========================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end
    
    always_comb begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    if (is_read)
                        next_state = READ_ADDR;
                    else
                        next_state = WRITE_ADDR;
                end
            end
            READ_ADDR: begin
                if (m_axi_arvalid && m_axi_arready)
                    next_state = READ_DATA;
            end
            READ_DATA: begin
                if (m_axi_rvalid && m_axi_rlast) begin
                    if (remaining == 0)
                        next_state = COMPLETE;
                    else
                        next_state = READ_ADDR;
                end
            end
            WRITE_ADDR: begin
                if (m_axi_awvalid && m_axi_awready)
                    next_state = WRITE_DATA;
            end
            WRITE_DATA: begin
                if (m_axi_wvalid && m_axi_wready && m_axi_wlast)
                    next_state = WRITE_RESP;
            end
            WRITE_RESP: begin
                if (m_axi_bvalid) begin
                    if (remaining == 0)
                        next_state = COMPLETE;
                    else
                        next_state = WRITE_ADDR;
                end
            end
            COMPLETE: begin
                next_state = IDLE;
            end
        endcase
    end
    
    //=========================================================================
    // Descriptor Latch
    //=========================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            desc_reg     <= '0;
            src_addr_reg <= '0;
            dst_addr_reg <= '0;
            remaining    <= '0;
            is_read      <= 1'b0;
        end else if (state == IDLE && start) begin
            desc_reg     <= descriptor;
            src_addr_reg <= descriptor.src_addr;
            dst_addr_reg <= descriptor.dst_addr;
            remaining    <= descriptor.length;
            is_read      <= descriptor.flags[0];  // Bit 0: 1=read, 0=write
        end else if (state == READ_DATA && m_axi_rvalid) begin
            src_addr_reg <= src_addr_reg + BURST_SIZE;
            dst_addr_reg <= dst_addr_reg + BURST_SIZE;
            if (remaining >= BURST_SIZE)
                remaining <= remaining - BURST_SIZE;
            else
                remaining <= '0;
        end else if (state == WRITE_DATA && m_axi_wvalid && m_axi_wready) begin
            src_addr_reg <= src_addr_reg + BURST_SIZE;
            dst_addr_reg <= dst_addr_reg + BURST_SIZE;
            if (remaining >= BURST_SIZE)
                remaining <= remaining - BURST_SIZE;
            else
                remaining <= '0;
        end
    end
    
    //=========================================================================
    // Burst Length Calculation
    //=========================================================================
    
    always_comb begin
        if (remaining >= MAX_BURST_LEN * BURST_SIZE)
            burst_count = MAX_BURST_LEN - 1;
        else
            burst_count = (remaining / BURST_SIZE) - 1;
    end
    
    //=========================================================================
    // AXI Read Channel
    //=========================================================================
    
    assign m_axi_araddr  = src_addr_reg;
    assign m_axi_arlen   = burst_count;
    assign m_axi_arsize  = $clog2(BURST_SIZE);
    assign m_axi_arburst = 2'b01;  // INCR
    assign m_axi_arvalid = (state == READ_ADDR);
    assign m_axi_rready  = (state == READ_DATA);
    
    //=========================================================================
    // AXI Write Channel
    //=========================================================================
    
    logic [7:0] write_beat_count;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            write_beat_count <= '0;
        else if (state == WRITE_ADDR)
            write_beat_count <= '0;
        else if (state == WRITE_DATA && m_axi_wvalid && m_axi_wready)
            write_beat_count <= write_beat_count + 1'b1;
    end
    
    assign m_axi_awaddr  = dst_addr_reg;
    assign m_axi_awlen   = burst_count;
    assign m_axi_awsize  = $clog2(BURST_SIZE);
    assign m_axi_awburst = 2'b01;  // INCR
    assign m_axi_awvalid = (state == WRITE_ADDR);
    assign m_axi_wdata   = buf_rd_data;
    assign m_axi_wstrb   = {(AXI_DATA_W/8){1'b1}};
    assign m_axi_wlast   = (write_beat_count == burst_count);
    assign m_axi_wvalid  = (state == WRITE_DATA) && buf_rd_valid;
    assign m_axi_bready  = (state == WRITE_RESP);
    
    //=========================================================================
    // Buffer Interface
    //=========================================================================
    
    assign buf_wr_en   = (state == READ_DATA) && m_axi_rvalid;
    assign buf_wr_addr = dst_addr_reg[17:0];
    assign buf_wr_data = m_axi_rdata;
    
    assign buf_rd_en   = (state == WRITE_DATA);
    assign buf_rd_addr = src_addr_reg[17:0];
    
    //=========================================================================
    // Status
    //=========================================================================
    
    assign busy  = (state != IDLE);
    assign done  = (state == COMPLETE);
    assign error = (m_axi_bresp[1] && m_axi_bvalid) || (m_axi_rresp[1] && m_axi_rvalid);

endmodule
