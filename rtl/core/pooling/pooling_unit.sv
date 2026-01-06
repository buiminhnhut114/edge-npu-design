//=============================================================================
// Pooling Unit
// Supports Max Pooling, Average Pooling, Global Average Pooling
//=============================================================================

module pooling_unit
    import npu_pkg::*;
#(
    parameter int DATA_WIDTH  = 8,
    parameter int MAX_KERNEL  = 3,   // Max kernel size 3x3
    parameter int MAX_CHANNELS = 256
)(
    input  logic                            clk,
    input  logic                            rst_n,
    
    // Control
    input  pooling_t                        pool_type,
    input  logic [1:0]                      kernel_size,  // 0=2x2, 1=3x3
    input  logic                            start,
    output logic                            done,
    output logic                            busy,
    
    // Data interface
    input  logic                            valid_in,
    input  logic signed [DATA_WIDTH-1:0]    data_in,
    output logic                            valid_out,
    output logic signed [DATA_WIDTH-1:0]    data_out
);

    //=========================================================================
    // State Machine
    //=========================================================================
    
    typedef enum logic [1:0] {
        IDLE,
        COLLECT,
        COMPUTE,
        OUTPUT
    } state_t;
    
    state_t state, next_state;
    
    //=========================================================================
    // Internal Signals
    //=========================================================================
    
    logic signed [DATA_WIDTH-1:0] window [MAX_KERNEL*MAX_KERNEL];
    logic [3:0] count;
    logic [3:0] kernel_elements;
    
    logic signed [DATA_WIDTH-1:0] max_val;
    logic signed [DATA_WIDTH+7:0] sum_val;  // Extra bits for accumulation
    logic signed [DATA_WIDTH-1:0] avg_val;
    logic signed [DATA_WIDTH-1:0] result;
    
    //=========================================================================
    // Kernel Size Decode
    //=========================================================================
    
    always_comb begin
        case (kernel_size)
            2'b00:   kernel_elements = 4'd4;   // 2x2
            2'b01:   kernel_elements = 4'd9;   // 3x3
            default: kernel_elements = 4'd4;
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
            IDLE:    if (start) next_state = COLLECT;
            COLLECT: if (count >= kernel_elements) next_state = COMPUTE;
            COMPUTE: next_state = OUTPUT;
            OUTPUT:  next_state = IDLE;
        endcase
    end
    
    //=========================================================================
    // Data Collection
    //=========================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= '0;
            for (int i = 0; i < MAX_KERNEL*MAX_KERNEL; i++)
                window[i] <= '0;
        end else begin
            case (state)
                IDLE: begin
                    count <= '0;
                end
                COLLECT: begin
                    if (valid_in && count < kernel_elements) begin
                        window[count] <= data_in;
                        count <= count + 1'b1;
                    end
                end
            endcase
        end
    end
    
    //=========================================================================
    // Max Pooling
    //=========================================================================
    
    always_comb begin
        max_val = window[0];
        for (int i = 1; i < MAX_KERNEL*MAX_KERNEL; i++) begin
            if (i < kernel_elements && window[i] > max_val)
                max_val = window[i];
        end
    end
    
    //=========================================================================
    // Average Pooling
    //=========================================================================
    
    always_comb begin
        sum_val = '0;
        for (int i = 0; i < MAX_KERNEL*MAX_KERNEL; i++) begin
            if (i < kernel_elements)
                sum_val = sum_val + {{8{window[i][DATA_WIDTH-1]}}, window[i]};
        end
        
        // Divide by kernel elements
        case (kernel_size)
            2'b00:   avg_val = sum_val[DATA_WIDTH+1:2];  // Divide by 4
            2'b01:   avg_val = sum_val / 9;              // Divide by 9
            default: avg_val = sum_val[DATA_WIDTH+1:2];
        endcase
    end
    
    //=========================================================================
    // Output Selection
    //=========================================================================
    
    always_comb begin
        case (pool_type)
            POOL_MAX:    result = max_val;
            POOL_AVG:    result = avg_val;
            POOL_GLOBAL: result = avg_val;
            default:     result = max_val;
        endcase
    end
    
    //=========================================================================
    // Output Register
    //=========================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out  <= '0;
            valid_out <= 1'b0;
            done      <= 1'b0;
        end else begin
            valid_out <= (state == OUTPUT);
            done      <= (state == OUTPUT);
            if (state == COMPUTE)
                data_out <= result;
        end
    end
    
    assign busy = (state != IDLE);

endmodule
