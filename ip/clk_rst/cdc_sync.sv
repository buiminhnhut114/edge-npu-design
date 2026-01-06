//=============================================================================
// Clock Domain Crossing Synchronizers
// Various CDC techniques: 2FF sync, pulse sync, handshake
//=============================================================================

module cdc_sync #(
    parameter int DATA_WIDTH  = 1,      // Width of data to synchronize
    parameter int SYNC_STAGES = 2,      // Number of sync stages
    parameter     CDC_TYPE    = "2FF"   // "2FF", "PULSE", "HANDSHAKE"
)(
    // Source domain
    input  logic                    src_clk,
    input  logic                    src_rst_n,
    input  logic [DATA_WIDTH-1:0]   src_data,
    input  logic                    src_valid,
    output logic                    src_ready,
    
    // Destination domain
    input  logic                    dst_clk,
    input  logic                    dst_rst_n,
    output logic [DATA_WIDTH-1:0]   dst_data,
    output logic                    dst_valid
);

    //=========================================================================
    // 2FF Synchronizer (for slow-changing signals)
    //=========================================================================
    
    generate
        if (CDC_TYPE == "2FF") begin : gen_2ff
            
            (* ASYNC_REG = "TRUE" *)
            logic [DATA_WIDTH-1:0] sync_chain [SYNC_STAGES];
            
            always_ff @(posedge dst_clk or negedge dst_rst_n) begin
                if (!dst_rst_n) begin
                    for (int i = 0; i < SYNC_STAGES; i++) begin
                        sync_chain[i] <= '0;
                    end
                end else begin
                    sync_chain[0] <= src_data;
                    for (int i = 1; i < SYNC_STAGES; i++) begin
                        sync_chain[i] <= sync_chain[i-1];
                    end
                end
            end
            
            assign dst_data  = sync_chain[SYNC_STAGES-1];
            assign dst_valid = 1'b1;  // Always valid for 2FF
            assign src_ready = 1'b1;  // Always ready for 2FF
            
        end
    endgenerate
    
    //=========================================================================
    // Pulse Synchronizer (for single-cycle pulses)
    //=========================================================================
    
    generate
        if (CDC_TYPE == "PULSE") begin : gen_pulse
            
            // Toggle in source domain
            logic src_toggle;
            
            always_ff @(posedge src_clk or negedge src_rst_n) begin
                if (!src_rst_n) begin
                    src_toggle <= 1'b0;
                end else if (src_valid) begin
                    src_toggle <= ~src_toggle;
                end
            end
            
            // Synchronize toggle to destination
            (* ASYNC_REG = "TRUE" *)
            logic [SYNC_STAGES-1:0] toggle_sync;
            logic toggle_prev;
            
            always_ff @(posedge dst_clk or negedge dst_rst_n) begin
                if (!dst_rst_n) begin
                    toggle_sync <= '0;
                    toggle_prev <= 1'b0;
                end else begin
                    toggle_sync <= {toggle_sync[SYNC_STAGES-2:0], src_toggle};
                    toggle_prev <= toggle_sync[SYNC_STAGES-1];
                end
            end
            
            // Edge detect generates pulse in destination
            assign dst_valid = toggle_sync[SYNC_STAGES-1] ^ toggle_prev;
            assign dst_data  = src_data;  // Data must be stable
            assign src_ready = 1'b1;
            
        end
    endgenerate
    
    //=========================================================================
    // Handshake Synchronizer (for reliable transfer)
    //=========================================================================
    
    generate
        if (CDC_TYPE == "HANDSHAKE") begin : gen_handshake
            
            // Source domain state
            typedef enum logic [1:0] {
                SRC_IDLE,
                SRC_WAIT_ACK,
                SRC_WAIT_DONE
            } src_state_t;
            
            src_state_t src_state;
            logic src_req;
            logic [DATA_WIDTH-1:0] src_data_reg;
            
            // Destination domain state
            typedef enum logic [1:0] {
                DST_IDLE,
                DST_ACK
            } dst_state_t;
            
            dst_state_t dst_state;
            logic dst_ack;
            
            // Cross-domain signals
            (* ASYNC_REG = "TRUE" *)
            logic [SYNC_STAGES-1:0] req_sync;
            (* ASYNC_REG = "TRUE" *)
            logic [SYNC_STAGES-1:0] ack_sync;
            
            // Sync request to destination
            always_ff @(posedge dst_clk or negedge dst_rst_n) begin
                if (!dst_rst_n)
                    req_sync <= '0;
                else
                    req_sync <= {req_sync[SYNC_STAGES-2:0], src_req};
            end
            
            // Sync ack to source
            always_ff @(posedge src_clk or negedge src_rst_n) begin
                if (!src_rst_n)
                    ack_sync <= '0;
                else
                    ack_sync <= {ack_sync[SYNC_STAGES-2:0], dst_ack};
            end
            
            // Source FSM
            always_ff @(posedge src_clk or negedge src_rst_n) begin
                if (!src_rst_n) begin
                    src_state    <= SRC_IDLE;
                    src_req      <= 1'b0;
                    src_data_reg <= '0;
                end else begin
                    case (src_state)
                        SRC_IDLE: begin
                            if (src_valid) begin
                                src_data_reg <= src_data;
                                src_req      <= 1'b1;
                                src_state    <= SRC_WAIT_ACK;
                            end
                        end
                        SRC_WAIT_ACK: begin
                            if (ack_sync[SYNC_STAGES-1]) begin
                                src_req   <= 1'b0;
                                src_state <= SRC_WAIT_DONE;
                            end
                        end
                        SRC_WAIT_DONE: begin
                            if (!ack_sync[SYNC_STAGES-1]) begin
                                src_state <= SRC_IDLE;
                            end
                        end
                        default: src_state <= SRC_IDLE;
                    endcase
                end
            end
            
            assign src_ready = (src_state == SRC_IDLE);
            
            // Destination FSM
            always_ff @(posedge dst_clk or negedge dst_rst_n) begin
                if (!dst_rst_n) begin
                    dst_state <= DST_IDLE;
                    dst_ack   <= 1'b0;
                    dst_data  <= '0;
                    dst_valid <= 1'b0;
                end else begin
                    dst_valid <= 1'b0;
                    
                    case (dst_state)
                        DST_IDLE: begin
                            if (req_sync[SYNC_STAGES-1]) begin
                                dst_data  <= src_data_reg;
                                dst_valid <= 1'b1;
                                dst_ack   <= 1'b1;
                                dst_state <= DST_ACK;
                            end
                        end
                        DST_ACK: begin
                            if (!req_sync[SYNC_STAGES-1]) begin
                                dst_ack   <= 1'b0;
                                dst_state <= DST_IDLE;
                            end
                        end
                        default: dst_state <= DST_IDLE;
                    endcase
                end
            end
            
        end
    endgenerate

endmodule
