//=============================================================================
// Data Reshaper
// Tensor reshape and transpose operations (NHWC <-> NCHW)
//=============================================================================

module data_reshaper
    import npu_pkg::*;
#(
    parameter int DATA_WIDTH = 8,
    parameter int MAX_DIM    = 256,    // Maximum dimension size
    parameter int BUFFER_DEPTH = 1024  // Internal buffer size
)(
    input  logic                        clk,
    input  logic                        rst_n,
    
    //=========================================================================
    // Configuration
    //=========================================================================
    
    input  logic [1:0]                  mode,           // 0=passthrough, 1=transpose, 2=NHWC->NCHW, 3=NCHW->NHWC
    input  logic [15:0]                 dim_h,          // Height
    input  logic [15:0]                 dim_w,          // Width
    input  logic [15:0]                 dim_c,          // Channels
    input  logic                        start,
    output logic                        busy,
    output logic                        done,
    
    //=========================================================================
    // Input Stream
    //=========================================================================
    
    input  logic                        in_valid,
    input  logic [DATA_WIDTH-1:0]       in_data,
    output logic                        in_ready,
    
    //=========================================================================
    // Output Stream
    //=========================================================================
    
    output logic                        out_valid,
    output logic [DATA_WIDTH-1:0]       out_data,
    input  logic                        out_ready
);

    localparam ADDR_WIDTH = $clog2(BUFFER_DEPTH);
    
    //=========================================================================
    // Internal Buffer (used for transpose operations)
    //=========================================================================
    
    logic [DATA_WIDTH-1:0] buffer [BUFFER_DEPTH];
    logic [ADDR_WIDTH-1:0] wr_addr;
    logic [ADDR_WIDTH-1:0] rd_addr;
    
    //=========================================================================
    // State Machine
    //=========================================================================
    
    typedef enum logic [2:0] {
        IDLE,
        FILL_BUFFER,
        DRAIN_BUFFER,
        PASSTHROUGH,
        COMPLETE
    } state_t;
    
    state_t state;
    
    logic [15:0] cnt_h, cnt_w, cnt_c;
    logic [31:0] total_elements;
    logic [31:0] element_cnt;
    
    //=========================================================================
    // Address Calculation
    //=========================================================================
    
    // NHWC: index = h * W * C + w * C + c
    // NCHW: index = c * H * W + h * W + w
    
    function automatic logic [ADDR_WIDTH-1:0] calc_nhwc_addr(
        input logic [15:0] h, w, c,
        input logic [15:0] H, W, C
    );
        return (h * W * C + w * C + c) % BUFFER_DEPTH;
    endfunction
    
    function automatic logic [ADDR_WIDTH-1:0] calc_nchw_addr(
        input logic [15:0] h, w, c,
        input logic [15:0] H, W, C
    );
        return (c * H * W + h * W + w) % BUFFER_DEPTH;
    endfunction
    
    //=========================================================================
    // Main FSM
    //=========================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= IDLE;
            busy           <= 1'b0;
            done           <= 1'b0;
            wr_addr        <= '0;
            rd_addr        <= '0;
            cnt_h          <= '0;
            cnt_w          <= '0;
            cnt_c          <= '0;
            element_cnt    <= '0;
            total_elements <= '0;
        end else begin
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        busy           <= 1'b1;
                        total_elements <= dim_h * dim_w * dim_c;
                        element_cnt    <= '0;
                        cnt_h          <= '0;
                        cnt_w          <= '0;
                        cnt_c          <= '0;
                        wr_addr        <= '0;
                        rd_addr        <= '0;
                        
                        if (mode == 2'b00) begin
                            state <= PASSTHROUGH;
                        end else begin
                            state <= FILL_BUFFER;
                        end
                    end
                end
                
                PASSTHROUGH: begin
                    if (in_valid && in_ready && out_ready) begin
                        element_cnt <= element_cnt + 1;
                        if (element_cnt == total_elements - 1) begin
                            state <= COMPLETE;
                        end
                    end
                end
                
                FILL_BUFFER: begin
                    if (in_valid && in_ready) begin
                        // Write to buffer at NHWC address
                        buffer[wr_addr] <= in_data;
                        
                        // Update counters
                        if (cnt_c == dim_c - 1) begin
                            cnt_c <= '0;
                            if (cnt_w == dim_w - 1) begin
                                cnt_w <= '0;
                                if (cnt_h == dim_h - 1) begin
                                    cnt_h <= '0;
                                    state <= DRAIN_BUFFER;
                                end else begin
                                    cnt_h <= cnt_h + 1;
                                end
                            end else begin
                                cnt_w <= cnt_w + 1;
                            end
                        end else begin
                            cnt_c <= cnt_c + 1;
                        end
                        
                        wr_addr <= wr_addr + 1;
                        element_cnt <= element_cnt + 1;
                    end
                end
                
                DRAIN_BUFFER: begin
                    if (out_valid && out_ready) begin
                        // Read from buffer in NCHW order (or vice versa)
                        case (mode)
                            2'b01: begin // Simple transpose (swap last two dims)
                                rd_addr <= calc_nchw_addr(cnt_h, cnt_w, cnt_c, dim_h, dim_w, dim_c);
                            end
                            2'b10: begin // NHWC -> NCHW
                                rd_addr <= calc_nchw_addr(cnt_h, cnt_w, cnt_c, dim_h, dim_w, dim_c);
                            end
                            2'b11: begin // NCHW -> NHWC
                                rd_addr <= calc_nhwc_addr(cnt_h, cnt_w, cnt_c, dim_h, dim_w, dim_c);
                            end
                            default: rd_addr <= rd_addr + 1;
                        endcase
                        
                        // Update drain counters (output in target order)
                        if (mode == 2'b10) begin
                            // Output in NCHW order: c, h, w
                            if (cnt_w == dim_w - 1) begin
                                cnt_w <= '0;
                                if (cnt_h == dim_h - 1) begin
                                    cnt_h <= '0;
                                    if (cnt_c == dim_c - 1) begin
                                        state <= COMPLETE;
                                    end else begin
                                        cnt_c <= cnt_c + 1;
                                    end
                                end else begin
                                    cnt_h <= cnt_h + 1;
                                end
                            end else begin
                                cnt_w <= cnt_w + 1;
                            end
                        end else begin
                            // Output in NHWC order: h, w, c
                            if (cnt_c == dim_c - 1) begin
                                cnt_c <= '0;
                                if (cnt_w == dim_w - 1) begin
                                    cnt_w <= '0;
                                    if (cnt_h == dim_h - 1) begin
                                        state <= COMPLETE;
                                    end else begin
                                        cnt_h <= cnt_h + 1;
                                    end
                                end else begin
                                    cnt_w <= cnt_w + 1;
                                end
                            end else begin
                                cnt_c <= cnt_c + 1;
                            end
                        end
                    end
                end
                
                COMPLETE: begin
                    done  <= 1'b1;
                    busy  <= 1'b0;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    //=========================================================================
    // Flow Control
    //=========================================================================
    
    assign in_ready = (state == FILL_BUFFER) || (state == PASSTHROUGH && out_ready);
    
    assign out_valid = (state == DRAIN_BUFFER) || (state == PASSTHROUGH && in_valid);
    assign out_data = (state == PASSTHROUGH) ? in_data : buffer[rd_addr];

endmodule
