module activation_buffer (
	clk,
	rst_n,
	a_en,
	a_we,
	a_addr,
	a_wdata,
	a_rdata,
	b_en,
	b_addr,
	b_rdata,
	b_valid
);
	parameter signed [31:0] DATA_WIDTH = 128;
	parameter signed [31:0] SIZE_KB = 256;
	parameter signed [31:0] DEPTH = ((SIZE_KB * 1024) * 8) / DATA_WIDTH;
	parameter signed [31:0] ADDR_WIDTH = $clog2(DEPTH);
	input wire clk;
	input wire rst_n;
	input wire a_en;
	input wire a_we;
	input wire [ADDR_WIDTH - 1:0] a_addr;
	input wire [DATA_WIDTH - 1:0] a_wdata;
	output reg [DATA_WIDTH - 1:0] a_rdata;
	input wire b_en;
	input wire [ADDR_WIDTH - 1:0] b_addr;
	output reg [DATA_WIDTH - 1:0] b_rdata;
	output reg b_valid;
	reg [DATA_WIDTH - 1:0] mem [0:DEPTH - 1];
	reg b_en_d;
	always @(posedge clk)
		if (a_en) begin
			if (a_we)
				mem[a_addr] <= a_wdata;
			a_rdata <= mem[a_addr];
		end
	always @(posedge clk)
		if (b_en)
			b_rdata <= mem[b_addr];
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			b_en_d <= 1'b0;
			b_valid <= 1'b0;
		end
		else begin
			b_en_d <= b_en;
			b_valid <= b_en_d;
		end
endmodule
