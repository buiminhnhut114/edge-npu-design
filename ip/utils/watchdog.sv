//=============================================================================
// Watchdog Timer
// System watchdog with configurable timeout and reset capability
//=============================================================================

module watchdog #(
    parameter int COUNTER_WIDTH = 32,
    parameter int ADDR_WIDTH = 8,
    parameter int DATA_WIDTH = 32
)(
    input  logic                        clk,
    input  logic                        rst_n,
    
    // Watchdog outputs
    output logic                        wdt_reset,      // System reset
    output logic                        wdt_irq,        // Early warning interrupt
    
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
    
    localparam REG_CTRL    = 8'h00;  // R/W - Control register
    localparam REG_TIMEOUT = 8'h04;  // R/W - Timeout value
    localparam REG_COUNT   = 8'h08;  // R   - Current count
    localparam REG_KICK    = 8'h0C;  // W   - Kick/reload (write magic value)
    localparam REG_WARN    = 8'h10;  // R/W - Early warning threshold
    
    // Control bits
    localparam CTRL_EN       = 0;
    localparam CTRL_RST_EN   = 1;  // Enable reset on timeout
    localparam CTRL_IRQ_EN   = 2;  // Enable early warning IRQ
    localparam CTRL_LOCK     = 3;  // Lock configuration
    
    // Magic value for kick
    localparam KICK_MAGIC = 32'h5A5A_A5A5;
    
    //=========================================================================
    // Registers
    //=========================================================================
    
    logic [7:0] ctrl_reg;
    logic [COUNTER_WIDTH-1:0] timeout_reg;
    logic [COUNTER_WIDTH-1:0] count_reg;
    logic [COUNTER_WIDTH-1:0] warn_threshold;
    logic locked;
    
    //=========================================================================
    // Watchdog Counter
    //=========================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count_reg <= '0;
        end else if (ctrl_reg[CTRL_EN]) begin
            // Kick detection
            if (reg_wr && reg_addr == REG_KICK && reg_wdata == KICK_MAGIC) begin
                count_reg <= '0;
            end else begin
                count_reg <= count_reg + 1;
            end
        end else begin
            count_reg <= '0;
        end
    end
    
    //=========================================================================
    // Timeout Detection
    //=========================================================================
    
    logic timeout;
    logic warning;
    
    assign timeout = (count_reg >= timeout_reg) && ctrl_reg[CTRL_EN];
    assign warning = (count_reg >= warn_threshold) && ctrl_reg[CTRL_EN];
    
    //=========================================================================
    // Reset Generation
    //=========================================================================
    
    // Use a pulse stretcher for reset
    logic [3:0] reset_pulse;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reset_pulse <= '0;
        end else begin
            if (timeout && ctrl_reg[CTRL_RST_EN]) begin
                reset_pulse <= 4'hF;
            end else if (reset_pulse > 0) begin
                reset_pulse <= reset_pulse - 1;
            end
        end
    end
    
    assign wdt_reset = (reset_pulse > 0);
    
    //=========================================================================
    // Early Warning IRQ
    //=========================================================================
    
    logic warning_latched;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            warning_latched <= 1'b0;
        end else begin
            if (warning && !warning_latched) begin
                warning_latched <= 1'b1;
            end else if (!ctrl_reg[CTRL_EN] || 
                        (reg_wr && reg_addr == REG_KICK && reg_wdata == KICK_MAGIC)) begin
                warning_latched <= 1'b0;
            end
        end
    end
    
    assign wdt_irq = warning_latched && ctrl_reg[CTRL_IRQ_EN];
    
    //=========================================================================
    // Configuration Registers
    //=========================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ctrl_reg       <= '0;
            timeout_reg    <= '1;  // Max timeout by default
            warn_threshold <= '1;
            locked         <= 1'b0;
        end else if (reg_wr && !locked) begin
            case (reg_addr)
                REG_CTRL: begin
                    ctrl_reg <= reg_wdata[7:0];
                    if (reg_wdata[CTRL_LOCK]) begin
                        locked <= 1'b1;
                    end
                end
                REG_TIMEOUT: timeout_reg    <= reg_wdata[COUNTER_WIDTH-1:0];
                REG_WARN:    warn_threshold <= reg_wdata[COUNTER_WIDTH-1:0];
            endcase
        end
    end
    
    //=========================================================================
    // Register Read
    //=========================================================================
    
    always_comb begin
        reg_rdata = '0;
        case (reg_addr)
            REG_CTRL:    reg_rdata = {{(DATA_WIDTH-8){1'b0}}, ctrl_reg};
            REG_TIMEOUT: reg_rdata = timeout_reg;
            REG_COUNT:   reg_rdata = count_reg;
            REG_WARN:    reg_rdata = warn_threshold;
            default:     reg_rdata = '0;
        endcase
    end

endmodule
