module pe (
	clk,
	rst_n,
	enable,
	clear_acc,
	load_weight,
	data_in,
	weight_in,
	data_out,
	acc_out,
	acc_valid
);
	parameter signed [31:0] DATA_WIDTH = 8;
	parameter signed [31:0] WEIGHT_WIDTH = 8;
	parameter signed [31:0] ACC_WIDTH = 32;
	input wire clk;
	input wire rst_n;
	input wire enable;
	input wire clear_acc;
	input wire load_weight;
	input wire signed [DATA_WIDTH - 1:0] data_in;
	input wire signed [WEIGHT_WIDTH - 1:0] weight_in;
	output wire signed [DATA_WIDTH - 1:0] data_out;
	output wire signed [ACC_WIDTH - 1:0] acc_out;
	output wire acc_valid;
	reg signed [WEIGHT_WIDTH - 1:0] weight_reg;
	reg signed [DATA_WIDTH - 1:0] data_reg;
	reg signed [ACC_WIDTH - 1:0] acc_reg;
	reg valid_reg;
	wire signed [(DATA_WIDTH + WEIGHT_WIDTH) - 1:0] mult_result;
	wire signed [ACC_WIDTH - 1:0] add_result;
	assign mult_result = data_in * weight_reg;
	assign add_result = acc_reg + {{(ACC_WIDTH - DATA_WIDTH) - WEIGHT_WIDTH {mult_result[(DATA_WIDTH + WEIGHT_WIDTH) - 1]}}, mult_result};
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			weight_reg <= 1'sb0;
			data_reg <= 1'sb0;
			acc_reg <= 1'sb0;
			valid_reg <= 1'b0;
		end
		else begin
			if (load_weight)
				weight_reg <= weight_in;
			if (clear_acc) begin
				acc_reg <= 1'sb0;
				valid_reg <= 1'b0;
			end
			else if (enable) begin
				data_reg <= data_in;
				acc_reg <= add_result;
				valid_reg <= 1'b1;
			end
		end
	assign data_out = data_reg;
	assign acc_out = acc_reg;
	assign acc_valid = valid_reg;
endmodule
