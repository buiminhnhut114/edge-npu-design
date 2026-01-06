//=============================================================================
// NPU Top Level
// Top-level integration of all NPU components
//=============================================================================

`include "npu_pkg.sv"

module npu_top
    import npu_pkg::*;
#(
    parameter int PE_ROWS       = 16,
    parameter int PE_COLS       = 16,
    parameter int DATA_WIDTH    = 8,
    parameter int AXI_DATA_W    = 128,
    parameter int AXI_ADDR_W    = 40,
    parameter int AXIL_DATA_W   = 32,
    parameter int AXIL_ADDR_W   = 32
)(
    input  logic                        clk,
    input  logic                        rst_n,
    
    //=========================================================================
    // AXI4 Master Interface (DMA)
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
    // AXI4-Lite Slave Interface (Registers)
    //=========================================================================
    
    // Write Address Channel
    input  logic [AXIL_ADDR_W-1:0]      s_axil_awaddr,
    input  logic                        s_axil_awvalid,
    output logic                        s_axil_awready,
    
    // Write Data Channel
    input  logic [AXIL_DATA_W-1:0]      s_axil_wdata,
    input  logic [AXIL_DATA_W/8-1:0]    s_axil_wstrb,
    input  logic                        s_axil_wvalid,
    output logic                        s_axil_wready,
    
    // Write Response Channel
    output logic [1:0]                  s_axil_bresp,
    output logic                        s_axil_bvalid,
    input  logic                        s_axil_bready,
    
    // Read Address Channel
    input  logic [AXIL_ADDR_W-1:0]      s_axil_araddr,
    input  logic                        s_axil_arvalid,
    output logic                        s_axil_arready,
    
    // Read Data Channel
    output logic [AXIL_DATA_W-1:0]      s_axil_rdata,
    output logic [1:0]                  s_axil_rresp,
    output logic                        s_axil_rvalid,
    input  logic                        s_axil_rready,
    
    //=========================================================================
    // Interrupt
    //=========================================================================
    
    output logic                        irq
);

    //=========================================================================
    // Internal Signals
    //=========================================================================
    
    // Control signals
    logic        npu_enable;
    logic        npu_start;
    logic        npu_done;
    logic        npu_busy;
    logic [31:0] npu_status;
    logic [3:0]  ctrl_state;
    
    // PE Array signals
    logic                           pe_enable;
    logic                           pe_clear_acc;
    logic [PE_ROWS-1:0]             pe_load_weight;
    logic signed [DATA_WIDTH-1:0]   pe_data_in [PE_ROWS];
    logic signed [DATA_WIDTH-1:0]   pe_weight_in [PE_COLS];
    logic signed [31:0]             pe_acc_out [PE_ROWS][PE_COLS];
    logic                           pe_acc_valid [PE_ROWS][PE_COLS];
    
    // Activation signals
    activation_t                    act_type;
    logic                           act_enable;
    logic signed [DATA_WIDTH-1:0]   act_data_in;
    logic signed [DATA_WIDTH-1:0]   act_data_out;
    logic                           act_valid_in;
    logic                           act_valid_out;
    
    // Pooling signals
    pooling_t                       pool_type;
    logic                           pool_start;
    logic                           pool_done;
    logic                           pool_busy;
    logic signed [DATA_WIDTH-1:0]   pool_data_in;
    logic signed [DATA_WIDTH-1:0]   pool_data_out;
    logic                           pool_valid_in;
    logic                           pool_valid_out;
    
    // Memory signals
    logic                           weight_buf_rd_en;
    logic [17:0]                    weight_buf_addr;
    logic [AXI_DATA_W-1:0]          weight_buf_data;
    logic                           weight_buf_valid;
    
    logic                           act_buf_rd_en;
    logic                           act_buf_wr_en;
    logic [17:0]                    act_buf_addr;
    logic [AXI_DATA_W-1:0]          act_buf_rd_data;
    logic [AXI_DATA_W-1:0]          act_buf_wr_data;
    logic                           act_buf_valid;
    
    // DMA signals
    logic                           dma_start;
    logic [1:0]                     dma_channel;
    logic                           dma_busy;
    logic                           dma_done;
    logic                           dma_error;
    dma_desc_t                      dma_desc;
    
    logic                           dma_buf_wr_en;
    logic [17:0]                    dma_buf_wr_addr;
    logic [AXI_DATA_W-1:0]          dma_buf_wr_data;
    logic                           dma_buf_rd_en;
    logic [17:0]                    dma_buf_rd_addr;
    logic [AXI_DATA_W-1:0]          dma_buf_rd_data;
    logic                           dma_buf_rd_valid;
    
    // Instruction signals
    instruction_t                   instruction;
    logic                           inst_valid;
    logic                           inst_ready;
    
    // Interrupt signals
    logic                           irq_done;
    logic                           irq_error;
    
    //=========================================================================
    // Register File
    //=========================================================================
    
    logic [31:0] reg_ctrl;
    logic [31:0] reg_status;
    logic [31:0] reg_irq_en;
    logic [31:0] reg_irq_status;
    logic [31:0] reg_dma_ctrl;
    logic [31:0] reg_dma_src;
    logic [31:0] reg_dma_dst;
    logic [31:0] reg_dma_len;
    
    // AXI-Lite Write
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_ctrl      <= '0;
            reg_irq_en    <= '0;
            reg_dma_ctrl  <= '0;
            reg_dma_src   <= '0;
            reg_dma_dst   <= '0;
            reg_dma_len   <= '0;
        end else if (s_axil_awvalid && s_axil_wvalid && s_axil_awready && s_axil_wready) begin
            case (s_axil_awaddr[11:0])
                REG_CTRL:       reg_ctrl     <= s_axil_wdata;
                REG_IRQ_EN:     reg_irq_en   <= s_axil_wdata;
                REG_DMA_CTRL:   reg_dma_ctrl <= s_axil_wdata;
                REG_DMA_SRC:    reg_dma_src  <= s_axil_wdata;
                REG_DMA_DST:    reg_dma_dst  <= s_axil_wdata;
                REG_DMA_LEN:    reg_dma_len  <= s_axil_wdata;
            endcase
        end
        
        // Auto-clear start bits
        if (npu_start)
            reg_ctrl[1] <= 1'b0;
        if (dma_start)
            reg_dma_ctrl[0] <= 1'b0;
    end
    
    // Interrupt status
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_irq_status <= '0;
        end else begin
            if (irq_done)
                reg_irq_status[0] <= 1'b1;
            if (irq_error)
                reg_irq_status[1] <= 1'b1;
            if (dma_done)
                reg_irq_status[2] <= 1'b1;
            if (dma_error)
                reg_irq_status[3] <= 1'b1;
            
            // Clear on write
            if (s_axil_awvalid && s_axil_wvalid && s_axil_awaddr[11:0] == REG_IRQ_STATUS)
                reg_irq_status <= reg_irq_status & ~s_axil_wdata;
        end
    end
    
    // AXI-Lite Read - combinational decode for immediate response
    always_comb begin
        case (s_axil_araddr[11:0])
            REG_CTRL:       s_axil_rdata = reg_ctrl;
            REG_STATUS:     s_axil_rdata = npu_status;
            REG_IRQ_EN:     s_axil_rdata = reg_irq_en;
            REG_IRQ_STATUS: s_axil_rdata = reg_irq_status;
            REG_VERSION:    s_axil_rdata = NPU_VERSION;
            REG_CONFIG:     s_axil_rdata = {16'(PE_ROWS), 16'(PE_COLS)};
            REG_DMA_CTRL:   s_axil_rdata = reg_dma_ctrl;
            REG_DMA_STATUS: s_axil_rdata = {30'b0, dma_done, dma_busy};
            REG_DMA_SRC:    s_axil_rdata = reg_dma_src;
            REG_DMA_DST:    s_axil_rdata = reg_dma_dst;
            REG_DMA_LEN:    s_axil_rdata = reg_dma_len;
            default:        s_axil_rdata = '0;
        endcase
    end
    
    // AXI-Lite handshake - always ready
    assign s_axil_awready = 1'b1;
    assign s_axil_wready  = 1'b1;
    assign s_axil_bresp   = 2'b00;
    assign s_axil_bvalid  = 1'b1;
    assign s_axil_arready = 1'b1;
    assign s_axil_rresp   = 2'b00;
    assign s_axil_rvalid  = 1'b1;
    
    //=========================================================================
    // Control Logic
    //=========================================================================
    
    assign npu_enable = reg_ctrl[0];
    assign npu_start  = reg_ctrl[1] && npu_enable;
    assign npu_status = {24'b0, ctrl_state, 2'b0, npu_done, npu_busy};
    
    // DMA descriptor from registers
    assign dma_desc.src_addr   = {8'b0, reg_dma_src};
    assign dma_desc.dst_addr   = {8'b0, reg_dma_dst};
    assign dma_desc.length     = reg_dma_len[23:0];
    assign dma_desc.src_stride = '0;
    assign dma_desc.dst_stride = '0;
    assign dma_desc.flags      = reg_dma_ctrl[15:8];
    
    //=========================================================================
    // NPU Controller
    //=========================================================================
    
    npu_controller #(
        .PE_ROWS (PE_ROWS),
        .PE_COLS (PE_COLS)
    ) u_controller (
        .clk            (clk),
        .rst_n          (rst_n),
        .start          (npu_start),
        .enable         (npu_enable),
        .busy           (npu_busy),
        .done           (npu_done),
        .state_out      (ctrl_state),
        .instruction    (instruction),
        .inst_valid     (inst_valid),
        .inst_ready     (inst_ready),
        .pe_enable      (pe_enable),
        .pe_clear_acc   (pe_clear_acc),
        .pe_load_weight (pe_load_weight),
        .act_type       (act_type),
        .act_enable     (act_enable),
        .pool_type      (pool_type),
        .pool_start     (pool_start),
        .pool_done      (pool_done),
        .weight_buf_rd_en (weight_buf_rd_en),
        .weight_buf_addr  (weight_buf_addr),
        .act_buf_rd_en    (act_buf_rd_en),
        .act_buf_wr_en    (act_buf_wr_en),
        .act_buf_addr     (act_buf_addr),
        .dma_start      (dma_start),
        .dma_channel    (dma_channel),
        .dma_done       (dma_done),
        .irq_done       (irq_done),
        .irq_error      (irq_error)
    );
    
    //=========================================================================
    // PE Array
    //=========================================================================
    
    pe_array #(
        .ROWS         (PE_ROWS),
        .COLS         (PE_COLS),
        .DATA_WIDTH   (DATA_WIDTH),
        .WEIGHT_WIDTH (DATA_WIDTH),
        .ACC_WIDTH    (32)
    ) u_pe_array (
        .clk          (clk),
        .rst_n        (rst_n),
        .enable       (pe_enable),
        .clear_acc    (pe_clear_acc),
        .load_weight  (pe_load_weight),
        .data_in      (pe_data_in),
        .weight_in    (pe_weight_in),
        .acc_out      (pe_acc_out),
        .acc_valid    (pe_acc_valid)
    );
    
    //=========================================================================
    // Activation Unit
    //=========================================================================
    
    activation_unit #(
        .DATA_WIDTH (DATA_WIDTH)
    ) u_activation (
        .clk        (clk),
        .rst_n      (rst_n),
        .act_type   (act_type),
        .valid_in   (act_valid_in),
        .data_in    (act_data_in),
        .data_out   (act_data_out),
        .valid_out  (act_valid_out)
    );
    
    //=========================================================================
    // Pooling Unit
    //=========================================================================
    
    pooling_unit #(
        .DATA_WIDTH (DATA_WIDTH)
    ) u_pooling (
        .clk         (clk),
        .rst_n       (rst_n),
        .pool_type   (pool_type),
        .kernel_size (2'b00),  // 2x2
        .start       (pool_start),
        .done        (pool_done),
        .busy        (pool_busy),
        .valid_in    (pool_valid_in),
        .data_in     (pool_data_in),
        .valid_out   (pool_valid_out),
        .data_out    (pool_data_out)
    );
    
    //=========================================================================
    // Weight Buffer
    //=========================================================================
    
    weight_buffer #(
        .DATA_WIDTH (AXI_DATA_W),
        .SIZE_KB    (256)
    ) u_weight_buffer (
        .clk      (clk),
        .rst_n    (rst_n),
        .wr_en    (dma_buf_wr_en && dma_channel == 2'b00),
        .wr_addr  (dma_buf_wr_addr),
        .wr_data  (dma_buf_wr_data),
        .rd_en    (weight_buf_rd_en),
        .rd_addr  (weight_buf_addr),
        .rd_data  (weight_buf_data),
        .rd_valid (weight_buf_valid)
    );
    
    //=========================================================================
    // Activation Buffer
    //=========================================================================
    
    activation_buffer #(
        .DATA_WIDTH (AXI_DATA_W),
        .SIZE_KB    (256)
    ) u_act_buffer (
        .clk     (clk),
        .rst_n   (rst_n),
        .a_en    (act_buf_wr_en || (dma_buf_wr_en && dma_channel == 2'b01)),
        .a_we    (act_buf_wr_en || (dma_buf_wr_en && dma_channel == 2'b01)),
        .a_addr  (dma_buf_wr_en ? dma_buf_wr_addr : act_buf_addr),
        .a_wdata (dma_buf_wr_en ? dma_buf_wr_data : act_buf_wr_data),
        .a_rdata (),
        .b_en    (act_buf_rd_en),
        .b_addr  (act_buf_addr),
        .b_rdata (act_buf_rd_data),
        .b_valid (act_buf_valid)
    );
    
    //=========================================================================
    // DMA Engine
    //=========================================================================
    
    dma_engine #(
        .AXI_DATA_W (AXI_DATA_W),
        .AXI_ADDR_W (AXI_ADDR_W)
    ) u_dma (
        .clk            (clk),
        .rst_n          (rst_n),
        .start          (reg_dma_ctrl[0]),
        .channel_sel    (dma_channel),
        .descriptor     (dma_desc),
        .busy           (dma_busy),
        .done           (dma_done),
        .error          (dma_error),
        .m_axi_awaddr   (m_axi_awaddr),
        .m_axi_awlen    (m_axi_awlen),
        .m_axi_awsize   (m_axi_awsize),
        .m_axi_awburst  (m_axi_awburst),
        .m_axi_awvalid  (m_axi_awvalid),
        .m_axi_awready  (m_axi_awready),
        .m_axi_wdata    (m_axi_wdata),
        .m_axi_wstrb    (m_axi_wstrb),
        .m_axi_wlast    (m_axi_wlast),
        .m_axi_wvalid   (m_axi_wvalid),
        .m_axi_wready   (m_axi_wready),
        .m_axi_bresp    (m_axi_bresp),
        .m_axi_bvalid   (m_axi_bvalid),
        .m_axi_bready   (m_axi_bready),
        .m_axi_araddr   (m_axi_araddr),
        .m_axi_arlen    (m_axi_arlen),
        .m_axi_arsize   (m_axi_arsize),
        .m_axi_arburst  (m_axi_arburst),
        .m_axi_arvalid  (m_axi_arvalid),
        .m_axi_arready  (m_axi_arready),
        .m_axi_rdata    (m_axi_rdata),
        .m_axi_rresp    (m_axi_rresp),
        .m_axi_rlast    (m_axi_rlast),
        .m_axi_rvalid   (m_axi_rvalid),
        .m_axi_rready   (m_axi_rready),
        .buf_wr_en      (dma_buf_wr_en),
        .buf_wr_addr    (dma_buf_wr_addr),
        .buf_wr_data    (dma_buf_wr_data),
        .buf_rd_en      (dma_buf_rd_en),
        .buf_rd_addr    (dma_buf_rd_addr),
        .buf_rd_data    (dma_buf_rd_data),
        .buf_rd_valid   (dma_buf_rd_valid)
    );
    
    //=========================================================================
    // Data Path Connections (simplified)
    //=========================================================================
    
    // Unpack weight buffer data to PE weight inputs
    generate
        for (genvar i = 0; i < PE_COLS; i++) begin : gen_weight_unpack
            assign pe_weight_in[i] = weight_buf_data[i*DATA_WIDTH +: DATA_WIDTH];
        end
    endgenerate
    
    // Unpack activation buffer data to PE data inputs
    generate
        for (genvar i = 0; i < PE_ROWS; i++) begin : gen_data_unpack
            assign pe_data_in[i] = act_buf_rd_data[i*DATA_WIDTH +: DATA_WIDTH];
        end
    endgenerate
    
    // Activation unit input (from first PE row output)
    assign act_data_in = pe_acc_out[0][0][DATA_WIDTH-1:0];
    assign act_valid_in = pe_acc_valid[0][0] && act_enable;
    
    // Pooling unit input
    assign pool_data_in = act_data_out;
    assign pool_valid_in = act_valid_out;
    
    // Instruction interface (simplified - would connect to instruction buffer)
    assign instruction = '0;
    assign inst_valid = 1'b0;
    
    //=========================================================================
    // Interrupt Generation
    //=========================================================================
    
    assign irq = |(reg_irq_status & reg_irq_en);

endmodule
