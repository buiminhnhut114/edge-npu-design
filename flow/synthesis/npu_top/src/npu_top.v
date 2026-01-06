module npu_top (
	clk,
	rst_n,
	m_axi_awaddr,
	m_axi_awlen,
	m_axi_awsize,
	m_axi_awburst,
	m_axi_awvalid,
	m_axi_awready,
	m_axi_wdata,
	m_axi_wstrb,
	m_axi_wlast,
	m_axi_wvalid,
	m_axi_wready,
	m_axi_bresp,
	m_axi_bvalid,
	m_axi_bready,
	m_axi_araddr,
	m_axi_arlen,
	m_axi_arsize,
	m_axi_arburst,
	m_axi_arvalid,
	m_axi_arready,
	m_axi_rdata,
	m_axi_rresp,
	m_axi_rlast,
	m_axi_rvalid,
	m_axi_rready,
	s_axil_awaddr,
	s_axil_awvalid,
	s_axil_awready,
	s_axil_wdata,
	s_axil_wstrb,
	s_axil_wvalid,
	s_axil_wready,
	s_axil_bresp,
	s_axil_bvalid,
	s_axil_bready,
	s_axil_araddr,
	s_axil_arvalid,
	s_axil_arready,
	s_axil_rdata,
	s_axil_rresp,
	s_axil_rvalid,
	s_axil_rready,
	irq
);
	reg _sv2v_0;
	parameter signed [31:0] PE_ROWS = 16;
	parameter signed [31:0] PE_COLS = 16;
	parameter signed [31:0] DATA_WIDTH = 8;
	parameter signed [31:0] AXI_DATA_W = 128;
	parameter signed [31:0] AXI_ADDR_W = 40;
	parameter signed [31:0] AXIL_DATA_W = 32;
	parameter signed [31:0] AXIL_ADDR_W = 32;
	input wire clk;
	input wire rst_n;
	output wire [AXI_ADDR_W - 1:0] m_axi_awaddr;
	output wire [7:0] m_axi_awlen;
	output wire [2:0] m_axi_awsize;
	output wire [1:0] m_axi_awburst;
	output wire m_axi_awvalid;
	input wire m_axi_awready;
	output wire [AXI_DATA_W - 1:0] m_axi_wdata;
	output wire [(AXI_DATA_W / 8) - 1:0] m_axi_wstrb;
	output wire m_axi_wlast;
	output wire m_axi_wvalid;
	input wire m_axi_wready;
	input wire [1:0] m_axi_bresp;
	input wire m_axi_bvalid;
	output wire m_axi_bready;
	output wire [AXI_ADDR_W - 1:0] m_axi_araddr;
	output wire [7:0] m_axi_arlen;
	output wire [2:0] m_axi_arsize;
	output wire [1:0] m_axi_arburst;
	output wire m_axi_arvalid;
	input wire m_axi_arready;
	input wire [AXI_DATA_W - 1:0] m_axi_rdata;
	input wire [1:0] m_axi_rresp;
	input wire m_axi_rlast;
	input wire m_axi_rvalid;
	output wire m_axi_rready;
	input wire [AXIL_ADDR_W - 1:0] s_axil_awaddr;
	input wire s_axil_awvalid;
	output wire s_axil_awready;
	input wire [AXIL_DATA_W - 1:0] s_axil_wdata;
	input wire [(AXIL_DATA_W / 8) - 1:0] s_axil_wstrb;
	input wire s_axil_wvalid;
	output wire s_axil_wready;
	output wire [1:0] s_axil_bresp;
	output wire s_axil_bvalid;
	input wire s_axil_bready;
	input wire [AXIL_ADDR_W - 1:0] s_axil_araddr;
	input wire s_axil_arvalid;
	output wire s_axil_arready;
	output reg [AXIL_DATA_W - 1:0] s_axil_rdata;
	output wire [1:0] s_axil_rresp;
	output wire s_axil_rvalid;
	input wire s_axil_rready;
	output wire irq;
	wire npu_enable;
	wire npu_start;
	wire npu_done;
	wire npu_busy;
	wire [31:0] npu_status;
	wire [3:0] ctrl_state;
	wire pe_enable;
	wire pe_clear_acc;
	wire [PE_ROWS - 1:0] pe_load_weight;
	wire signed [(PE_ROWS * DATA_WIDTH) - 1:0] pe_data_in;
	wire signed [(PE_COLS * DATA_WIDTH) - 1:0] pe_weight_in;
	wire signed [((PE_ROWS * PE_COLS) * 32) - 1:0] pe_acc_out;
	wire [(PE_ROWS * PE_COLS) - 1:0] pe_acc_valid;
	wire [2:0] act_type;
	wire act_enable;
	wire signed [DATA_WIDTH - 1:0] act_data_in;
	wire signed [DATA_WIDTH - 1:0] act_data_out;
	wire act_valid_in;
	wire act_valid_out;
	wire [1:0] pool_type;
	wire pool_start;
	wire pool_done;
	wire pool_busy;
	wire signed [DATA_WIDTH - 1:0] pool_data_in;
	wire signed [DATA_WIDTH - 1:0] pool_data_out;
	wire pool_valid_in;
	wire pool_valid_out;
	wire weight_buf_rd_en;
	wire [17:0] weight_buf_addr;
	wire [AXI_DATA_W - 1:0] weight_buf_data;
	wire weight_buf_valid;
	wire act_buf_rd_en;
	wire act_buf_wr_en;
	wire [17:0] act_buf_addr;
	wire [AXI_DATA_W - 1:0] act_buf_rd_data;
	wire [AXI_DATA_W - 1:0] act_buf_wr_data;
	wire act_buf_valid;
	wire dma_start;
	wire [1:0] dma_channel;
	wire dma_busy;
	wire dma_done;
	wire dma_error;
	wire [143:0] dma_desc;
	wire dma_buf_wr_en;
	wire [17:0] dma_buf_wr_addr;
	wire [AXI_DATA_W - 1:0] dma_buf_wr_data;
	wire dma_buf_rd_en;
	wire [17:0] dma_buf_rd_addr;
	wire [AXI_DATA_W - 1:0] dma_buf_rd_data;
	wire dma_buf_rd_valid;
	wire [63:0] instruction;
	wire inst_valid;
	wire inst_ready;
	wire irq_done;
	wire irq_error;
	reg [31:0] reg_ctrl;
	wire [31:0] reg_status;
	reg [31:0] reg_irq_en;
	reg [31:0] reg_irq_status;
	reg [31:0] reg_dma_ctrl;
	reg [31:0] reg_dma_src;
	reg [31:0] reg_dma_dst;
	reg [31:0] reg_dma_len;
	localparam [11:0] npu_pkg_REG_CTRL = 12'h000;
	localparam [11:0] npu_pkg_REG_DMA_CTRL = 12'h100;
	localparam [11:0] npu_pkg_REG_DMA_DST = 12'h10c;
	localparam [11:0] npu_pkg_REG_DMA_LEN = 12'h110;
	localparam [11:0] npu_pkg_REG_DMA_SRC = 12'h108;
	localparam [11:0] npu_pkg_REG_IRQ_EN = 12'h008;
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			reg_ctrl <= 1'sb0;
			reg_irq_en <= 1'sb0;
			reg_dma_ctrl <= 1'sb0;
			reg_dma_src <= 1'sb0;
			reg_dma_dst <= 1'sb0;
			reg_dma_len <= 1'sb0;
		end
		else if (((s_axil_awvalid && s_axil_wvalid) && s_axil_awready) && s_axil_wready)
			case (s_axil_awaddr[11:0])
				npu_pkg_REG_CTRL: reg_ctrl <= s_axil_wdata;
				npu_pkg_REG_IRQ_EN: reg_irq_en <= s_axil_wdata;
				npu_pkg_REG_DMA_CTRL: reg_dma_ctrl <= s_axil_wdata;
				npu_pkg_REG_DMA_SRC: reg_dma_src <= s_axil_wdata;
				npu_pkg_REG_DMA_DST: reg_dma_dst <= s_axil_wdata;
				npu_pkg_REG_DMA_LEN: reg_dma_len <= s_axil_wdata;
			endcase
		if (npu_start)
			reg_ctrl[1] <= 1'b0;
		if (dma_start)
			reg_dma_ctrl[0] <= 1'b0;
	end
	localparam [11:0] npu_pkg_REG_IRQ_STATUS = 12'h00c;
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			reg_irq_status <= 1'sb0;
		else begin
			if (irq_done)
				reg_irq_status[0] <= 1'b1;
			if (irq_error)
				reg_irq_status[1] <= 1'b1;
			if (dma_done)
				reg_irq_status[2] <= 1'b1;
			if (dma_error)
				reg_irq_status[3] <= 1'b1;
			if ((s_axil_awvalid && s_axil_wvalid) && (s_axil_awaddr[11:0] == npu_pkg_REG_IRQ_STATUS))
				reg_irq_status <= reg_irq_status & ~s_axil_wdata;
		end
	localparam [31:0] npu_pkg_NPU_VERSION = 32'h00010000;
	localparam [11:0] npu_pkg_REG_CONFIG = 12'h014;
	localparam [11:0] npu_pkg_REG_DMA_STATUS = 12'h104;
	localparam [11:0] npu_pkg_REG_STATUS = 12'h004;
	localparam [11:0] npu_pkg_REG_VERSION = 12'h010;
	function automatic signed [15:0] sv2v_cast_16_signed;
		input reg signed [15:0] inp;
		sv2v_cast_16_signed = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		case (s_axil_araddr[11:0])
			npu_pkg_REG_CTRL: s_axil_rdata = reg_ctrl;
			npu_pkg_REG_STATUS: s_axil_rdata = npu_status;
			npu_pkg_REG_IRQ_EN: s_axil_rdata = reg_irq_en;
			npu_pkg_REG_IRQ_STATUS: s_axil_rdata = reg_irq_status;
			npu_pkg_REG_VERSION: s_axil_rdata = npu_pkg_NPU_VERSION;
			npu_pkg_REG_CONFIG: s_axil_rdata = {sv2v_cast_16_signed(PE_ROWS), sv2v_cast_16_signed(PE_COLS)};
			npu_pkg_REG_DMA_CTRL: s_axil_rdata = reg_dma_ctrl;
			npu_pkg_REG_DMA_STATUS: s_axil_rdata = {30'b000000000000000000000000000000, dma_done, dma_busy};
			npu_pkg_REG_DMA_SRC: s_axil_rdata = reg_dma_src;
			npu_pkg_REG_DMA_DST: s_axil_rdata = reg_dma_dst;
			npu_pkg_REG_DMA_LEN: s_axil_rdata = reg_dma_len;
			default: s_axil_rdata = 1'sb0;
		endcase
	end
	assign s_axil_awready = 1'b1;
	assign s_axil_wready = 1'b1;
	assign s_axil_bresp = 2'b00;
	assign s_axil_bvalid = 1'b1;
	assign s_axil_arready = 1'b1;
	assign s_axil_rresp = 2'b00;
	assign s_axil_rvalid = 1'b1;
	assign npu_enable = reg_ctrl[0];
	assign npu_start = reg_ctrl[1] && npu_enable;
	assign npu_status = {24'b000000000000000000000000, ctrl_state, 2'b00, npu_done, npu_busy};
	assign dma_desc[143-:40] = {8'b00000000, reg_dma_src};
	assign dma_desc[103-:40] = {8'b00000000, reg_dma_dst};
	assign dma_desc[63-:24] = reg_dma_len[23:0];
	assign dma_desc[39-:16] = 1'sb0;
	assign dma_desc[23-:16] = 1'sb0;
	assign dma_desc[7-:8] = reg_dma_ctrl[15:8];
	npu_controller #(
		.PE_ROWS(PE_ROWS),
		.PE_COLS(PE_COLS)
	) u_controller(
		.clk(clk),
		.rst_n(rst_n),
		.start(npu_start),
		.enable(npu_enable),
		.busy(npu_busy),
		.done(npu_done),
		.state_out(ctrl_state),
		.instruction(instruction),
		.inst_valid(inst_valid),
		.inst_ready(inst_ready),
		.pe_enable(pe_enable),
		.pe_clear_acc(pe_clear_acc),
		.pe_load_weight(pe_load_weight),
		.act_type(act_type),
		.act_enable(act_enable),
		.pool_type(pool_type),
		.pool_start(pool_start),
		.pool_done(pool_done),
		.weight_buf_rd_en(weight_buf_rd_en),
		.weight_buf_addr(weight_buf_addr),
		.act_buf_rd_en(act_buf_rd_en),
		.act_buf_wr_en(act_buf_wr_en),
		.act_buf_addr(act_buf_addr),
		.dma_start(dma_start),
		.dma_channel(dma_channel),
		.dma_done(dma_done),
		.irq_done(irq_done),
		.irq_error(irq_error)
	);
	pe_array #(
		.ROWS(PE_ROWS),
		.COLS(PE_COLS),
		.DATA_WIDTH(DATA_WIDTH),
		.WEIGHT_WIDTH(DATA_WIDTH),
		.ACC_WIDTH(32)
	) u_pe_array(
		.clk(clk),
		.rst_n(rst_n),
		.enable(pe_enable),
		.clear_acc(pe_clear_acc),
		.load_weight(pe_load_weight),
		.data_in(pe_data_in),
		.weight_in(pe_weight_in),
		.acc_out(pe_acc_out),
		.acc_valid(pe_acc_valid)
	);
	activation_unit #(.DATA_WIDTH(DATA_WIDTH)) u_activation(
		.clk(clk),
		.rst_n(rst_n),
		.act_type(act_type),
		.valid_in(act_valid_in),
		.data_in(act_data_in),
		.data_out(act_data_out),
		.valid_out(act_valid_out)
	);
	pooling_unit #(.DATA_WIDTH(DATA_WIDTH)) u_pooling(
		.clk(clk),
		.rst_n(rst_n),
		.pool_type(pool_type),
		.kernel_size(2'b00),
		.start(pool_start),
		.done(pool_done),
		.busy(pool_busy),
		.valid_in(pool_valid_in),
		.data_in(pool_data_in),
		.valid_out(pool_valid_out),
		.data_out(pool_data_out)
	);
	weight_buffer #(
		.DATA_WIDTH(AXI_DATA_W),
		.SIZE_KB(256)
	) u_weight_buffer(
		.clk(clk),
		.rst_n(rst_n),
		.wr_en(dma_buf_wr_en && (dma_channel == 2'b00)),
		.wr_addr(dma_buf_wr_addr),
		.wr_data(dma_buf_wr_data),
		.rd_en(weight_buf_rd_en),
		.rd_addr(weight_buf_addr),
		.rd_data(weight_buf_data),
		.rd_valid(weight_buf_valid)
	);
	activation_buffer #(
		.DATA_WIDTH(AXI_DATA_W),
		.SIZE_KB(256)
	) u_act_buffer(
		.clk(clk),
		.rst_n(rst_n),
		.a_en(act_buf_wr_en || (dma_buf_wr_en && (dma_channel == 2'b01))),
		.a_we(act_buf_wr_en || (dma_buf_wr_en && (dma_channel == 2'b01))),
		.a_addr((dma_buf_wr_en ? dma_buf_wr_addr : act_buf_addr)),
		.a_wdata((dma_buf_wr_en ? dma_buf_wr_data : act_buf_wr_data)),
		.a_rdata(),
		.b_en(act_buf_rd_en),
		.b_addr(act_buf_addr),
		.b_rdata(act_buf_rd_data),
		.b_valid(act_buf_valid)
	);
	dma_engine #(
		.AXI_DATA_W(AXI_DATA_W),
		.AXI_ADDR_W(AXI_ADDR_W)
	) u_dma(
		.clk(clk),
		.rst_n(rst_n),
		.start(reg_dma_ctrl[0]),
		.channel_sel(dma_channel),
		.descriptor(dma_desc),
		.busy(dma_busy),
		.done(dma_done),
		.error(dma_error),
		.m_axi_awaddr(m_axi_awaddr),
		.m_axi_awlen(m_axi_awlen),
		.m_axi_awsize(m_axi_awsize),
		.m_axi_awburst(m_axi_awburst),
		.m_axi_awvalid(m_axi_awvalid),
		.m_axi_awready(m_axi_awready),
		.m_axi_wdata(m_axi_wdata),
		.m_axi_wstrb(m_axi_wstrb),
		.m_axi_wlast(m_axi_wlast),
		.m_axi_wvalid(m_axi_wvalid),
		.m_axi_wready(m_axi_wready),
		.m_axi_bresp(m_axi_bresp),
		.m_axi_bvalid(m_axi_bvalid),
		.m_axi_bready(m_axi_bready),
		.m_axi_araddr(m_axi_araddr),
		.m_axi_arlen(m_axi_arlen),
		.m_axi_arsize(m_axi_arsize),
		.m_axi_arburst(m_axi_arburst),
		.m_axi_arvalid(m_axi_arvalid),
		.m_axi_arready(m_axi_arready),
		.m_axi_rdata(m_axi_rdata),
		.m_axi_rresp(m_axi_rresp),
		.m_axi_rlast(m_axi_rlast),
		.m_axi_rvalid(m_axi_rvalid),
		.m_axi_rready(m_axi_rready),
		.buf_wr_en(dma_buf_wr_en),
		.buf_wr_addr(dma_buf_wr_addr),
		.buf_wr_data(dma_buf_wr_data),
		.buf_rd_en(dma_buf_rd_en),
		.buf_rd_addr(dma_buf_rd_addr),
		.buf_rd_data(dma_buf_rd_data),
		.buf_rd_valid(dma_buf_rd_valid)
	);
	genvar _gv_i_1;
	generate
		for (_gv_i_1 = 0; _gv_i_1 < PE_COLS; _gv_i_1 = _gv_i_1 + 1) begin : gen_weight_unpack
			localparam i = _gv_i_1;
			assign pe_weight_in[((PE_COLS - 1) - i) * DATA_WIDTH+:DATA_WIDTH] = weight_buf_data[i * DATA_WIDTH+:DATA_WIDTH];
		end
	endgenerate
	genvar _gv_i_2;
	generate
		for (_gv_i_2 = 0; _gv_i_2 < PE_ROWS; _gv_i_2 = _gv_i_2 + 1) begin : gen_data_unpack
			localparam i = _gv_i_2;
			assign pe_data_in[((PE_ROWS - 1) - i) * DATA_WIDTH+:DATA_WIDTH] = act_buf_rd_data[i * DATA_WIDTH+:DATA_WIDTH];
		end
	endgenerate
	assign act_data_in = pe_acc_out[((((PE_ROWS - 1) * PE_COLS) + (PE_COLS - 1)) * 32) + (DATA_WIDTH - 1)-:DATA_WIDTH];
	assign act_valid_in = pe_acc_valid[((PE_ROWS - 1) * PE_COLS) + (PE_COLS - 1)] && act_enable;
	assign pool_data_in = act_data_out;
	assign pool_valid_in = act_valid_out;
	assign instruction = 1'sb0;
	assign inst_valid = 1'b0;
	assign irq = |(reg_irq_status & reg_irq_en);
	initial _sv2v_0 = 0;
endmodule
