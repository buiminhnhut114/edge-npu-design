//=============================================================================
// Reset Synchronizer
// Synchronizes asynchronous reset deassertion to clock domain
//=============================================================================

module reset_sync #(
    parameter int SYNC_STAGES = 3   // Number of synchronization stages
)(
    input  logic clk,       // Destination clock
    input  logic rst_n_i,   // Asynchronous reset input (active low)
    output logic rst_n_o    // Synchronized reset output (active low)
);

    //=========================================================================
    // Synchronizer Chain
    //=========================================================================
    
    (* ASYNC_REG = "TRUE" *)
    logic [SYNC_STAGES-1:0] sync_chain;
    
    always_ff @(posedge clk or negedge rst_n_i) begin
        if (!rst_n_i) begin
            // Asynchronous reset assertion (immediate)
            sync_chain <= '0;
        end else begin
            // Synchronous reset deassertion
            sync_chain <= {sync_chain[SYNC_STAGES-2:0], 1'b1};
        end
    end
    
    assign rst_n_o = sync_chain[SYNC_STAGES-1];

endmodule
