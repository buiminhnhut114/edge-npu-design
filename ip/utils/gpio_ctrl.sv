//=============================================================================
// GPIO Controller
// General Purpose I/O controller with direction control
//=============================================================================

module gpio_ctrl #(
    parameter int GPIO_WIDTH = 32,
    parameter int ADDR_WIDTH = 8,
    parameter int DATA_WIDTH = 32,
    parameter int SYNC_STAGES = 2
)(
    input  logic                        clk,
    input  logic                        rst_n,
    
    // GPIO pins
    input  logic [GPIO_WIDTH-1:0]       gpio_in,
    output logic [GPIO_WIDTH-1:0]       gpio_out,
    output logic [GPIO_WIDTH-1:0]       gpio_oe,    // Output enable (1=output, 0=input)
    
    // Interrupt
    output logic                        gpio_irq,
    
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
    
    localparam REG_DATA_IN   = 8'h00;  // R   - Input data
    localparam REG_DATA_OUT  = 8'h04;  // R/W - Output data
    localparam REG_DIR       = 8'h08;  // R/W - Direction (1=out, 0=in)
    localparam REG_IRQ_EN    = 8'h0C;  // R/W - IRQ enable
    localparam REG_IRQ_TYPE  = 8'h10;  // R/W - IRQ type (0=level, 1=edge)
    localparam REG_IRQ_POL   = 8'h14;  // R/W - IRQ polarity (0=high/rising, 1=low/falling)
    localparam REG_IRQ_STATUS= 8'h18;  // R/W1C - IRQ status
    localparam REG_SET       = 8'h1C;  // W   - Set output bits
    localparam REG_CLR       = 8'h20;  // W   - Clear output bits
    localparam REG_TOGGLE    = 8'h24;  // W   - Toggle output bits
    
    //=========================================================================
    // Registers
    //=========================================================================
    
    logic [GPIO_WIDTH-1:0] data_out_reg;
    logic [GPIO_WIDTH-1:0] dir_reg;
    logic [GPIO_WIDTH-1:0] irq_enable;
    logic [GPIO_WIDTH-1:0] irq_type;
    logic [GPIO_WIDTH-1:0] irq_polarity;
    logic [GPIO_WIDTH-1:0] irq_status;
    
    //=========================================================================
    // Input Synchronization
    //=========================================================================
    
    (* ASYNC_REG = "TRUE" *)
    logic [GPIO_WIDTH-1:0] gpio_in_sync [SYNC_STAGES];
    logic [GPIO_WIDTH-1:0] gpio_in_synced;
    logic [GPIO_WIDTH-1:0] gpio_in_d;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < SYNC_STAGES; i++) begin
                gpio_in_sync[i] <= '0;
            end
            gpio_in_d <= '0;
        end else begin
            gpio_in_sync[0] <= gpio_in;
            for (int i = 1; i < SYNC_STAGES; i++) begin
                gpio_in_sync[i] <= gpio_in_sync[i-1];
            end
            gpio_in_d <= gpio_in_synced;
        end
    end
    
    assign gpio_in_synced = gpio_in_sync[SYNC_STAGES-1];
    
    //=========================================================================
    // Output Register
    //=========================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out_reg <= '0;
            dir_reg      <= '0;
        end else if (reg_wr) begin
            case (reg_addr)
                REG_DATA_OUT: data_out_reg <= reg_wdata[GPIO_WIDTH-1:0];
                REG_DIR:      dir_reg      <= reg_wdata[GPIO_WIDTH-1:0];
                REG_SET:      data_out_reg <= data_out_reg | reg_wdata[GPIO_WIDTH-1:0];
                REG_CLR:      data_out_reg <= data_out_reg & ~reg_wdata[GPIO_WIDTH-1:0];
                REG_TOGGLE:   data_out_reg <= data_out_reg ^ reg_wdata[GPIO_WIDTH-1:0];
            endcase
        end
    end
    
    assign gpio_out = data_out_reg;
    assign gpio_oe  = dir_reg;
    
    //=========================================================================
    // Interrupt Configuration
    //=========================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            irq_enable   <= '0;
            irq_type     <= '0;
            irq_polarity <= '0;
        end else if (reg_wr) begin
            case (reg_addr)
                REG_IRQ_EN:   irq_enable   <= reg_wdata[GPIO_WIDTH-1:0];
                REG_IRQ_TYPE: irq_type     <= reg_wdata[GPIO_WIDTH-1:0];
                REG_IRQ_POL:  irq_polarity <= reg_wdata[GPIO_WIDTH-1:0];
            endcase
        end
    end
    
    //=========================================================================
    // Interrupt Detection
    //=========================================================================
    
    logic [GPIO_WIDTH-1:0] irq_detect;
    
    always_comb begin
        for (int i = 0; i < GPIO_WIDTH; i++) begin
            if (irq_type[i]) begin
                // Edge triggered
                if (irq_polarity[i]) begin
                    // Falling edge
                    irq_detect[i] = gpio_in_d[i] & ~gpio_in_synced[i];
                end else begin
                    // Rising edge
                    irq_detect[i] = ~gpio_in_d[i] & gpio_in_synced[i];
                end
            end else begin
                // Level triggered
                irq_detect[i] = irq_polarity[i] ? ~gpio_in_synced[i] : gpio_in_synced[i];
            end
        end
    end
    
    //=========================================================================
    // Interrupt Status
    //=========================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            irq_status <= '0;
        end else begin
            for (int i = 0; i < GPIO_WIDTH; i++) begin
                if (irq_type[i]) begin
                    // Edge - latch
                    if (irq_detect[i]) begin
                        irq_status[i] <= 1'b1;
                    end else if (reg_wr && reg_addr == REG_IRQ_STATUS && reg_wdata[i]) begin
                        irq_status[i] <= 1'b0;
                    end
                end else begin
                    // Level - direct
                    irq_status[i] <= irq_detect[i];
                end
            end
        end
    end
    
    assign gpio_irq = |(irq_status & irq_enable);
    
    //=========================================================================
    // Register Read
    //=========================================================================
    
    always_comb begin
        reg_rdata = '0;
        case (reg_addr)
            REG_DATA_IN:    reg_rdata = {{(DATA_WIDTH-GPIO_WIDTH){1'b0}}, gpio_in_synced};
            REG_DATA_OUT:   reg_rdata = {{(DATA_WIDTH-GPIO_WIDTH){1'b0}}, data_out_reg};
            REG_DIR:        reg_rdata = {{(DATA_WIDTH-GPIO_WIDTH){1'b0}}, dir_reg};
            REG_IRQ_EN:     reg_rdata = {{(DATA_WIDTH-GPIO_WIDTH){1'b0}}, irq_enable};
            REG_IRQ_TYPE:   reg_rdata = {{(DATA_WIDTH-GPIO_WIDTH){1'b0}}, irq_type};
            REG_IRQ_POL:    reg_rdata = {{(DATA_WIDTH-GPIO_WIDTH){1'b0}}, irq_polarity};
            REG_IRQ_STATUS: reg_rdata = {{(DATA_WIDTH-GPIO_WIDTH){1'b0}}, irq_status};
            default:        reg_rdata = '0;
        endcase
    end

endmodule
