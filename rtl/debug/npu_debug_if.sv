//=============================================================================
// NPU Debug Interface
// Wrapper for Advanced Debug Interface adapted for NPU
// Based on adv_dbg_if from OpenCores
//=============================================================================

module npu_debug_if
    import npu_pkg::*;
#(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32
)(
    input  logic                        clk,
    input  logic                        rst_n,
    
    // JTAG Interface
    input  logic                        tck,        // JTAG clock
    input  logic                        tms,        // JTAG mode select
    input  logic                        tdi,        // JTAG data in
    output logic                        tdo,        // JTAG data out
    input  logic                        trst_n,     // JTAG reset
    
    // Debug Register Access (to NPU registers)
    output logic                        dbg_req,
    output logic                        dbg_we,
    output logic [ADDR_WIDTH-1:0]       dbg_addr,
    output logic [DATA_WIDTH-1:0]       dbg_wdata,
    input  logic [DATA_WIDTH-1:0]       dbg_rdata,
    input  logic                        dbg_ack,
    input  logic                        dbg_err,
    
    // Debug Memory Access (to buffers)
    output logic                        mem_req,
    output logic                        mem_we,
    output logic [ADDR_WIDTH-1:0]       mem_addr,
    output logic [DATA_WIDTH-1:0]       mem_wdata,
    input  logic [DATA_WIDTH-1:0]       mem_rdata,
    input  logic                        mem_ack,
    
    // NPU Control
    output logic                        dbg_halt,       // Halt NPU execution
    output logic                        dbg_resume,     // Resume execution
    output logic                        dbg_step,       // Single step
    input  logic                        npu_halted,     // NPU is halted
    
    // Breakpoint interface
    output logic                        bp_enable,
    output logic [ADDR_WIDTH-1:0]       bp_addr,
    input  logic                        bp_hit,
    
    // Status
    output logic                        dbg_active
);

    //=========================================================================
    // JTAG TAP Controller
    //=========================================================================
    
    typedef enum logic [3:0] {
        TAP_RESET,
        TAP_IDLE,
        TAP_DR_SELECT,
        TAP_DR_CAPTURE,
        TAP_DR_SHIFT,
        TAP_DR_EXIT1,
        TAP_DR_PAUSE,
        TAP_DR_EXIT2,
        TAP_DR_UPDATE,
        TAP_IR_SELECT,
        TAP_IR_CAPTURE,
        TAP_IR_SHIFT,
        TAP_IR_EXIT1,
        TAP_IR_PAUSE,
        TAP_IR_EXIT2,
        TAP_IR_UPDATE
    } tap_state_t;
    
    tap_state_t tap_state, tap_next;
    
    // TAP state machine
    always_ff @(posedge tck or negedge trst_n) begin
        if (!trst_n)
            tap_state <= TAP_RESET;
        else
            tap_state <= tap_next;
    end
    
    always_comb begin
        case (tap_state)
            TAP_RESET:      tap_next = tms ? TAP_RESET : TAP_IDLE;
            TAP_IDLE:       tap_next = tms ? TAP_DR_SELECT : TAP_IDLE;
            TAP_DR_SELECT:  tap_next = tms ? TAP_IR_SELECT : TAP_DR_CAPTURE;
            TAP_DR_CAPTURE: tap_next = tms ? TAP_DR_EXIT1 : TAP_DR_SHIFT;
            TAP_DR_SHIFT:   tap_next = tms ? TAP_DR_EXIT1 : TAP_DR_SHIFT;
            TAP_DR_EXIT1:   tap_next = tms ? TAP_DR_UPDATE : TAP_DR_PAUSE;
            TAP_DR_PAUSE:   tap_next = tms ? TAP_DR_EXIT2 : TAP_DR_PAUSE;
            TAP_DR_EXIT2:   tap_next = tms ? TAP_DR_UPDATE : TAP_DR_SHIFT;
            TAP_DR_UPDATE:  tap_next = tms ? TAP_DR_SELECT : TAP_IDLE;
            TAP_IR_SELECT:  tap_next = tms ? TAP_RESET : TAP_IR_CAPTURE;
            TAP_IR_CAPTURE: tap_next = tms ? TAP_IR_EXIT1 : TAP_IR_SHIFT;
            TAP_IR_SHIFT:   tap_next = tms ? TAP_IR_EXIT1 : TAP_IR_SHIFT;
            TAP_IR_EXIT1:   tap_next = tms ? TAP_IR_UPDATE : TAP_IR_PAUSE;
            TAP_IR_PAUSE:   tap_next = tms ? TAP_IR_EXIT2 : TAP_IR_PAUSE;
            TAP_IR_EXIT2:   tap_next = tms ? TAP_IR_UPDATE : TAP_IR_SHIFT;
            TAP_IR_UPDATE:  tap_next = tms ? TAP_DR_SELECT : TAP_IDLE;
            default:        tap_next = TAP_RESET;
        endcase
    end
    
    //=========================================================================
    // Instruction Register
    //=========================================================================
    
    localparam int IR_WIDTH = 5;
    
    // JTAG Instructions
    localparam logic [IR_WIDTH-1:0] IR_BYPASS   = 5'b11111;
    localparam logic [IR_WIDTH-1:0] IR_IDCODE   = 5'b00001;
    localparam logic [IR_WIDTH-1:0] IR_DEBUG    = 5'b00010;
    localparam logic [IR_WIDTH-1:0] IR_MBIST    = 5'b00011;
    localparam logic [IR_WIDTH-1:0] IR_REGACC   = 5'b00100;
    localparam logic [IR_WIDTH-1:0] IR_MEMACC   = 5'b00101;
    
    logic [IR_WIDTH-1:0] ir_reg, ir_shift;
    
    always_ff @(posedge tck or negedge trst_n) begin
        if (!trst_n) begin
            ir_reg   <= IR_IDCODE;
            ir_shift <= '0;
        end else begin
            if (tap_state == TAP_IR_CAPTURE)
                ir_shift <= ir_reg;
            else if (tap_state == TAP_IR_SHIFT)
                ir_shift <= {tdi, ir_shift[IR_WIDTH-1:1]};
            else if (tap_state == TAP_IR_UPDATE)
                ir_reg <= ir_shift;
        end
    end
    
    //=========================================================================
    // Data Registers
    //=========================================================================
    
    // ID Code Register (32-bit)
    localparam logic [31:0] IDCODE = 32'hEDGE_0001;  // EdgeNPU ID
    
    logic [31:0] idcode_shift;
    logic [63:0] debug_shift;    // Debug data register
    logic        bypass_reg;
    
    // Shift registers
    always_ff @(posedge tck or negedge trst_n) begin
        if (!trst_n) begin
            idcode_shift <= IDCODE;
            debug_shift  <= '0;
            bypass_reg   <= 1'b0;
        end else begin
            case (tap_state)
                TAP_DR_CAPTURE: begin
                    case (ir_reg)
                        IR_IDCODE: idcode_shift <= IDCODE;
                        IR_DEBUG:  debug_shift  <= {dbg_rdata, mem_rdata};
                        IR_REGACC: debug_shift  <= {32'b0, dbg_rdata};
                        IR_MEMACC: debug_shift  <= {32'b0, mem_rdata};
                        default:   bypass_reg   <= 1'b0;
                    endcase
                end
                
                TAP_DR_SHIFT: begin
                    case (ir_reg)
                        IR_IDCODE: idcode_shift <= {tdi, idcode_shift[31:1]};
                        IR_DEBUG:  debug_shift  <= {tdi, debug_shift[63:1]};
                        IR_REGACC: debug_shift  <= {tdi, debug_shift[63:1]};
                        IR_MEMACC: debug_shift  <= {tdi, debug_shift[63:1]};
                        IR_BYPASS: bypass_reg   <= tdi;
                        default:   bypass_reg   <= tdi;
                    endcase
                end
            endcase
        end
    end
    
    //=========================================================================
    // TDO Output Mux
    //=========================================================================
    
    logic tdo_reg;
    
    always_comb begin
        if (tap_state == TAP_IR_SHIFT)
            tdo_reg = ir_shift[0];
        else begin
            case (ir_reg)
                IR_IDCODE: tdo_reg = idcode_shift[0];
                IR_DEBUG:  tdo_reg = debug_shift[0];
                IR_REGACC: tdo_reg = debug_shift[0];
                IR_MEMACC: tdo_reg = debug_shift[0];
                default:   tdo_reg = bypass_reg;
            endcase
        end
    end
    
    // TDO is updated on negative edge
    always_ff @(negedge tck or negedge trst_n) begin
        if (!trst_n)
            tdo <= 1'b0;
        else
            tdo <= tdo_reg;
    end
    
    //=========================================================================
    // Debug Command Processing
    //=========================================================================
    
    // Command format in debug_shift:
    // [63:62] - Command type (00=read, 01=write, 10=halt, 11=resume)
    // [61:32] - Address
    // [31:0]  - Write data
    
    logic [1:0]  cmd_type;
    logic [29:0] cmd_addr;
    logic [31:0] cmd_data;
    
    assign cmd_type = debug_shift[63:62];
    assign cmd_addr = debug_shift[61:32];
    assign cmd_data = debug_shift[31:0];
    
    // Process commands on DR_UPDATE
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dbg_req    <= 1'b0;
            dbg_we     <= 1'b0;
            dbg_addr   <= '0;
            dbg_wdata  <= '0;
            mem_req    <= 1'b0;
            mem_we     <= 1'b0;
            mem_addr   <= '0;
            mem_wdata  <= '0;
            dbg_halt   <= 1'b0;
            dbg_resume <= 1'b0;
            dbg_step   <= 1'b0;
        end else begin
            // Default: clear single-cycle signals
            dbg_req    <= 1'b0;
            mem_req    <= 1'b0;
            dbg_resume <= 1'b0;
            dbg_step   <= 1'b0;
            
            // Synchronize JTAG update to system clock
            if (tap_state == TAP_DR_UPDATE) begin
                case (ir_reg)
                    IR_REGACC: begin
                        dbg_req   <= 1'b1;
                        dbg_we    <= cmd_type[0];
                        dbg_addr  <= {2'b0, cmd_addr};
                        dbg_wdata <= cmd_data;
                    end
                    
                    IR_MEMACC: begin
                        mem_req   <= 1'b1;
                        mem_we    <= cmd_type[0];
                        mem_addr  <= {2'b0, cmd_addr};
                        mem_wdata <= cmd_data;
                    end
                    
                    IR_DEBUG: begin
                        case (cmd_type)
                            2'b10: dbg_halt   <= 1'b1;
                            2'b11: dbg_resume <= 1'b1;
                            2'b01: dbg_step   <= 1'b1;
                            default: ;
                        endcase
                    end
                endcase
            end
            
            // Clear halt when resume is issued
            if (dbg_resume)
                dbg_halt <= 1'b0;
        end
    end
    
    //=========================================================================
    // Breakpoint Logic
    //=========================================================================
    
    logic [ADDR_WIDTH-1:0] bp_addr_reg;
    logic                  bp_enable_reg;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bp_addr_reg   <= '0;
            bp_enable_reg <= 1'b0;
        end else if (tap_state == TAP_DR_UPDATE && ir_reg == IR_DEBUG) begin
            if (cmd_type == 2'b00) begin  // Set breakpoint
                bp_addr_reg   <= {2'b0, cmd_addr};
                bp_enable_reg <= 1'b1;
            end
        end
    end
    
    assign bp_addr   = bp_addr_reg;
    assign bp_enable = bp_enable_reg;
    
    //=========================================================================
    // Status
    //=========================================================================
    
    assign dbg_active = (tap_state != TAP_RESET) && (tap_state != TAP_IDLE);

endmodule
