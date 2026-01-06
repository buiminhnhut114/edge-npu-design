//=============================================================================
// Memory Arbiter
// Multi-master memory arbiter with round-robin or priority arbitration
//=============================================================================

module mem_arbiter #(
    parameter int NUM_MASTERS  = 4,
    parameter int ADDR_WIDTH   = 32,
    parameter int DATA_WIDTH   = 128,
    parameter     ARB_TYPE     = "ROUND_ROBIN"  // "ROUND_ROBIN" or "PRIORITY"
)(
    input  logic                            clk,
    input  logic                            rst_n,
    
    //=========================================================================
    // Master Interfaces
    //=========================================================================
    
    input  logic [NUM_MASTERS-1:0]          m_req,
    input  logic [NUM_MASTERS-1:0]          m_wr,
    input  logic [ADDR_WIDTH-1:0]           m_addr  [NUM_MASTERS],
    input  logic [DATA_WIDTH-1:0]           m_wdata [NUM_MASTERS],
    input  logic [DATA_WIDTH/8-1:0]         m_strb  [NUM_MASTERS],
    output logic [NUM_MASTERS-1:0]          m_gnt,
    output logic [DATA_WIDTH-1:0]           m_rdata,
    output logic                            m_rvalid,
    
    //=========================================================================
    // Slave Interface (to memory)
    //=========================================================================
    
    output logic                            s_req,
    output logic                            s_wr,
    output logic [ADDR_WIDTH-1:0]           s_addr,
    output logic [DATA_WIDTH-1:0]           s_wdata,
    output logic [DATA_WIDTH/8-1:0]         s_strb,
    input  logic                            s_gnt,
    input  logic [DATA_WIDTH-1:0]           s_rdata,
    input  logic                            s_rvalid
);

    //=========================================================================
    // Internal Signals
    //=========================================================================
    
    localparam M_IDX_WIDTH = $clog2(NUM_MASTERS);
    
    logic [M_IDX_WIDTH-1:0] current_master;
    logic [M_IDX_WIDTH-1:0] next_master;
    logic [M_IDX_WIDTH-1:0] last_served;
    logic grant_active;
    
    //=========================================================================
    // Arbitration Logic
    //=========================================================================
    
    generate
        if (ARB_TYPE == "ROUND_ROBIN") begin : gen_rr
            
            // Round-robin arbitration
            always_comb begin
                next_master = last_served;
                
                for (int i = 0; i < NUM_MASTERS; i++) begin
                    logic [M_IDX_WIDTH-1:0] idx;
                    idx = (last_served + 1 + i) % NUM_MASTERS;
                    if (m_req[idx]) begin
                        next_master = idx;
                        break;
                    end
                end
            end
            
        end else begin : gen_priority
            
            // Priority arbitration (lower index = higher priority)
            always_comb begin
                next_master = '0;
                
                for (int i = NUM_MASTERS - 1; i >= 0; i--) begin
                    if (m_req[i]) begin
                        next_master = i;
                    end
                end
            end
            
        end
    endgenerate
    
    //=========================================================================
    // Grant FSM
    //=========================================================================
    
    typedef enum logic [1:0] {
        IDLE,
        GRANT,
        WAIT_RESP
    } state_t;
    
    state_t state;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= IDLE;
            current_master <= '0;
            last_served    <= '0;
            grant_active   <= 1'b0;
            m_gnt          <= '0;
            s_req          <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    m_gnt        <= '0;
                    grant_active <= 1'b0;
                    
                    if (|m_req) begin
                        current_master      <= next_master;
                        m_gnt[next_master]  <= 1'b1;
                        s_req               <= 1'b1;
                        state               <= GRANT;
                    end
                end
                
                GRANT: begin
                    if (s_gnt) begin
                        grant_active <= 1'b1;
                        
                        if (m_wr[current_master]) begin
                            // Write - no response needed
                            m_gnt       <= '0;
                            s_req       <= 1'b0;
                            last_served <= current_master;
                            state       <= IDLE;
                        end else begin
                            // Read - wait for response
                            state <= WAIT_RESP;
                        end
                    end
                end
                
                WAIT_RESP: begin
                    if (s_rvalid) begin
                        m_gnt       <= '0;
                        s_req       <= 1'b0;
                        last_served <= current_master;
                        state       <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    //=========================================================================
    // Output Muxing
    //=========================================================================
    
    assign s_wr    = m_wr[current_master];
    assign s_addr  = m_addr[current_master];
    assign s_wdata = m_wdata[current_master];
    assign s_strb  = m_strb[current_master];
    
    assign m_rdata  = s_rdata;
    assign m_rvalid = s_rvalid && grant_active;

endmodule
