//=============================================================================
// PE Array Wrapper
// Adapts opensource pe_array to EdgeNPU interface
// Original: pe_array-master from GitHub
//=============================================================================

module pe_array_wrapper
    import npu_pkg::*;
#(
    parameter int PE_NUM      = 8,
    parameter int DATA_WIDTH  = 16,
    parameter int INST_WIDTH  = 32
)(
    input  logic                            clk,
    input  logic                            rst_n,
    
    // NPU Control Interface
    input  logic                            enable,
    input  logic                            start,
    output logic                            done,
    output logic                            busy,
    
    // Data Input (from activation buffer)
    input  logic                            data_valid,
    input  logic [DATA_WIDTH*2-1:0]         data_in,
    
    // Data Output (to next stage)
    output logic                            data_out_valid,
    output logic [DATA_WIDTH*2-1:0]         data_out,
    
    // Configuration
    input  logic [7:0]                      num_iterations
);

    //=========================================================================
    // Internal Signals
    //=========================================================================
    
    logic                       rst;
    logic                       load;
    logic                       din_overlay_v;
    logic [DATA_WIDTH*2-1:0]    din_overlay;
    logic                       dout_overlay_v;
    logic [DATA_WIDTH*2-1:0]    dout_overlay;
    
    assign rst = ~rst_n;
    
    //=========================================================================
    // Control FSM
    //=========================================================================
    
    typedef enum logic [2:0] {
        IDLE,
        LOADING,
        PROCESSING,
        OUTPUT,
        COMPLETE
    } state_t;
    
    state_t state, next_state;
    logic [15:0] cycle_cnt;
    logic [7:0]  iter_cnt;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end
    
    always_comb begin
        next_state = state;
        case (state)
            IDLE:       if (start && enable) next_state = LOADING;
            LOADING:    if (!data_valid) next_state = PROCESSING;
            PROCESSING: if (dout_overlay_v) next_state = OUTPUT;
            OUTPUT:     if (!dout_overlay_v) next_state = COMPLETE;
            COMPLETE:   next_state = IDLE;
            default:    next_state = IDLE;
        endcase
    end
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_cnt <= '0;
            iter_cnt  <= '0;
        end else begin
            case (state)
                IDLE: begin
                    cycle_cnt <= '0;
                    iter_cnt  <= '0;
                end
                LOADING, PROCESSING, OUTPUT: begin
                    cycle_cnt <= cycle_cnt + 1'b1;
                end
            endcase
        end
    end
    
    //=========================================================================
    // Interface Mapping
    //=========================================================================
    
    assign din_overlay_v = (state == LOADING) && data_valid;
    assign din_overlay   = data_in;
    assign load          = (state == OUTPUT);
    
    assign data_out_valid = dout_overlay_v;
    assign data_out       = dout_overlay;
    assign busy           = (state != IDLE);
    assign done           = (state == COMPLETE);
    
    //=========================================================================
    // Instantiate Original PE Array
    //=========================================================================
    
    pe_array u_pe_array (
        .clk            (clk),
        .rst            (rst),
        .load           (load),
        .din_overlay_v  (din_overlay_v),
        .din_overlay    (din_overlay),
        .dout_overlay_v (dout_overlay_v),
        .dout_overlay   (dout_overlay)
    );

endmodule
