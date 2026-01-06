//=============================================================================
// Tensor Reshape Unit
// Handles transpose, reshape, and permute operations
//=============================================================================

module tensor_reshape
    import npu_pkg::*;
#(
    parameter int DATA_WIDTH = 8,
    parameter int MAX_DIM    = 4     // Max tensor dimensions
)(
    input  logic                        clk,
    input  logic                        rst_n,
    
    // Control
    input  logic                        start,
    input  logic [2:0]                  op_type,        // 0=reshape, 1=transpose, 2=permute, 3=flatten
    input  logic [15:0]                 src_dims [MAX_DIM],  // Source dimensions
    input  logic [15:0]                 dst_dims [MAX_DIM],  // Destination dimensions
    input  logic [1:0]                  permute_order [MAX_DIM], // For permute op
    output logic                        done,
    output logic                        busy,
    
    // Input interface
    input  logic                        valid_in,
    input  logic [DATA_WIDTH-1:0]       data_in,
    
    // Output interface
    output logic                        valid_out,
    output logic [DATA_WIDTH-1:0]       data_out,
    
    // Address generation (for external memory access)
    output logic [31:0]                 src_addr,
    output logic [31:0]                 dst_addr
);

    //=========================================================================
    // Operation Types
    //=========================================================================
    
    localparam logic [2:0] OP_RESHAPE   = 3'b000;
    localparam logic [2:0] OP_TRANSPOSE = 3'b001;
    localparam logic [2:0] OP_PERMUTE   = 3'b010;
    localparam logic [2:0] OP_FLATTEN   = 3'b011;
    
    //=========================================================================
    // State Machine
    //=========================================================================
    
    typedef enum logic [2:0] {
        IDLE,
        CALC_ADDR,
        READ_DATA,
        WRITE_DATA,
        COMPLETE
    } state_t;
    
    state_t state, next_state;
    
    //=========================================================================
    // Index Counters
    //=========================================================================
    
    logic [15:0] idx [MAX_DIM];
    logic [31:0] total_elements;
    logic [31:0] element_cnt;
    
    // Calculate total elements
    always_comb begin
        total_elements = src_dims[0];
        for (int i = 1; i < MAX_DIM; i++) begin
            if (src_dims[i] != 0)
                total_elements = total_elements * src_dims[i];
        end
    end
    
    //=========================================================================
    // Address Calculation
    //=========================================================================
    
    // Source address: linear index from multi-dimensional index
    always_comb begin
        src_addr = idx[0];
        for (int i = 1; i < MAX_DIM; i++) begin
            if (src_dims[i] != 0) begin
                logic [31:0] stride = 1;
                for (int j = 0; j < i; j++)
                    stride = stride * src_dims[j];
                src_addr = src_addr + idx[i] * stride;
            end
        end
    end
    
    // Destination address based on operation
    always_comb begin
        case (op_type)
            OP_RESHAPE, OP_FLATTEN: begin
                // Same linear order, just different interpretation
                dst_addr = src_addr;
            end
            
            OP_TRANSPOSE: begin
                // Swap last two dimensions (for 2D transpose)
                dst_addr = idx[1] * src_dims[0] + idx[0];
            end
            
            OP_PERMUTE: begin
                // General permutation
                logic [15:0] perm_idx [MAX_DIM];
                for (int i = 0; i < MAX_DIM; i++)
                    perm_idx[i] = idx[permute_order[i]];
                    
                dst_addr = perm_idx[0];
                for (int i = 1; i < MAX_DIM; i++) begin
                    if (dst_dims[i] != 0) begin
                        logic [31:0] stride = 1;
                        for (int j = 0; j < i; j++)
                            stride = stride * dst_dims[j];
                        dst_addr = dst_addr + perm_idx[i] * stride;
                    end
                end
            end
            
            default: dst_addr = src_addr;
        endcase
    end
    
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
            IDLE:       if (start) next_state = CALC_ADDR;
            CALC_ADDR:  next_state = READ_DATA;
            READ_DATA:  if (valid_in) next_state = WRITE_DATA;
            WRITE_DATA: begin
                if (element_cnt >= total_elements - 1)
                    next_state = COMPLETE;
                else
                    next_state = CALC_ADDR;
            end
            COMPLETE:   next_state = IDLE;
            default:    next_state = IDLE;
        endcase
    end
    
    //=========================================================================
    // Index Update
    //=========================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < MAX_DIM; i++)
                idx[i] <= '0;
            element_cnt <= '0;
        end else begin
            case (state)
                IDLE: begin
                    for (int i = 0; i < MAX_DIM; i++)
                        idx[i] <= '0;
                    element_cnt <= '0;
                end
                
                WRITE_DATA: begin
                    element_cnt <= element_cnt + 1'b1;
                    
                    // Increment multi-dimensional index
                    idx[0] <= idx[0] + 1'b1;
                    for (int i = 0; i < MAX_DIM-1; i++) begin
                        if (idx[i] >= src_dims[i] - 1) begin
                            idx[i] <= '0;
                            idx[i+1] <= idx[i+1] + 1'b1;
                        end
                    end
                end
            endcase
        end
    end
    
    //=========================================================================
    // Output
    //=========================================================================
    
    assign data_out  = data_in;
    assign valid_out = (state == WRITE_DATA) && valid_in;
    assign busy      = (state != IDLE);
    assign done      = (state == COMPLETE);

endmodule
