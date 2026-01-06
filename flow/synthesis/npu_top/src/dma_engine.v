module dma_engine (
	clk,
	rst_n,
	start,
	channel_sel,
	descriptor,
	busy,
	done,
	error,
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
	buf_wr_en,
	buf_wr_addr,
	buf_wr_data,
	buf_rd_en,
	buf_rd_addr,
	buf_rd_data,
	buf_rd_valid
);
	reg _sv2v_0;
	parameter signed [31:0] AXI_DATA_W = 128;
	parameter signed [31:0] AXI_ADDR_W = 40;
	parameter signed [31:0] NUM_CHANNELS = 4;
	input wire clk;
	input wire rst_n;
	input wire start;
	input wire [1:0] channel_sel;
	input wire [143:0] descriptor;
	output wire busy;
	output wire done;
	output wire error;
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
	output wire buf_wr_en;
	output wire [17:0] buf_wr_addr;
	output wire [AXI_DATA_W - 1:0] buf_wr_data;
	output wire buf_rd_en;
	output wire [17:0] buf_rd_addr;
	input wire [AXI_DATA_W - 1:0] buf_rd_data;
	input wire buf_rd_valid;
	reg [2:0] state;
	reg [2:0] next_state;
	reg [143:0] desc_reg;
	reg [39:0] src_addr_reg;
	reg [39:0] dst_addr_reg;
	reg [23:0] remaining;
	reg [7:0] burst_count;
	reg is_read;
	localparam signed [31:0] BURST_SIZE = AXI_DATA_W / 8;
	localparam signed [31:0] MAX_BURST_LEN = 256;
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			state <= 3'd0;
		else
			state <= next_state;
	always @(*) begin
		if (_sv2v_0)
			;
		next_state = state;
		case (state)
			3'd0:
				if (start) begin
					if (is_read)
						next_state = 3'd1;
					else
						next_state = 3'd3;
				end
			3'd1:
				if (m_axi_arvalid && m_axi_arready)
					next_state = 3'd2;
			3'd2:
				if (m_axi_rvalid && m_axi_rlast) begin
					if (remaining == 0)
						next_state = 3'd6;
					else
						next_state = 3'd1;
				end
			3'd3:
				if (m_axi_awvalid && m_axi_awready)
					next_state = 3'd4;
			3'd4:
				if ((m_axi_wvalid && m_axi_wready) && m_axi_wlast)
					next_state = 3'd5;
			3'd5:
				if (m_axi_bvalid) begin
					if (remaining == 0)
						next_state = 3'd6;
					else
						next_state = 3'd3;
				end
			3'd6: next_state = 3'd0;
		endcase
	end
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			desc_reg <= 1'sb0;
			src_addr_reg <= 1'sb0;
			dst_addr_reg <= 1'sb0;
			remaining <= 1'sb0;
			is_read <= 1'b0;
		end
		else if ((state == 3'd0) && start) begin
			desc_reg <= descriptor;
			src_addr_reg <= descriptor[143-:40];
			dst_addr_reg <= descriptor[103-:40];
			remaining <= descriptor[63-:24];
			is_read <= descriptor[0];
		end
		else if ((state == 3'd2) && m_axi_rvalid) begin
			src_addr_reg <= src_addr_reg + BURST_SIZE;
			dst_addr_reg <= dst_addr_reg + BURST_SIZE;
			if (remaining >= BURST_SIZE)
				remaining <= remaining - BURST_SIZE;
			else
				remaining <= 1'sb0;
		end
		else if (((state == 3'd4) && m_axi_wvalid) && m_axi_wready) begin
			src_addr_reg <= src_addr_reg + BURST_SIZE;
			dst_addr_reg <= dst_addr_reg + BURST_SIZE;
			if (remaining >= BURST_SIZE)
				remaining <= remaining - BURST_SIZE;
			else
				remaining <= 1'sb0;
		end
	always @(*) begin
		if (_sv2v_0)
			;
		if (remaining >= (MAX_BURST_LEN * BURST_SIZE))
			burst_count = 255;
		else
			burst_count = (remaining / BURST_SIZE) - 1;
	end
	assign m_axi_araddr = src_addr_reg;
	assign m_axi_arlen = burst_count;
	assign m_axi_arsize = $clog2(BURST_SIZE);
	assign m_axi_arburst = 2'b01;
	assign m_axi_arvalid = state == 3'd1;
	assign m_axi_rready = state == 3'd2;
	reg [7:0] write_beat_count;
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			write_beat_count <= 1'sb0;
		else if (state == 3'd3)
			write_beat_count <= 1'sb0;
		else if (((state == 3'd4) && m_axi_wvalid) && m_axi_wready)
			write_beat_count <= write_beat_count + 1'b1;
	assign m_axi_awaddr = dst_addr_reg;
	assign m_axi_awlen = burst_count;
	assign m_axi_awsize = $clog2(BURST_SIZE);
	assign m_axi_awburst = 2'b01;
	assign m_axi_awvalid = state == 3'd3;
	assign m_axi_wdata = buf_rd_data;
	assign m_axi_wstrb = {AXI_DATA_W / 8 {1'b1}};
	assign m_axi_wlast = write_beat_count == burst_count;
	assign m_axi_wvalid = (state == 3'd4) && buf_rd_valid;
	assign m_axi_bready = state == 3'd5;
	assign buf_wr_en = (state == 3'd2) && m_axi_rvalid;
	assign buf_wr_addr = dst_addr_reg[17:0];
	assign buf_wr_data = m_axi_rdata;
	assign buf_rd_en = state == 3'd4;
	assign buf_rd_addr = src_addr_reg[17:0];
	assign busy = state != 3'd0;
	assign done = state == 3'd6;
	assign error = (m_axi_bresp[1] && m_axi_bvalid) || (m_axi_rresp[1] && m_axi_rvalid);
	initial _sv2v_0 = 0;
endmodule
