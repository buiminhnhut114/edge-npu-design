module activation_unit (
	clk,
	rst_n,
	act_type,
	valid_in,
	data_in,
	data_out,
	valid_out
);
	reg _sv2v_0;
	parameter signed [31:0] DATA_WIDTH = 8;
	input wire clk;
	input wire rst_n;
	input wire [2:0] act_type;
	input wire valid_in;
	input wire signed [DATA_WIDTH - 1:0] data_in;
	output reg signed [DATA_WIDTH - 1:0] data_out;
	output reg valid_out;
	wire signed [DATA_WIDTH - 1:0] relu_out;
	reg signed [DATA_WIDTH - 1:0] relu6_out;
	reg signed [DATA_WIDTH - 1:0] sigmoid_out;
	reg signed [DATA_WIDTH - 1:0] tanh_out;
	reg signed [DATA_WIDTH - 1:0] result;
	localparam signed [DATA_WIDTH - 1:0] ZERO = 1'sb0;
	localparam signed [DATA_WIDTH - 1:0] SIX = 8'sd6;
	localparam signed [DATA_WIDTH - 1:0] MAX_VAL = 8'sd127;
	assign relu_out = (data_in[DATA_WIDTH - 1] ? ZERO : data_in);
	always @(*) begin
		if (_sv2v_0)
			;
		if (data_in[DATA_WIDTH - 1])
			relu6_out = ZERO;
		else if (data_in > SIX)
			relu6_out = SIX;
		else
			relu6_out = data_in;
	end
	always @(*) begin
		if (_sv2v_0)
			;
		if (data_in < -8'sd64)
			sigmoid_out = ZERO;
		else if (data_in > 8'sd64)
			sigmoid_out = MAX_VAL;
		else
			sigmoid_out = 8'sd64 + (data_in >>> 1);
	end
	always @(*) begin
		if (_sv2v_0)
			;
		if (data_in < -8'sd64)
			tanh_out = -MAX_VAL;
		else if (data_in > 8'sd64)
			tanh_out = MAX_VAL;
		else
			tanh_out = data_in <<< 1;
	end
	always @(*) begin
		if (_sv2v_0)
			;
		case (act_type)
			3'h0: result = data_in;
			3'h1: result = relu_out;
			3'h2: result = relu6_out;
			3'h3: result = sigmoid_out;
			3'h4: result = tanh_out;
			3'h5: result = (data_in[DATA_WIDTH - 1] ? ZERO : data_in);
			3'h6: result = (data_in[DATA_WIDTH - 1] ? ZERO : data_in);
			default: result = data_in;
		endcase
	end
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			data_out <= 1'sb0;
			valid_out <= 1'b0;
		end
		else begin
			data_out <= result;
			valid_out <= valid_in;
		end
	initial _sv2v_0 = 0;
endmodule
