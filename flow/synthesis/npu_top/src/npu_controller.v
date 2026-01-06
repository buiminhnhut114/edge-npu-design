module npu_controller (
	clk,
	rst_n,
	start,
	enable,
	busy,
	done,
	state_out,
	instruction,
	inst_valid,
	inst_ready,
	pe_enable,
	pe_clear_acc,
	pe_load_weight,
	act_type,
	act_enable,
	pool_type,
	pool_start,
	pool_done,
	weight_buf_rd_en,
	weight_buf_addr,
	act_buf_rd_en,
	act_buf_wr_en,
	act_buf_addr,
	dma_start,
	dma_channel,
	dma_done,
	irq_done,
	irq_error
);
	reg _sv2v_0;
	parameter signed [31:0] PE_ROWS = 16;
	parameter signed [31:0] PE_COLS = 16;
	input wire clk;
	input wire rst_n;
	input wire start;
	input wire enable;
	output wire busy;
	output wire done;
	output wire [3:0] state_out;
	input wire [63:0] instruction;
	input wire inst_valid;
	output wire inst_ready;
	output wire pe_enable;
	output wire pe_clear_acc;
	output reg [PE_ROWS - 1:0] pe_load_weight;
	output reg [2:0] act_type;
	output wire act_enable;
	output reg [1:0] pool_type;
	output wire pool_start;
	input wire pool_done;
	output wire weight_buf_rd_en;
	output wire [17:0] weight_buf_addr;
	output wire act_buf_rd_en;
	output wire act_buf_wr_en;
	output wire [17:0] act_buf_addr;
	output wire dma_start;
	output wire [1:0] dma_channel;
	input wire dma_done;
	output wire irq_done;
	output wire irq_error;
	reg [3:0] state;
	reg [3:0] next_state;
	reg [63:0] inst_reg;
	wire [3:0] current_op;
	reg [15:0] compute_count;
	reg [15:0] compute_total;
	reg [7:0] weight_row_count;
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			state <= 4'h0;
		else
			state <= next_state;
	assign state_out = state;
	always @(*) begin
		if (_sv2v_0)
			;
		next_state = state;
		case (state)
			4'h0:
				if (start && enable)
					next_state = 4'h1;
			4'h1:
				if (inst_valid)
					next_state = 4'h2;
			4'h2:
				case (inst_reg[63-:4])
					4'h0: next_state = 4'h1;
					4'h1: next_state = 4'h3;
					4'h2: next_state = 4'h3;
					4'h3: next_state = 4'h4;
					4'h4: next_state = 4'h4;
					4'h5: next_state = 4'h4;
					4'h6: next_state = 4'h9;
					4'h7: next_state = 4'ha;
					default: next_state = 4'hf;
				endcase
			4'h3:
				if (weight_row_count >= PE_ROWS)
					next_state = 4'h4;
			4'h4: next_state = 4'h5;
			4'h5:
				if (compute_count >= compute_total)
					next_state = 4'h6;
			4'h6:
				if (inst_reg[63-:4] == 4'h3)
					next_state = 4'h8;
				else
					next_state = 4'h7;
			4'h7: next_state = 4'h9;
			4'h8:
				if (pool_done)
					next_state = 4'h9;
			4'h9: next_state = 4'h1;
			4'ha: next_state = 4'h0;
			4'hf: next_state = 4'h0;
			default: next_state = 4'h0;
		endcase
	end
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			inst_reg <= 1'sb0;
		else if ((state == 4'h1) && inst_valid)
			inst_reg <= instruction;
	assign current_op = inst_reg[63-:4];
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			compute_count <= 1'sb0;
			compute_total <= 1'sb0;
		end
		else
			case (state)
				4'h2: begin
					compute_count <= 1'sb0;
					compute_total <= inst_reg[15:0];
				end
				4'h5:
					if (pe_enable)
						compute_count <= compute_count + 1'b1;
			endcase
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			weight_row_count <= 1'sb0;
		else
			case (state)
				4'h2: weight_row_count <= 1'sb0;
				4'h3: weight_row_count <= weight_row_count + 1'b1;
			endcase
	assign busy = state != 4'h0;
	assign done = state == 4'ha;
	assign inst_ready = state == 4'h1;
	assign pe_enable = state == 4'h5;
	assign pe_clear_acc = state == 4'h2;
	always @(*) begin
		if (_sv2v_0)
			;
		pe_load_weight = 1'sb0;
		if ((state == 4'h3) && (weight_row_count < PE_ROWS))
			pe_load_weight[weight_row_count] = 1'b1;
	end
	always @(*) begin
		if (_sv2v_0)
			;
		case (inst_reg[58:56])
			3'h0: act_type = 3'h0;
			3'h1: act_type = 3'h1;
			3'h2: act_type = 3'h2;
			3'h3: act_type = 3'h3;
			3'h4: act_type = 3'h4;
			3'h5: act_type = 3'h5;
			3'h6: act_type = 3'h6;
			default: act_type = 3'h0;
		endcase
	end
	assign act_enable = state == 4'h7;
	always @(*) begin
		if (_sv2v_0)
			;
		case (inst_reg[57:56])
			2'h0: pool_type = 2'h0;
			2'h1: pool_type = 2'h1;
			2'h2: pool_type = 2'h2;
			default: pool_type = 2'h0;
		endcase
	end
	assign pool_start = (state == 4'h8) && (next_state != 4'h8);
	assign weight_buf_rd_en = state == 4'h3;
	assign weight_buf_addr = inst_reg[39-:8] + weight_row_count;
	assign act_buf_rd_en = (state == 4'h4) || (state == 4'h5);
	assign act_buf_wr_en = state == 4'h9;
	assign act_buf_addr = (state == 4'h9 ? inst_reg[55-:8] : inst_reg[47-:8]);
	assign dma_start = (state == 4'h4) && (current_op == 4'h5);
	assign dma_channel = inst_reg[57:56];
	assign irq_done = state == 4'ha;
	assign irq_error = state == 4'hf;
	initial _sv2v_0 = 0;
endmodule
