//=============================================================================
// Convolution Dataflow Controller
// Handles im2col transformation, tiling, and PE array scheduling
//=============================================================================

module conv_controller
    import npu_pkg::*;
#(
    parameter int PE_ROWS       = 16,
    parameter int PE_COLS       = 16,
    parameter int DATA_WIDTH    = 8,
    parameter int ADDR_WIDTH    = 18
)(
    input  logic                        clk,
    input  logic                        rst_n,
    
    // Control interface
    input  logic                        start,
    input  conv_param_t                 conv_params,
    output logic                        done,
    output logic                        busy,
    
    // Weight buffer interface
    output logic                        weight_rd_en,
    output logic [ADDR_WIDTH-1:0]       weight_rd_addr,
    input  logic [127:0]                weight_rd_data,
    input  logic                        weight_rd_valid,
    
    // Activation buffer interface
    output logic                        act_rd_en,
    output logic [ADDR_WIDTH-1:0]       act_rd_addr,
    input  logic [127:0]                act_rd_data,
    input  logic                        act_rd_valid,
    
    output logic                        act_wr_en,
    output logic [ADDR_WIDTH-1:0]       act_wr_addr,
    output logic [127:0]                act_wr_data,
    
    // PE Array control
    output logic                        pe_enable,
    output logic                        pe_clear_acc,
    output logic [PE_ROWS-1:0]          pe_load_weight,
    output logic signed [DATA_WIDTH-1:0] pe_data_in [PE_ROWS],
    output logic signed [DATA_WIDTH-1:0] pe_weight_in [PE_COLS],
    input  logic signed [31:0]          pe_acc_out [PE_ROWS][PE_COLS],
    input  logic                        pe_acc_valid [PE_ROWS][PE_COLS],
    
    // Activation function control
    output activation_t                 act_type,
    output logic                        act_enable
);

    //=========================================================================
    // State Machine
    //=========================================================================
    
    typedef enum logic [3:0] {
        IDLE,
        LOAD_WEIGHTS,
        INIT_TILE,
        LOAD_INPUT,
        COMPUTE,
        ACCUMULATE,
        APPLY_ACTIVATION,
        STORE_OUTPUT,
        NEXT_TILE,
        COMPLETE
    } state_t;
    
    state_t state, next_state;
    
    //=========================================================================
    // Tile Parameters
    //=========================================================================
    
    // Tiling dimensions
    localparam int TILE_M = PE_ROWS;  // Output channels per tile
    localparam int TILE_N = PE_COLS;  // Output spatial per tile
    localparam int TILE_K = 16;       // Input channels per iteration
    
    // Convolution parameters (registered)
    logic [15:0] input_h, input_w, input_c;
    logic [15:0] output_h, output_w, output_c;
    logic [3:0]  kernel_h, kernel_w;
    logic [3:0]  stride_h, stride_w;
    logic [3:0]  pad_t, pad_b, pad_l, pad_r;
    activation_t activation;
    
    // Tile counters
    logic [15:0] tile_m_idx;    // Output channel tile index
    logic [15:0] tile_n_idx;    // Output spatial tile index
    logic [15:0] tile_k_idx;    // Input channel tile index
    
    // Within-tile counters
    logic [7:0]  weight_row_cnt;
    logic [7:0]  input_col_cnt;
    logic [7:0]  compute_cnt;
    logic [7:0]  output_cnt;
    
    // Output position
    logic [15:0] out_row, out_col;
    
    //=========================================================================
    // Im2Col Address Calculation
    //=========================================================================
    
    logic [15:0] im2col_row, im2col_col;
    logic [15:0] input_row, input_col;
    logic [15:0] kernel_row, kernel_col;
    logic        is_padding;
    
    // Calculate input position from output position and kernel offset
    always_comb begin
        kernel_row = compute_cnt / kernel_w;
        kernel_col = compute_cnt % kernel_w;
        
        input_row = out_row * stride_h + kernel_row - pad_t;
        input_col = out_col * stride_w + kernel_col - pad_l;
        
        // Check if position is in padding region
        is_padding = (input_row >= input_h) || (input_col >= input_w) ||
                     (input_row[15]) || (input_col[15]);  // Negative check
    end
    
    //=========================================================================
    // Address Generation
    //=========================================================================
    
    // Weight address: [output_channel][input_channel][kernel_h][kernel_w]
    logic [ADDR_WIDTH-1:0] weight_base_addr;
    assign weight_base_addr = (tile_m_idx * input_c * kernel_h * kernel_w) +
                              (tile_k_idx * kernel_h * kernel_w);
    
    // Input address: [batch][input_channel][input_h][input_w]
    logic [ADDR_WIDTH-1:0] input_base_addr;
    assign input_base_addr = (tile_k_idx * input_h * input_w) +
                             (input_row * input_w) + input_col;
    
    // Output address: [batch][output_channel][output_h][output_w]
    logic [ADDR_WIDTH-1:0] output_base_addr;
    assign output_base_addr = (tile_m_idx * output_h * output_w) +
                              (out_row * output_w) + out_col;
    
    //=========================================================================
    // State Machine
    //=========================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end
    
    always_comb begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start)
                    next_state = LOAD_WEIGHTS;
            end
            
            LOAD_WEIGHTS: begin
                if (weight_row_cnt >= TILE_M)
                    next_state = INIT_TILE;
            end
            
            INIT_TILE: begin
                next_state = LOAD_INPUT;
            end
            
            LOAD_INPUT: begin
                if (input_col_cnt >= TILE_N)
                    next_state = COMPUTE;
            end
            
            COMPUTE: begin
                if (compute_cnt >= kernel_h * kernel_w)
                    next_state = ACCUMULATE;
            end
            
            ACCUMULATE: begin
                // Check if more input channel tiles
                if (tile_k_idx + TILE_K < input_c)
                    next_state = LOAD_WEIGHTS;
                else
                    next_state = APPLY_ACTIVATION;
            end
            
            APPLY_ACTIVATION: begin
                next_state = STORE_OUTPUT;
            end
            
            STORE_OUTPUT: begin
                if (output_cnt >= TILE_M * TILE_N)
                    next_state = NEXT_TILE;
            end
            
            NEXT_TILE: begin
                // Check if more tiles
                if (tile_n_idx + TILE_N < output_h * output_w)
                    next_state = INIT_TILE;
                else if (tile_m_idx + TILE_M < output_c)
                    next_state = LOAD_WEIGHTS;
                else
                    next_state = COMPLETE;
            end
            
            COMPLETE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    //=========================================================================
    // Datapath Control
    //=========================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            input_h     <= '0;
            input_w     <= '0;
            input_c     <= '0;
            output_h    <= '0;
            output_w    <= '0;
            output_c    <= '0;
            kernel_h    <= '0;
            kernel_w    <= '0;
            stride_h    <= '0;
            stride_w    <= '0;
            pad_t       <= '0;
            pad_b       <= '0;
            pad_l       <= '0;
            pad_r       <= '0;
            activation  <= ACT_NONE;
            
            tile_m_idx  <= '0;
            tile_n_idx  <= '0;
            tile_k_idx  <= '0;
            
            weight_row_cnt <= '0;
            input_col_cnt  <= '0;
            compute_cnt    <= '0;
            output_cnt     <= '0;
            
            out_row     <= '0;
            out_col     <= '0;
            
            done        <= 1'b0;
        end else begin
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        // Latch convolution parameters
                        input_h    <= conv_params.input_height;
                        input_w    <= conv_params.input_width;
                        input_c    <= conv_params.input_channels;
                        output_c   <= conv_params.output_channels;
                        kernel_h   <= conv_params.kernel_height;
                        kernel_w   <= conv_params.kernel_width;
                        stride_h   <= conv_params.stride_h;
                        stride_w   <= conv_params.stride_w;
                        pad_t      <= conv_params.pad_top;
                        pad_b      <= conv_params.pad_bottom;
                        pad_l      <= conv_params.pad_left;
                        pad_r      <= conv_params.pad_right;
                        activation <= conv_params.activation;
                        
                        // Calculate output dimensions
                        output_h <= (conv_params.input_height + conv_params.pad_top + 
                                    conv_params.pad_bottom - conv_params.kernel_height) / 
                                    conv_params.stride_h + 1;
                        output_w <= (conv_params.input_width + conv_params.pad_left + 
                                    conv_params.pad_right - conv_params.kernel_width) / 
                                    conv_params.stride_w + 1;
                        
                        // Reset tile indices
                        tile_m_idx <= '0;
                        tile_n_idx <= '0;
                        tile_k_idx <= '0;
                    end
                end
                
                LOAD_WEIGHTS: begin
                    if (weight_rd_valid)
                        weight_row_cnt <= weight_row_cnt + 1'b1;
                    
                    if (weight_row_cnt >= TILE_M)
                        weight_row_cnt <= '0;
                end
                
                INIT_TILE: begin
                    input_col_cnt <= '0;
                    compute_cnt   <= '0;
                    
                    // Calculate output position from tile index
                    out_row <= tile_n_idx / output_w;
                    out_col <= tile_n_idx % output_w;
                end
                
                LOAD_INPUT: begin
                    if (act_rd_valid)
                        input_col_cnt <= input_col_cnt + 1'b1;
                end
                
                COMPUTE: begin
                    compute_cnt <= compute_cnt + 1'b1;
                end
                
                ACCUMULATE: begin
                    tile_k_idx <= tile_k_idx + TILE_K;
                    
                    if (tile_k_idx + TILE_K >= input_c)
                        tile_k_idx <= '0;
                end
                
                STORE_OUTPUT: begin
                    output_cnt <= output_cnt + 1'b1;
                    
                    if (output_cnt >= TILE_M * TILE_N)
                        output_cnt <= '0;
                end
                
                NEXT_TILE: begin
                    if (tile_n_idx + TILE_N < output_h * output_w) begin
                        tile_n_idx <= tile_n_idx + TILE_N;
                    end else begin
                        tile_n_idx <= '0;
                        tile_m_idx <= tile_m_idx + TILE_M;
                    end
                end
                
                COMPLETE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end
    
    //=========================================================================
    // Output Assignments
    //=========================================================================
    
    assign busy = (state != IDLE);
    
    // Weight buffer control
    assign weight_rd_en   = (state == LOAD_WEIGHTS);
    assign weight_rd_addr = weight_base_addr + weight_row_cnt;
    
    // Activation buffer control
    assign act_rd_en   = (state == LOAD_INPUT) && !is_padding;
    assign act_rd_addr = input_base_addr;
    assign act_wr_en   = (state == STORE_OUTPUT);
    assign act_wr_addr = output_base_addr + output_cnt;
    
    // PE Array control
    assign pe_enable     = (state == COMPUTE);
    assign pe_clear_acc  = (state == INIT_TILE);
    assign pe_load_weight = (state == LOAD_WEIGHTS) ? {PE_ROWS{1'b1}} : '0;
    
    // Activation control
    assign act_type   = activation;
    assign act_enable = (state == APPLY_ACTIVATION);
    
    // Data unpacking (simplified - actual implementation needs proper im2col)
    generate
        for (genvar i = 0; i < PE_ROWS; i++) begin : gen_pe_data
            assign pe_data_in[i]   = act_rd_data[i*DATA_WIDTH +: DATA_WIDTH];
            assign pe_weight_in[i] = weight_rd_data[i*DATA_WIDTH +: DATA_WIDTH];
        end
    endgenerate
    
    // Output data packing
    generate
        for (genvar i = 0; i < PE_COLS; i++) begin : gen_out_data
            assign act_wr_data[i*DATA_WIDTH +: DATA_WIDTH] = pe_acc_out[0][i][DATA_WIDTH-1:0];
        end
    endgenerate

endmodule
