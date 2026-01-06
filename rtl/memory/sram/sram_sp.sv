//=============================================================================
// Single-Port SRAM
// Generic synchronous SRAM for weight/activation buffers
//=============================================================================

module sram_sp #(
    parameter int DATA_WIDTH = 128,
    parameter int DEPTH      = 2048,
    parameter int ADDR_WIDTH = $clog2(DEPTH)
)(
    input  logic                    clk,
    input  logic                    rst_n,
    
    // Port
    input  logic                    en,
    input  logic                    we,
    input  logic [ADDR_WIDTH-1:0]   addr,
    input  logic [DATA_WIDTH-1:0]   wdata,
    output logic [DATA_WIDTH-1:0]   rdata
);

    //=========================================================================
    // Memory Array
    //=========================================================================
    
    logic [DATA_WIDTH-1:0] mem [DEPTH];
    
    //=========================================================================
    // Read/Write Logic
    //=========================================================================
    
    always_ff @(posedge clk) begin
        if (en) begin
            if (we)
                mem[addr] <= wdata;
            rdata <= mem[addr];
        end
    end

endmodule
