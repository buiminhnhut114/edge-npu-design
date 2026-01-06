//=============================================================================
// AXI4-Stream Slave Interface
// Streaming data sink for NPU data flow
//=============================================================================

module axi4_stream_slave #(
    parameter int DATA_WIDTH = 128,
    parameter int USER_WIDTH = 4,
    parameter int ID_WIDTH   = 4,
    parameter int FIFO_DEPTH = 16
)(
    input  logic                        clk,
    input  logic                        rst_n,
    
    //=========================================================================
    // AXI4-Stream Slave Interface
    //=========================================================================
    
    input  logic [DATA_WIDTH-1:0]       s_axis_tdata,
    input  logic [DATA_WIDTH/8-1:0]     s_axis_tstrb,
    input  logic [DATA_WIDTH/8-1:0]     s_axis_tkeep,
    input  logic                        s_axis_tlast,
    input  logic [USER_WIDTH-1:0]       s_axis_tuser,
    input  logic [ID_WIDTH-1:0]         s_axis_tid,
    input  logic                        s_axis_tvalid,
    output logic                        s_axis_tready,
    
    //=========================================================================
    // User Interface
    //=========================================================================
    
    output logic [DATA_WIDTH-1:0]       rx_data,
    output logic                        rx_last,
    output logic [USER_WIDTH-1:0]       rx_user,
    output logic [ID_WIDTH-1:0]         rx_id,
    output logic                        rx_valid,
    input  logic                        rx_ready,
    
    // Status
    output logic [$clog2(FIFO_DEPTH):0] fifo_count,
    output logic                        fifo_empty,
    output logic                        fifo_full
);

    //=========================================================================
    // Internal FIFO
    //=========================================================================
    
    localparam FIFO_WIDTH = DATA_WIDTH + 1 + USER_WIDTH + ID_WIDTH;
    
    logic [FIFO_WIDTH-1:0] fifo_mem [FIFO_DEPTH];
    logic [$clog2(FIFO_DEPTH)-1:0] wr_ptr;
    logic [$clog2(FIFO_DEPTH)-1:0] rd_ptr;
    logic [$clog2(FIFO_DEPTH):0]   count;
    
    wire fifo_wr_en = s_axis_tvalid && s_axis_tready;
    wire fifo_rd_en = rx_valid && rx_ready;
    
    //=========================================================================
    // FIFO Write
    //=========================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= '0;
        end else if (fifo_wr_en) begin
            fifo_mem[wr_ptr] <= {s_axis_tdata, s_axis_tlast, s_axis_tuser, s_axis_tid};
            wr_ptr <= wr_ptr + 1;
        end
    end
    
    //=========================================================================
    // FIFO Read
    //=========================================================================
    
    logic [FIFO_WIDTH-1:0] fifo_out;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr <= '0;
        end else if (fifo_rd_en) begin
            rd_ptr <= rd_ptr + 1;
        end
    end
    
    assign fifo_out = fifo_mem[rd_ptr];
    
    // Unpack FIFO output
    assign rx_data = fifo_out[FIFO_WIDTH-1 -: DATA_WIDTH];
    assign rx_last = fifo_out[USER_WIDTH + ID_WIDTH];
    assign rx_user = fifo_out[ID_WIDTH +: USER_WIDTH];
    assign rx_id   = fifo_out[ID_WIDTH-1:0];
    
    //=========================================================================
    // FIFO Count
    //=========================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= '0;
        end else begin
            case ({fifo_wr_en, fifo_rd_en})
                2'b10:   count <= count + 1;
                2'b01:   count <= count - 1;
                default: count <= count;
            endcase
        end
    end
    
    assign fifo_count = count;
    assign fifo_empty = (count == 0);
    assign fifo_full  = (count == FIFO_DEPTH);
    
    //=========================================================================
    // Flow Control
    //=========================================================================
    
    assign s_axis_tready = !fifo_full;
    assign rx_valid      = !fifo_empty;

endmodule
