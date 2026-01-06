//=============================================================================
// AXI4-Lite Slave Interface
// Register access interface for NPU configuration
//=============================================================================

module axi_lite_slave
    import npu_pkg::*;
#(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 32,
    parameter int NUM_REGS   = 64
)(
    input  logic                        clk,
    input  logic                        rst_n,
    
    //=========================================================================
    // AXI4-Lite Interface
    //=========================================================================
    
    // Write Address Channel
    input  logic [ADDR_WIDTH-1:0]       s_axil_awaddr,
    input  logic                        s_axil_awvalid,
    output logic                        s_axil_awready,
    
    // Write Data Channel
    input  logic [DATA_WIDTH-1:0]       s_axil_wdata,
    input  logic [DATA_WIDTH/8-1:0]     s_axil_wstrb,
    input  logic                        s_axil_wvalid,
    output logic                        s_axil_wready,
    
    // Write Response Channel
    output logic [1:0]                  s_axil_bresp,
    output logic                        s_axil_bvalid,
    input  logic                        s_axil_bready,
    
    // Read Address Channel
    input  logic [ADDR_WIDTH-1:0]       s_axil_araddr,
    input  logic                        s_axil_arvalid,
    output logic                        s_axil_arready,
    
    // Read Data Channel
    output logic [DATA_WIDTH-1:0]       s_axil_rdata,
    output logic [1:0]                  s_axil_rresp,
    output logic                        s_axil_rvalid,
    input  logic                        s_axil_rready,
    
    //=========================================================================
    // Register Interface
    //=========================================================================
    
    output logic [DATA_WIDTH-1:0]       reg_wr_data,
    output logic [$clog2(NUM_REGS)-1:0] reg_wr_addr,
    output logic                        reg_wr_en,
    
    output logic [$clog2(NUM_REGS)-1:0] reg_rd_addr,
    output logic                        reg_rd_en,
    input  logic [DATA_WIDTH-1:0]       reg_rd_data
);

    //=========================================================================
    // State Machine
    //=========================================================================
    
    typedef enum logic [1:0] {
        IDLE,
        WRITE,
        READ,
        RESP
    } state_t;
    
    state_t wr_state, rd_state;
    
    //=========================================================================
    // Write State Machine
    //=========================================================================
    
    logic [ADDR_WIDTH-1:0] wr_addr_reg;
    logic [DATA_WIDTH-1:0] wr_data_reg;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_state <= IDLE;
            wr_addr_reg <= '0;
            wr_data_reg <= '0;
        end else begin
            case (wr_state)
                IDLE: begin
                    if (s_axil_awvalid && s_axil_wvalid) begin
                        wr_addr_reg <= s_axil_awaddr;
                        wr_data_reg <= s_axil_wdata;
                        wr_state <= WRITE;
                    end
                end
                WRITE: begin
                    wr_state <= RESP;
                end
                RESP: begin
                    if (s_axil_bready)
                        wr_state <= IDLE;
                end
                default: wr_state <= IDLE;
            endcase
        end
    end
    
    assign s_axil_awready = (wr_state == IDLE);
    assign s_axil_wready  = (wr_state == IDLE);
    assign s_axil_bresp   = 2'b00;  // OKAY
    assign s_axil_bvalid  = (wr_state == RESP);
    
    assign reg_wr_en   = (wr_state == WRITE);
    assign reg_wr_addr = wr_addr_reg[$clog2(NUM_REGS)+1:2];
    assign reg_wr_data = wr_data_reg;
    
    //=========================================================================
    // Read State Machine
    //=========================================================================
    
    logic [ADDR_WIDTH-1:0] rd_addr_reg;
    logic [DATA_WIDTH-1:0] rd_data_reg;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_state <= IDLE;
            rd_addr_reg <= '0;
            rd_data_reg <= '0;
        end else begin
            case (rd_state)
                IDLE: begin
                    if (s_axil_arvalid) begin
                        rd_addr_reg <= s_axil_araddr;
                        rd_state <= READ;
                    end
                end
                READ: begin
                    rd_data_reg <= reg_rd_data;
                    rd_state <= RESP;
                end
                RESP: begin
                    if (s_axil_rready)
                        rd_state <= IDLE;
                end
                default: rd_state <= IDLE;
            endcase
        end
    end
    
    assign s_axil_arready = (rd_state == IDLE);
    assign s_axil_rdata   = rd_data_reg;
    assign s_axil_rresp   = 2'b00;  // OKAY
    assign s_axil_rvalid  = (rd_state == RESP);
    
    assign reg_rd_en   = (rd_state == READ);
    assign reg_rd_addr = rd_addr_reg[$clog2(NUM_REGS)+1:2];

endmodule
