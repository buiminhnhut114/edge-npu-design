//=============================================================================
// Interrupt Controller
// Multi-source interrupt controller with masking and pending registers
//=============================================================================

module interrupt_ctrl #(
    parameter int NUM_IRQS = 32,
    parameter int ADDR_WIDTH = 8,
    parameter int DATA_WIDTH = 32
)(
    input  logic                        clk,
    input  logic                        rst_n,
    
    // Interrupt sources
    input  logic [NUM_IRQS-1:0]         irq_in,
    
    // Consolidated interrupt output
    output logic                        irq_out,
    
    //=========================================================================
    // Register Interface
    //=========================================================================
    
    input  logic                        reg_wr,
    input  logic [ADDR_WIDTH-1:0]       reg_addr,
    input  logic [DATA_WIDTH-1:0]       reg_wdata,
    output logic [DATA_WIDTH-1:0]       reg_rdata
);

    //=========================================================================
    // Register Map
    //=========================================================================
    
    // Address offsets
    localparam REG_IRQ_STATUS  = 8'h00;  // R/W1C - Interrupt status (pending)
    localparam REG_IRQ_ENABLE  = 8'h04;  // R/W   - Interrupt enable mask
    localparam REG_IRQ_TYPE    = 8'h08;  // R/W   - 0=level, 1=edge triggered
    localparam REG_IRQ_POL     = 8'h0C;  // R/W   - 0=active high, 1=active low
    localparam REG_IRQ_PRIO    = 8'h10;  // R/W   - Priority (optional)
    localparam REG_IRQ_PENDING = 8'h14;  // R     - RAW pending (before mask)
    
    //=========================================================================
    // Registers
    //=========================================================================
    
    logic [NUM_IRQS-1:0] irq_status;
    logic [NUM_IRQS-1:0] irq_enable;
    logic [NUM_IRQS-1:0] irq_type;     // 0=level, 1=edge
    logic [NUM_IRQS-1:0] irq_polarity; // 0=active high, 1=active low
    
    logic [NUM_IRQS-1:0] irq_in_d;
    logic [NUM_IRQS-1:0] irq_edge_detect;
    logic [NUM_IRQS-1:0] irq_active;
    
    //=========================================================================
    // Edge Detection
    //=========================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            irq_in_d <= '0;
        end else begin
            irq_in_d <= irq_in;
        end
    end
    
    // Detect rising/falling edge based on polarity
    always_comb begin
        for (int i = 0; i < NUM_IRQS; i++) begin
            if (irq_polarity[i]) begin
                // Active low - detect falling edge
                irq_edge_detect[i] = irq_in_d[i] & ~irq_in[i];
            end else begin
                // Active high - detect rising edge
                irq_edge_detect[i] = ~irq_in_d[i] & irq_in[i];
            end
        end
    end
    
    //=========================================================================
    // Active Interrupt Determination
    //=========================================================================
    
    always_comb begin
        for (int i = 0; i < NUM_IRQS; i++) begin
            if (irq_type[i]) begin
                // Edge triggered - use latched status
                irq_active[i] = irq_status[i];
            end else begin
                // Level triggered - use direct input (with polarity)
                irq_active[i] = irq_polarity[i] ? ~irq_in[i] : irq_in[i];
            end
        end
    end
    
    //=========================================================================
    // Interrupt Status Register
    //=========================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            irq_status <= '0;
        end else begin
            for (int i = 0; i < NUM_IRQS; i++) begin
                // Set on edge detect (for edge-triggered)
                if (irq_type[i] && irq_edge_detect[i]) begin
                    irq_status[i] <= 1'b1;
                end
                // Set on level (for level-triggered)
                else if (!irq_type[i]) begin
                    irq_status[i] <= irq_polarity[i] ? ~irq_in[i] : irq_in[i];
                end
                // Clear on W1C
                else if (reg_wr && reg_addr == REG_IRQ_STATUS && reg_wdata[i]) begin
                    irq_status[i] <= 1'b0;
                end
            end
        end
    end
    
    //=========================================================================
    // Configuration Registers
    //=========================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            irq_enable   <= '0;
            irq_type     <= '0;
            irq_polarity <= '0;
        end else if (reg_wr) begin
            case (reg_addr)
                REG_IRQ_ENABLE: irq_enable   <= reg_wdata[NUM_IRQS-1:0];
                REG_IRQ_TYPE:   irq_type     <= reg_wdata[NUM_IRQS-1:0];
                REG_IRQ_POL:    irq_polarity <= reg_wdata[NUM_IRQS-1:0];
            endcase
        end
    end
    
    //=========================================================================
    // Register Read
    //=========================================================================
    
    always_comb begin
        reg_rdata = '0;
        case (reg_addr)
            REG_IRQ_STATUS:  reg_rdata = {{(DATA_WIDTH-NUM_IRQS){1'b0}}, irq_status};
            REG_IRQ_ENABLE:  reg_rdata = {{(DATA_WIDTH-NUM_IRQS){1'b0}}, irq_enable};
            REG_IRQ_TYPE:    reg_rdata = {{(DATA_WIDTH-NUM_IRQS){1'b0}}, irq_type};
            REG_IRQ_POL:     reg_rdata = {{(DATA_WIDTH-NUM_IRQS){1'b0}}, irq_polarity};
            REG_IRQ_PENDING: reg_rdata = {{(DATA_WIDTH-NUM_IRQS){1'b0}}, irq_active};
            default:         reg_rdata = '0;
        endcase
    end
    
    //=========================================================================
    // IRQ Output
    //=========================================================================
    
    assign irq_out = |(irq_active & irq_enable);

endmodule
