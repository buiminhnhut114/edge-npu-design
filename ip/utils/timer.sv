//=============================================================================
// Timer Module
// Configurable timer with prescaler, one-shot, and continuous modes
//=============================================================================

module timer #(
    parameter int TIMER_WIDTH = 32,
    parameter int PRESCALER_WIDTH = 16,
    parameter int ADDR_WIDTH = 8,
    parameter int DATA_WIDTH = 32
)(
    input  logic                        clk,
    input  logic                        rst_n,
    
    // Timer interrupt
    output logic                        timer_irq,
    
    // PWM output (optional)
    output logic                        pwm_out,
    
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
    
    localparam REG_CTRL     = 8'h00;  // R/W - Control register
    localparam REG_STATUS   = 8'h04;  // R/W1C - Status register
    localparam REG_PRESCALE = 8'h08;  // R/W - Prescaler value
    localparam REG_COMPARE  = 8'h0C;  // R/W - Compare value
    localparam REG_COUNT    = 8'h10;  // R/W - Current count
    localparam REG_PWM_CMP  = 8'h14;  // R/W - PWM compare (duty cycle)
    
    // Control register bits
    localparam CTRL_EN       = 0;  // Timer enable
    localparam CTRL_ONESHOT  = 1;  // One-shot mode (0=continuous)
    localparam CTRL_IRQ_EN   = 2;  // Interrupt enable
    localparam CTRL_PWM_EN   = 3;  // PWM enable
    localparam CTRL_COUNT_UP = 4;  // Count direction (0=down, 1=up)
    
    //=========================================================================
    // Registers
    //=========================================================================
    
    logic [7:0] ctrl_reg;
    logic status_flag;
    logic [PRESCALER_WIDTH-1:0] prescale_reg;
    logic [TIMER_WIDTH-1:0] compare_reg;
    logic [TIMER_WIDTH-1:0] count_reg;
    logic [TIMER_WIDTH-1:0] pwm_cmp_reg;
    
    logic [PRESCALER_WIDTH-1:0] prescale_cnt;
    logic tick;
    
    //=========================================================================
    // Prescaler
    //=========================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prescale_cnt <= '0;
            tick         <= 1'b0;
        end else if (ctrl_reg[CTRL_EN]) begin
            if (prescale_cnt == prescale_reg) begin
                prescale_cnt <= '0;
                tick         <= 1'b1;
            end else begin
                prescale_cnt <= prescale_cnt + 1;
                tick         <= 1'b0;
            end
        end else begin
            prescale_cnt <= '0;
            tick         <= 1'b0;
        end
    end
    
    //=========================================================================
    // Counter
    //=========================================================================
    
    logic match;
    assign match = (count_reg == compare_reg);
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count_reg <= '0;
        end else if (reg_wr && reg_addr == REG_COUNT) begin
            count_reg <= reg_wdata[TIMER_WIDTH-1:0];
        end else if (ctrl_reg[CTRL_EN] && tick) begin
            if (match) begin
                if (ctrl_reg[CTRL_ONESHOT]) begin
                    // One-shot: stop
                end else begin
                    // Continuous: reload
                    count_reg <= '0;
                end
            end else begin
                if (ctrl_reg[CTRL_COUNT_UP]) begin
                    count_reg <= count_reg + 1;
                end else begin
                    count_reg <= count_reg - 1;
                end
            end
        end
    end
    
    //=========================================================================
    // Status and Interrupt
    //=========================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            status_flag <= 1'b0;
        end else begin
            if (ctrl_reg[CTRL_EN] && tick && match) begin
                status_flag <= 1'b1;
            end else if (reg_wr && reg_addr == REG_STATUS && reg_wdata[0]) begin
                status_flag <= 1'b0;
            end
        end
    end
    
    assign timer_irq = status_flag && ctrl_reg[CTRL_IRQ_EN];
    
    //=========================================================================
    // PWM Output
    //=========================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pwm_out <= 1'b0;
        end else if (ctrl_reg[CTRL_PWM_EN]) begin
            pwm_out <= (count_reg < pwm_cmp_reg);
        end else begin
            pwm_out <= 1'b0;
        end
    end
    
    //=========================================================================
    // Control Register
    //=========================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ctrl_reg     <= '0;
            prescale_reg <= '0;
            compare_reg  <= '1;
            pwm_cmp_reg  <= '0;
        end else if (reg_wr) begin
            case (reg_addr)
                REG_CTRL:     ctrl_reg     <= reg_wdata[7:0];
                REG_PRESCALE: prescale_reg <= reg_wdata[PRESCALER_WIDTH-1:0];
                REG_COMPARE:  compare_reg  <= reg_wdata[TIMER_WIDTH-1:0];
                REG_PWM_CMP:  pwm_cmp_reg  <= reg_wdata[TIMER_WIDTH-1:0];
            endcase
        end else if (ctrl_reg[CTRL_ONESHOT] && tick && match) begin
            // Auto-disable on one-shot completion
            ctrl_reg[CTRL_EN] <= 1'b0;
        end
    end
    
    //=========================================================================
    // Register Read
    //=========================================================================
    
    always_comb begin
        reg_rdata = '0;
        case (reg_addr)
            REG_CTRL:     reg_rdata = {{(DATA_WIDTH-8){1'b0}}, ctrl_reg};
            REG_STATUS:   reg_rdata = {{(DATA_WIDTH-1){1'b0}}, status_flag};
            REG_PRESCALE: reg_rdata = {{(DATA_WIDTH-PRESCALER_WIDTH){1'b0}}, prescale_reg};
            REG_COMPARE:  reg_rdata = compare_reg;
            REG_COUNT:    reg_rdata = count_reg;
            REG_PWM_CMP:  reg_rdata = pwm_cmp_reg;
            default:      reg_rdata = '0;
        endcase
    end

endmodule
