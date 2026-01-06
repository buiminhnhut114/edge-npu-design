module pooling_unit (
	clk,
	rst_n,
	pool_type,
	kernel_size,
	start,
	done,
	busy,
	valid_in,
	data_in,
	valid_out,
	data_out
);
	reg _sv2v_0;
	parameter signed [31:0] DATA_WIDTH = 8;
	parameter signed [31:0] MAX_KERNEL = 3;
	parameter signed [31:0] MAX_CHANNELS = 256;
	input wire clk;
	input wire rst_n;
	input wire [1:0] pool_type;
	input wire [1:0] kernel_size;
	input wire start;
	output reg done;
	output wire busy;
	input wire valid_in;
	input wire signed [DATA_WIDTH - 1:0] data_in;
	output reg valid_out;
	output reg signed [DATA_WIDTH - 1:0] data_out;
	reg [1:0] state;
	reg [1:0] next_state;
	reg signed [DATA_WIDTH - 1:0] window [0:(MAX_KERNEL * MAX_KERNEL) - 1];
	reg [3:0] count;
	reg [3:0] kernel_elements;
	reg signed [DATA_WIDTH - 1:0] max_val;
	reg signed [DATA_WIDTH + 7:0] sum_val;
	reg signed [DATA_WIDTH - 1:0] avg_val;
	reg signed [DATA_WIDTH - 1:0] result;
	always @(*) begin
		if (_sv2v_0)
			;
		case (kernel_size)
			2'b00: kernel_elements = 4'd4;
			2'b01: kernel_elements = 4'd9;
			default: kernel_elements = 4'd4;
		endcase
	end
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			state <= 2'd0;
		else
			state <= next_state;
	always @(*) begin
		if (_sv2v_0)
			;
		next_state = state;
		case (state)
			2'd0:
				if (start)
					next_state = 2'd1;
			2'd1:
				if (count >= kernel_elements)
					next_state = 2'd2;
			2'd2: next_state = 2'd3;
			2'd3: next_state = 2'd0;
		endcase
	end
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			count <= 1'sb0;
			begin : sv2v_autoblock_1
				reg signed [31:0] i;
				for (i = 0; i < (MAX_KERNEL * MAX_KERNEL); i = i + 1)
					window[i] <= 1'sb0;
			end
		end
		else
			case (state)
				2'd0: count <= 1'sb0;
				2'd1:
					if (valid_in && (count < kernel_elements)) begin
						window[count] <= data_in;
						count <= count + 1'b1;
					end
			endcase
	always @(*) begin
		if (_sv2v_0)
			;
		max_val = window[0];
		begin : sv2v_autoblock_2
			reg signed [31:0] i;
			for (i = 1; i < (MAX_KERNEL * MAX_KERNEL); i = i + 1)
				if ((i < kernel_elements) && (window[i] > max_val))
					max_val = window[i];
		end
	end
	always @(*) begin
		if (_sv2v_0)
			;
		sum_val = 1'sb0;
		begin : sv2v_autoblock_3
			reg signed [31:0] i;
			for (i = 0; i < (MAX_KERNEL * MAX_KERNEL); i = i + 1)
				if (i < kernel_elements)
					sum_val = sum_val + {{8 {window[i][DATA_WIDTH - 1]}}, window[i]};
		end
		case (kernel_size)
			2'b00: avg_val = sum_val[DATA_WIDTH + 1:2];
			2'b01: avg_val = sum_val / 9;
			default: avg_val = sum_val[DATA_WIDTH + 1:2];
		endcase
	end
	always @(*) begin
		if (_sv2v_0)
			;
		case (pool_type)
			2'h0: result = max_val;
			2'h1: result = avg_val;
			2'h2: result = avg_val;
			default: result = max_val;
		endcase
	end
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			data_out <= 1'sb0;
			valid_out <= 1'b0;
			done <= 1'b0;
		end
		else begin
			valid_out <= state == 2'd3;
			done <= state == 2'd3;
			if (state == 2'd2)
				data_out <= result;
		end
	assign busy = state != 2'd0;
	initial _sv2v_0 = 0;
endmodule
