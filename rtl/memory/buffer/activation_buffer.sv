//=============================================================================
// Activation Buffer
// 256KB dual-port buffer for input/output activations
//=============================================================================

module activation_buffer
    import npu_pkg::*;
#(
    parameter int DATA_WIDTH = 128,
    parameter int SIZE_KB    = 256,
    parameter int DEPTH      = (SIZE_KB * 1024 * 8) / DATA_WIDTH,
    parameter int ADDR_WIDTH = $clog2(DEPTH)
)(
    input  logic                    clk,
    input  logic                    rst_n,
    
    // Port A - Write (from DMA or PE array output)
    input  logic                    a_en,
    input  logic                    a_we,
    input  logic [ADDR_WIDTH-1:0]   a_addr,
    input  logic [DATA_WIDTH-1:0]   a_wdata,
    output logic [DATA_WIDTH-1:0]   a_rdata,
    
    // Port B - Read (to PE array input)
    input  logic                    b_en,
    input  logic [ADDR_WIDTH-1:0]   b_addr,
    output logic [DATA_WIDTH-1:0]   b_rdata,
    output logic                    b_valid
);

    //=========================================================================
    // Memory Array (True Dual-Port)
    //=========================================================================
    
    logic [DATA_WIDTH-1:0] mem [DEPTH];
    logic b_en_d;
    
    // Port A
    always_ff @(posedge clk) begin
        if (a_en) begin
            if (a_we)
                mem[a_addr] <= a_wdata;
            a_rdata <= mem[a_addr];
        end
    end
    
    // Port B (Read-only)
    always_ff @(posedge clk) begin
        if (b_en)
            b_rdata <= mem[b_addr];
    end
    
    //=========================================================================
    // Read Valid Pipeline
    //=========================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            b_en_d  <= 1'b0;
            b_valid <= 1'b0;
        end else begin
            b_en_d  <= b_en;
            b_valid <= b_en_d;
        end
    end

endmodule
