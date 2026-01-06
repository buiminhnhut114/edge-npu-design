//=============================================================================
// Dual-Port SRAM
// True dual-port SRAM with independent read/write ports
//=============================================================================

module sram_dp #(
    parameter int DATA_WIDTH = 128,
    parameter int DEPTH      = 2048,
    parameter int ADDR_WIDTH = $clog2(DEPTH)
)(
    // Port A
    input  logic                    clk_a,
    input  logic                    en_a,
    input  logic                    we_a,
    input  logic [ADDR_WIDTH-1:0]   addr_a,
    input  logic [DATA_WIDTH-1:0]   wdata_a,
    output logic [DATA_WIDTH-1:0]   rdata_a,
    
    // Port B
    input  logic                    clk_b,
    input  logic                    en_b,
    input  logic                    we_b,
    input  logic [ADDR_WIDTH-1:0]   addr_b,
    input  logic [DATA_WIDTH-1:0]   wdata_b,
    output logic [DATA_WIDTH-1:0]   rdata_b
);

    //=========================================================================
    // Memory Array
    //=========================================================================
    
    (* ram_style = "block" *)
    logic [DATA_WIDTH-1:0] mem [DEPTH];
    
    //=========================================================================
    // Port A
    //=========================================================================
    
    always_ff @(posedge clk_a) begin
        if (en_a) begin
            if (we_a) begin
                mem[addr_a] <= wdata_a;
            end
            rdata_a <= mem[addr_a];
        end
    end
    
    //=========================================================================
    // Port B
    //=========================================================================
    
    always_ff @(posedge clk_b) begin
        if (en_b) begin
            if (we_b) begin
                mem[addr_b] <= wdata_b;
            end
            rdata_b <= mem[addr_b];
        end
    end

endmodule
