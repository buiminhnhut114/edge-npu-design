//=============================================================================
// NPU Top Level V2
// Enhanced version with all integrated modules
//=============================================================================

`include "npu_pkg.sv"

module npu_top_v2
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
    
    // AXI4 Master Interface (DMA)
    output logic [AXI_ADDR_W-1:0]       m_axi_awaddr,
    output logic [7:0]                  m_axi_awlen,
    output logic [2:0]                  m_axi_awsize,
    output logic [1:0]                  m_axi_awburst,
    output logic                        m_axi_awvalid,
    input  logic                        m_axi_awready,
    output logic [AXI_DATA_W-1:0]       m_axi_wdata,
    output logic [AXI_DATA_W/8-1:0]     m_axi_wstrb,
    output logic                        m_axi_wlast,
    output logic                        m_axi_wvalid,
    input  logic                        m_axi_wready,
    input  logic [1:0]                  m_axi_bresp,
    input  logic                        m_axi_bvalid,
    output logic                        m_axi_bready,
    output logic [AXI_ADDR_W-1:0]       m_axi_araddr,
    output logic [7:0]                  m_axi_arlen,
    output logic [2:0]                  m_axi_arsize,
    output logic [1:0]                  m_axi_arburst,
    output logic                        m_axi_arvalid,
    input  logic                        m_axi_arready,
    input  logic [AXI_DATA_W-1:0]       m_axi_rdata,
    input  logic [1:0]                  m_axi_rresp,
    input  logic                        m_axi_rlast,
    input  logic                        m_axi_rvalid,
    output logic                        m_axi_rready,

    // AXI4-Lite Slave Interface (Registers)
    input  logic [AXIL_ADDR_W-1:0]      s_axil_awaddr,
    input  logic                        s_axil_awvalid,
    output logic                        s_axil_awready,
    input  logic [AXIL_DATA_W-1:0]      s_axil_wdata,
    input  logic [AXIL_DATA_W/8-1:0]    s_axil_wstrb,
    input  logic                        s_axil_wvalid,
    output logic                        s_axil_wready,
    output logic [1:0]                  s_axil_bresp,
    output logic                        s_axil_bvalid,
    input  logic                        s_axil_bready,
    input  logic [AXIL_ADDR_W-1:0]      s_axil_araddr,
    input  logic                        s_axil_arvalid,
    output logic                        s_axil_arready,
    output logic [AXIL_DATA_W-1:0]      s_axil_rdata,
    output logic [1:0]                  s_axil_rresp,
    output logic                        s_axil_rvalid,
    input  logic                        s_axil_rready,
    
    // JTAG Debug Interface
    input  logic                        tck,
    input  logic                        tms,
    input  logic                        tdi,
    output logic                        tdo,
    input  logic                        trst_n,
    
    // Interrupt
    output logic                        irq
);

    //=========================================================================
    // Internal Signals - Core Control
    //=========================================================================
    logic        npu_enable, npu_start, npu_done, npu_busy;
    logic [31:0] npu_status;
    logic [3:0]  ctrl_state;
    
    // Instruction pipeline
    instruction_t inst_fetched, inst_decoded, inst_scheduled;
    logic         inst_fetch_valid, inst_decode_valid, inst_sched_valid;
    logic         inst_fetch_ready, inst_decode_ready, inst_sched_ready;
    
    // Decoded control signals
    opcode_t      decoded_opcode;
    logic         is_compute, is_memory, is_activation, is_pooling, is_elementwise;

    //=========================================================================
    // Internal Signals - Compute Units
    //=========================================================================
    
    // PE Array
    logic                           pe_enable, pe_clear_acc;
    logic [PE_ROWS-1:0]             pe_load_weight;
    logic signed [DATA_WIDTH-1:0]   pe_data_in [PE_ROWS];
    logic signed [DATA_WIDTH-1:0]   pe_weight_in [PE_COLS];
    logic signed [31:0]             pe_acc_out [PE_ROWS][PE_COLS];
    logic                           pe_acc_valid [PE_ROWS][PE_COLS];
    
    // Convolution Controller
    logic                           conv_start, conv_done, conv_busy;
    conv_param_t                    conv_params;
    
    // Activation Unit
    activation_t                    act_type;
    logic                           act_enable;
    logic signed [DATA_WIDTH-1:0]   act_data_in, act_data_out;
    logic                           act_valid_in, act_valid_out;
    
    // Batch Normalization
    logic                           bn_enable, bn_load_params, bn_ready;
    logic [7:0]                     bn_channel_idx, bn_num_channels;
    logic signed [DATA_WIDTH-1:0]   bn_data_in, bn_data_out;
    logic                           bn_valid_in, bn_valid_out;
    
    // Pooling Unit
    pooling_t                       pool_type;
    logic                           pool_start, pool_done, pool_busy;
    logic signed [DATA_WIDTH-1:0]   pool_data_in, pool_data_out;
    logic                           pool_valid_in, pool_valid_out;
    
    // Softmax Unit
    logic                           softmax_start, softmax_done, softmax_busy;
    logic [9:0]                     softmax_num_classes;
    logic signed [DATA_WIDTH-1:0]   softmax_data_in;
    logic [DATA_WIDTH-1:0]          softmax_data_out;
    logic                           softmax_valid_in, softmax_valid_out;
    
    // Element-wise Unit
    logic [2:0]                     ew_op_type;
    logic                           ew_enable;
    logic signed [DATA_WIDTH-1:0]   ew_data_a, ew_data_b, ew_data_out;
    logic                           ew_valid_a, ew_valid_b, ew_valid_out;

    //=========================================================================
    // Internal Signals - Memory & DMA
    //=========================================================================
    
    // Weight Buffer
    logic                           weight_buf_rd_en;
    logic [17:0]                    weight_buf_addr;
    logic [AXI_DATA_W-1:0]          weight_buf_data;
    logic                           weight_buf_valid;
    
    // Activation Buffer
    logic                           act_buf_rd_en, act_buf_wr_en;
    logic [17:0]                    act_buf_addr;
    logic [AXI_DATA_W-1:0]          act_buf_rd_data, act_buf_wr_data;
    logic                           act_buf_valid;
    
    // DMA
    logic                           dma_start, dma_busy, dma_done, dma_error;
    logic [1:0]                     dma_channel;
    dma_desc_t                      dma_desc;
    logic                           dma_buf_wr_en, dma_buf_rd_en;
    logic [17:0]                    dma_buf_wr_addr, dma_buf_rd_addr;
    logic [AXI_DATA_W-1:0]          dma_buf_wr_data, dma_buf_rd_data;
    logic                           dma_buf_rd_valid;
    
    // Debug Interface
    logic                           dbg_req, dbg_we, dbg_ack, dbg_err;
    logic [31:0]                    dbg_addr, dbg_wdata, dbg_rdata;
    logic                           dbg_halt, dbg_resume, dbg_step, dbg_active;
    logic                           npu_halted;
    
    // Interrupt
    logic                           irq_done, irq_error;
    
    //=========================================================================
    // Register File
    //=========================================================================
    
    logic [31:0] reg_ctrl, reg_status, reg_irq_en, reg_irq_status;
    logic [31:0] reg_dma_ctrl, reg_dma_src, reg_dma_dst, reg_dma_len;
    logic [31:0] reg_conv_ctrl, reg_conv_param0, reg_conv_param1;
    
    // Extended register addresses
    localparam logic [11:0] REG_CONV_CTRL   = 12'h200;
    localparam logic [11:0] REG_CONV_PARAM0 = 12'h204;
    localparam logic [11:0] REG_CONV_PARAM1 = 12'h208;
    localparam logic [11:0] REG_BN_CTRL     = 12'h210;
    localparam logic [11:0] REG_SOFTMAX     = 12'h220;
    localparam logic [11:0] REG_ELEMWISE    = 12'h230;

    //=========================================================================
    // AXI-Lite Register Access
    //=========================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_ctrl       <= '0;
            reg_irq_en     <= '0;
            reg_dma_ctrl   <= '0;
            reg_dma_src    <= '0;
            reg_dma_dst    <= '0;
            reg_dma_len    <= '0;
            reg_conv_ctrl  <= '0;
            reg_conv_param0<= '0;
            reg_conv_param1<= '0;
        end else if (s_axil_awvalid && s_axil_wvalid && s_axil_awready) begin
            case (s_axil_awaddr[11:0])
                REG_CTRL:       reg_ctrl      <= s_axil_wdata;
                REG_IRQ_EN:     reg_irq_en    <= s_axil_wdata;
                REG_DMA_CTRL:   reg_dma_ctrl  <= s_axil_wdata;
                REG_DMA_SRC:    reg_dma_src   <= s_axil_wdata;
                REG_DMA_DST:    reg_dma_dst   <= s_axil_wdata;
                REG_DMA_LEN:    reg_dma_len   <= s_axil_wdata;
                REG_CONV_CTRL:  reg_conv_ctrl <= s_axil_wdata;
                REG_CONV_PARAM0:reg_conv_param0<= s_axil_wdata;
                REG_CONV_PARAM1:reg_conv_param1<= s_axil_wdata;
            endcase
        end
        // Auto-clear start bits
        if (npu_start) reg_ctrl[1] <= 1'b0;
        if (conv_start) reg_conv_ctrl[0] <= 1'b0;
    end
    
    // Interrupt status
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) reg_irq_status <= '0;
        else begin
            if (irq_done)  reg_irq_status[0] <= 1'b1;
            if (irq_error) reg_irq_status[1] <= 1'b1;
            if (dma_done)  reg_irq_status[2] <= 1'b1;
            if (dma_error) reg_irq_status[3] <= 1'b1;
            if (conv_done) reg_irq_status[4] <= 1'b1;
            if (s_axil_awvalid && s_axil_wvalid && s_axil_awaddr[11:0] == REG_IRQ_STATUS)
                reg_irq_status <= reg_irq_status & ~s_axil_wdata;
        end
    end
    
    // AXI-Lite handshake
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
    
    assign npu_enable = reg_ctrl[0] && !dbg_halt;
    assign npu_start  = reg_ctrl[1] && npu_enable;
    assign conv_start = reg_conv_ctrl[0];
    assign npu_status = {20'b0, conv_busy, softmax_busy, pool_busy, bn_enable,
                         ctrl_state, 2'b0, npu_done, npu_busy};
    assign npu_halted = dbg_halt;
    
    // DMA descriptor
    assign dma_desc.src_addr   = {8'b0, reg_dma_src};
    assign dma_desc.dst_addr   = {8'b0, reg_dma_dst};
    assign dma_desc.length     = reg_dma_len[23:0];
    assign dma_desc.src_stride = '0;
    assign dma_desc.dst_stride = '0;
    assign dma_desc.flags      = reg_dma_ctrl[15:8];
    
    // Conv parameters from registers
    assign conv_params.input_height    = reg_conv_param0[15:0];
    assign conv_params.input_width     = reg_conv_param0[31:16];
    assign conv_params.input_channels  = reg_conv_param1[15:0];
    assign conv_params.output_channels = reg_conv_param1[31:16];
    assign conv_params.kernel_height   = reg_conv_ctrl[7:4];
    assign conv_params.kernel_width    = reg_conv_ctrl[7:4];
    assign conv_params.stride_h        = reg_conv_ctrl[11:8];
    assign conv_params.stride_w        = reg_conv_ctrl[11:8];
    assign conv_params.pad_top         = reg_conv_ctrl[15:12];
    assign conv_params.pad_bottom      = reg_conv_ctrl[15:12];
    assign conv_params.pad_left        = reg_conv_ctrl[15:12];
    assign conv_params.pad_right       = reg_conv_ctrl[15:12];
    assign conv_params.dilation_h      = 4'd1;
    assign conv_params.dilation_w      = 4'd1;
    assign conv_params.activation      = activation_t'(reg_conv_ctrl[18:16]);
    
    //=========================================================================
    // Instruction Scheduler
    //=========================================================================
    
    instruction_scheduler u_scheduler (
        .clk          (clk),
        .rst_n        (rst_n),
        .inst_valid   (inst_fetch_valid),
        .inst_in      (inst_fetched),
        .inst_ready   (inst_fetch_ready),
        .sched_valid  (inst_sched_valid),
        .sched_inst   (inst_scheduled),
        .sched_ready  (inst_sched_ready),
        .conv_busy    (conv_busy),
        .conv_done    (conv_done),
        .pool_busy    (pool_busy),
        .pool_done    (pool_done),
        .act_busy     (1'b0),
        .dma_busy     (dma_busy),
        .dma_done     (dma_done),
        .queue_empty  (),
        .queue_full   (),
        .queue_count  ()
    );

    //=========================================================================
    // Instruction Decoder
    //=========================================================================
    
    instruction_decoder u_decoder (
        .clk            (clk),
        .rst_n          (rst_n),
        .inst_valid     (inst_sched_valid),
        .inst_in        (inst_scheduled),
        .inst_ready     (inst_sched_ready),
        .opcode         (decoded_opcode),
        .dst_addr       (),
        .src0_addr      (),
        .src1_addr      (),
        .immediate      (),
        .flags          (),
        .is_compute     (is_compute),
        .is_memory      (is_memory),
        .is_activation  (is_activation),
        .is_pooling     (is_pooling),
        .is_elementwise (is_elementwise),
        .is_sync        (),
        .kernel_size    (),
        .stride         (),
        .padding        (),
        .act_type       (act_type),
        .pool_type      (pool_type),
        .decode_valid   (inst_decode_valid),
        .decode_error   ()
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
    // Convolution Controller
    //=========================================================================
    
    conv_controller #(
        .PE_ROWS    (PE_ROWS),
        .PE_COLS    (PE_COLS),
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (18)
    ) u_conv_ctrl (
        .clk            (clk),
        .rst_n          (rst_n),
        .start          (conv_start),
        .conv_params    (conv_params),
        .done           (conv_done),
        .busy           (conv_busy),
        .weight_rd_en   (weight_buf_rd_en),
        .weight_rd_addr (weight_buf_addr),
        .weight_rd_data (weight_buf_data),
        .weight_rd_valid(weight_buf_valid),
        .act_rd_en      (act_buf_rd_en),
        .act_rd_addr    (act_buf_addr),
        .act_rd_data    (act_buf_rd_data),
        .act_rd_valid   (act_buf_valid),
        .act_wr_en      (act_buf_wr_en),
        .act_wr_addr    (),
        .act_wr_data    (act_buf_wr_data),
        .pe_enable      (pe_enable),
        .pe_clear_acc   (pe_clear_acc),
        .pe_load_weight (pe_load_weight),
        .pe_data_in     (pe_data_in),
        .pe_weight_in   (pe_weight_in),
        .pe_acc_out     (pe_acc_out),
        .pe_acc_valid   (pe_acc_valid),
        .act_type       (),
        .act_enable     (act_enable)
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
    // Batch Normalization Unit
    //=========================================================================
    
    batchnorm_unit #(
        .DATA_WIDTH   (DATA_WIDTH),
        .SCALE_WIDTH  (16),
        .MAX_CHANNELS (256)
    ) u_batchnorm (
        .clk           (clk),
        .rst_n         (rst_n),
        .enable        (bn_enable),
        .load_params   (bn_load_params),
        .channel_idx   (bn_channel_idx),
        .num_channels  (bn_num_channels),
        .param_valid   (1'b0),
        .scale_in      ('0),
        .bias_in       ('0),
        .valid_in      (bn_valid_in),
        .data_in       (bn_data_in),
        .valid_out     (bn_valid_out),
        .data_out      (bn_data_out),
        .ready         (bn_ready),
        .params_loaded ()
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
        .kernel_size (2'b00),
        .start       (pool_start),
        .done        (pool_done),
        .busy        (pool_busy),
        .valid_in    (pool_valid_in),
        .data_in     (pool_data_in),
        .valid_out   (pool_valid_out),
        .data_out    (pool_data_out)
    );
    
    //=========================================================================
    // Softmax Unit
    //=========================================================================
    
    softmax_unit #(
        .DATA_WIDTH  (DATA_WIDTH),
        .OUT_WIDTH   (DATA_WIDTH),
        .MAX_CLASSES (1024)
    ) u_softmax (
        .clk         (clk),
        .rst_n       (rst_n),
        .start       (softmax_start),
        .num_classes (softmax_num_classes),
        .done        (softmax_done),
        .busy        (softmax_busy),
        .valid_in    (softmax_valid_in),
        .data_in     (softmax_data_in),
        .valid_out   (softmax_valid_out),
        .data_out    (softmax_data_out)
    );

    //=========================================================================
    // Element-wise Unit
    //=========================================================================
    
    elementwise_unit #(
        .DATA_WIDTH (DATA_WIDTH)
    ) u_elementwise (
        .clk       (clk),
        .rst_n     (rst_n),
        .op_type   (ew_op_type),
        .enable    (ew_enable),
        .valid_a   (ew_valid_a),
        .data_a    (ew_data_a),
        .valid_b   (ew_valid_b),
        .data_b    (ew_data_b),
        .valid_out (ew_valid_out),
        .data_out  (ew_data_out)
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
    // Debug Interface (JTAG)
    //=========================================================================
    
    npu_debug_if #(
        .ADDR_WIDTH (32),
        .DATA_WIDTH (32)
    ) u_debug (
        .clk        (clk),
        .rst_n      (rst_n),
        .tck        (tck),
        .tms        (tms),
        .tdi        (tdi),
        .tdo        (tdo),
        .trst_n     (trst_n),
        .dbg_req    (dbg_req),
        .dbg_we     (dbg_we),
        .dbg_addr   (dbg_addr),
        .dbg_wdata  (dbg_wdata),
        .dbg_rdata  (dbg_rdata),
        .dbg_ack    (dbg_ack),
        .dbg_err    (dbg_err),
        .mem_req    (),
        .mem_we     (),
        .mem_addr   (),
        .mem_wdata  (),
        .mem_rdata  ('0),
        .mem_ack    (1'b1),
        .dbg_halt   (dbg_halt),
        .dbg_resume (dbg_resume),
        .dbg_step   (dbg_step),
        .npu_halted (npu_halted),
        .bp_enable  (),
        .bp_addr    (),
        .bp_hit     (1'b0),
        .dbg_active (dbg_active)
    );
    
    // Debug register access
    assign dbg_rdata = s_axil_rdata;
    assign dbg_ack   = 1'b1;
    assign dbg_err   = 1'b0;
    
    //=========================================================================
    // Data Path Connections
    //=========================================================================
    
    // Activation unit input
    assign act_data_in  = pe_acc_out[0][0][DATA_WIDTH-1:0];
    assign act_valid_in = pe_acc_valid[0][0] && act_enable;
    
    // BatchNorm input (from activation output)
    assign bn_data_in  = act_data_out;
    assign bn_valid_in = act_valid_out;
    
    // Pooling input (from batchnorm or activation)
    assign pool_data_in  = bn_enable ? bn_data_out : act_data_out;
    assign pool_valid_in = bn_enable ? bn_valid_out : act_valid_out;
    
    // Softmax input
    assign softmax_data_in  = pool_data_out;
    assign softmax_valid_in = pool_valid_out;
    
    // Instruction interface (placeholder)
    assign inst_fetched     = '0;
    assign inst_fetch_valid = 1'b0;
    
    //=========================================================================
    // Interrupt Generation
    //=========================================================================
    
    assign irq = |(reg_irq_status & reg_irq_en);
    assign irq_done  = conv_done || softmax_done;
    assign irq_error = dma_error;

endmodule
