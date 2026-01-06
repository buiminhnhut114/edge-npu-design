module weight_buffer (
	clk,
	rst_n,
	wr_en,
	wr_addr,
	wr_data,
	rd_en,
	rd_addr,
	rd_data,
	rd_valid
);
	parameter signed [31:0] DATA_WIDTH = 128;
	parameter signed [31:0] SIZE_KB = 256;
	parameter signed [31:0] DEPTH = ((SIZE_KB * 1024) * 8) / DATA_WIDTH;
	parameter signed [31:0] ADDR_WIDTH = $clog2(DEPTH);
	input wire clk;
	input wire rst_n;
	input wire wr_en;
	input wire [ADDR_WIDTH - 1:0] wr_addr;
	input wire [DATA_WIDTH - 1:0] wr_data;
	input wire rd_en;
	input wire [ADDR_WIDTH - 1:0] rd_addr;
	output reg [DATA_WIDTH - 1:0] rd_data;
	output reg rd_valid;
	wire [DATA_WIDTH - 1:0] mem_rdata;
	reg rd_en_d;
	sram_sp #(
		.DATA_WIDTH(DATA_WIDTH),
		.DEPTH(DEPTH)
	) u_sram(
		.clk(clk),
		.rst_n(rst_n),
		.en(wr_en | rd_en),
		.we(wr_en),
		.addr((wr_en ? wr_addr : rd_addr)),
		.wdata(wr_data),
		.rdata(mem_rdata)
	);
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			rd_en_d <= 1'b0;
			rd_valid <= 1'b0;
			rd_data <= 1'sb0;
		end
		else begin
			rd_en_d <= rd_en;
			rd_valid <= rd_en_d;
			rd_data <= mem_rdata;
		end
endmodule
