module pe_array (
	clk,
	rst_n,
	enable,
	clear_acc,
	load_weight,
	data_in,
	weight_in,
	acc_out,
	acc_valid
);
	parameter signed [31:0] ROWS = 16;
	parameter signed [31:0] COLS = 16;
	parameter signed [31:0] DATA_WIDTH = 8;
	parameter signed [31:0] WEIGHT_WIDTH = 8;
	parameter signed [31:0] ACC_WIDTH = 32;
	input wire clk;
	input wire rst_n;
	input wire enable;
	input wire clear_acc;
	input wire [ROWS - 1:0] load_weight;
	input wire signed [(ROWS * DATA_WIDTH) - 1:0] data_in;
	input wire signed [(COLS * WEIGHT_WIDTH) - 1:0] weight_in;
	output wire signed [((ROWS * COLS) * ACC_WIDTH) - 1:0] acc_out;
	output wire [(ROWS * COLS) - 1:0] acc_valid;
	wire signed [DATA_WIDTH - 1:0] data_h [0:ROWS - 1][0:COLS + 0];
	wire signed [WEIGHT_WIDTH - 1:0] weight_v [0:ROWS + 0][0:COLS - 1];
	genvar _gv_r_1;
	generate
		for (_gv_r_1 = 0; _gv_r_1 < ROWS; _gv_r_1 = _gv_r_1 + 1) begin : gen_data_in
			localparam r = _gv_r_1;
			assign data_h[r][0] = data_in[((ROWS - 1) - r) * DATA_WIDTH+:DATA_WIDTH];
		end
	endgenerate
	genvar _gv_c_1;
	generate
		for (_gv_c_1 = 0; _gv_c_1 < COLS; _gv_c_1 = _gv_c_1 + 1) begin : gen_weight_in
			localparam c = _gv_c_1;
			assign weight_v[0][c] = weight_in[((COLS - 1) - c) * WEIGHT_WIDTH+:WEIGHT_WIDTH];
		end
	endgenerate
	genvar _gv_r_2;
	generate
		for (_gv_r_2 = 0; _gv_r_2 < ROWS; _gv_r_2 = _gv_r_2 + 1) begin : gen_row
			localparam r = _gv_r_2;
			genvar _gv_c_2;
			for (_gv_c_2 = 0; _gv_c_2 < COLS; _gv_c_2 = _gv_c_2 + 1) begin : gen_col
				localparam c = _gv_c_2;
				pe #(
					.DATA_WIDTH(DATA_WIDTH),
					.WEIGHT_WIDTH(WEIGHT_WIDTH),
					.ACC_WIDTH(ACC_WIDTH)
				) u_pe(
					.clk(clk),
					.rst_n(rst_n),
					.enable(enable),
					.clear_acc(clear_acc),
					.load_weight(load_weight[r]),
					.data_in(data_h[r][c]),
					.weight_in(weight_v[r][c]),
					.data_out(data_h[r][c + 1]),
					.acc_out(acc_out[((((ROWS - 1) - r) * COLS) + ((COLS - 1) - c)) * ACC_WIDTH+:ACC_WIDTH]),
					.acc_valid(acc_valid[(((ROWS - 1) - r) * COLS) + ((COLS - 1) - c)])
				);
				assign weight_v[r + 1][c] = weight_v[r][c];
			end
		end
	endgenerate
endmodule
