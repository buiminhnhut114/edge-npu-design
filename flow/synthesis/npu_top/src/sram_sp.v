module sram_sp (
	clk,
	rst_n,
	en,
	we,
	addr,
	wdata,
	rdata
);
	parameter signed [31:0] DATA_WIDTH = 128;
	parameter signed [31:0] DEPTH = 2048;
	parameter signed [31:0] ADDR_WIDTH = $clog2(DEPTH);
	input wire clk;
	input wire rst_n;
	input wire en;
	input wire we;
	input wire [ADDR_WIDTH - 1:0] addr;
	input wire [DATA_WIDTH - 1:0] wdata;
	output reg [DATA_WIDTH - 1:0] rdata;
	reg [DATA_WIDTH - 1:0] mem [0:DEPTH - 1];
	always @(posedge clk)
		if (en) begin
			if (we)
				mem[addr] <= wdata;
			rdata <= mem[addr];
		end
endmodule
