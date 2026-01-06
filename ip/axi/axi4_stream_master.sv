//=============================================================================
// AXI4-Stream Master Interface
// Streaming data source for NPU data flow
//=============================================================================

module axi4_stream_master #(
    parameter int DATA_WIDTH = 128,
    parameter int USER_WIDTH = 4,
    parameter int ID_WIDTH   = 4
)(
    input  logic                        clk,
    input  logic                        rst_n,
    
    //=========================================================================
    // User Interface
    //=========================================================================
    
    input  logic                        start,
    input  logic [DATA_WIDTH-1:0]       tx_data,
    input  logic                        tx_last,
    input  logic [USER_WIDTH-1:0]       tx_user,
    input  logic [ID_WIDTH-1:0]         tx_id,
    input  logic                        tx_valid,
    output logic                        tx_ready,
    
    //=========================================================================
    // AXI4-Stream Master Interface
    //=========================================================================
    
    output logic [DATA_WIDTH-1:0]       m_axis_tdata,
    output logic [DATA_WIDTH/8-1:0]     m_axis_tstrb,
    output logic [DATA_WIDTH/8-1:0]     m_axis_tkeep,
    output logic                        m_axis_tlast,
    output logic [USER_WIDTH-1:0]       m_axis_tuser,
    output logic [ID_WIDTH-1:0]         m_axis_tid,
    output logic                        m_axis_tvalid,
    input  logic                        m_axis_tready
);

    //=========================================================================
    // Stream Logic
    //=========================================================================
    
    // Pass-through with registered outputs for timing
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_axis_tdata  <= '0;
            m_axis_tlast  <= 1'b0;
            m_axis_tuser  <= '0;
            m_axis_tid    <= '0;
            m_axis_tvalid <= 1'b0;
        end else begin
            if (tx_valid && tx_ready) begin
                m_axis_tdata  <= tx_data;
                m_axis_tlast  <= tx_last;
                m_axis_tuser  <= tx_user;
                m_axis_tid    <= tx_id;
                m_axis_tvalid <= 1'b1;
            end else if (m_axis_tready) begin
                m_axis_tvalid <= 1'b0;
            end
        end
    end
    
    // Backpressure handling
    assign tx_ready = !m_axis_tvalid || m_axis_tready;
    
    // All bytes valid
    assign m_axis_tstrb = {(DATA_WIDTH/8){1'b1}};
    assign m_axis_tkeep = {(DATA_WIDTH/8){1'b1}};

endmodule
