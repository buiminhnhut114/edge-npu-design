//=============================================================================
// Performance Counter
// Hardware performance monitoring for NPU
//=============================================================================

module perf_counter
    import npu_pkg::*;
#(
    parameter int NUM_COUNTERS = 8,
    parameter int COUNTER_WIDTH = 48,
    parameter int ADDR_WIDTH = 8,
    parameter int DATA_WIDTH = 32
)(
    input  logic                        clk,
    input  logic                        rst_n,
    
    //=========================================================================
    // Event Inputs
    //=========================================================================
    
    input  logic                        pe_active,      // PE array computing
    input  logic                        pe_stall,       // PE stalled
    input  logic                        mem_read,       // Memory read
    input  logic                        mem_write,      // Memory write
    input  logic                        dma_active,     // DMA transfer active
    input  logic                        cache_hit,      // Cache hit
    input  logic                        cache_miss,     // Cache miss
    input  logic                        instr_complete, // Instruction completed
    
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
    
    localparam REG_CTRL          = 8'h00;  // R/W - Control
    localparam REG_STATUS        = 8'h04;  // R   - Status
    localparam REG_CYCLE_LO      = 8'h10;  // R   - Cycle counter low
    localparam REG_CYCLE_HI      = 8'h14;  // R   - Cycle counter high
    localparam REG_PE_ACTIVE_LO  = 8'h20;  // R   - PE active cycles low
    localparam REG_PE_ACTIVE_HI  = 8'h24;  // R   - PE active cycles high
    localparam REG_PE_STALL_LO   = 8'h28;  // R   - PE stall cycles low
    localparam REG_PE_STALL_HI   = 8'h2C;  // R   - PE stall cycles high
    localparam REG_MEM_READ_LO   = 8'h30;  // R   - Memory reads low
    localparam REG_MEM_READ_HI   = 8'h34;  // R   - Memory reads high
    localparam REG_MEM_WRITE_LO  = 8'h38;  // R   - Memory writes low
    localparam REG_MEM_WRITE_HI  = 8'h3C;  // R   - Memory writes high
    localparam REG_DMA_CYCLES_LO = 8'h40;  // R   - DMA cycles low
    localparam REG_DMA_CYCLES_HI = 8'h44;  // R   - DMA cycles high
    localparam REG_CACHE_HIT_LO  = 8'h48;  // R   - Cache hits low
    localparam REG_CACHE_HIT_HI  = 8'h4C;  // R   - Cache hits high
    localparam REG_CACHE_MISS_LO = 8'h50;  // R   - Cache misses low
    localparam REG_CACHE_MISS_HI = 8'h54;  // R   - Cache misses high
    localparam REG_INSTR_CNT_LO  = 8'h58;  // R   - Instructions low
    localparam REG_INSTR_CNT_HI  = 8'h5C;  // R   - Instructions high
    
    // Control bits
    localparam CTRL_EN    = 0;
    localparam CTRL_RESET = 1;
    localparam CTRL_FREEZE = 2;
    
    //=========================================================================
    // Control Register
    //=========================================================================
    
    logic [7:0] ctrl_reg;
    logic counting;
    logic frozen;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ctrl_reg <= '0;
        end else if (reg_wr && reg_addr == REG_CTRL) begin
            ctrl_reg <= reg_wdata[7:0];
        end else begin
            ctrl_reg[CTRL_RESET] <= 1'b0;  // Auto-clear reset bit
        end
    end
    
    assign counting = ctrl_reg[CTRL_EN] && !ctrl_reg[CTRL_FREEZE];
    assign frozen   = ctrl_reg[CTRL_FREEZE];
    
    //=========================================================================
    // Counters
    //=========================================================================
    
    logic [COUNTER_WIDTH-1:0] cycle_cnt;
    logic [COUNTER_WIDTH-1:0] pe_active_cnt;
    logic [COUNTER_WIDTH-1:0] pe_stall_cnt;
    logic [COUNTER_WIDTH-1:0] mem_read_cnt;
    logic [COUNTER_WIDTH-1:0] mem_write_cnt;
    logic [COUNTER_WIDTH-1:0] dma_cycles_cnt;
    logic [COUNTER_WIDTH-1:0] cache_hit_cnt;
    logic [COUNTER_WIDTH-1:0] cache_miss_cnt;
    logic [COUNTER_WIDTH-1:0] instr_cnt;
    
    // Cycle counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || ctrl_reg[CTRL_RESET]) begin
            cycle_cnt <= '0;
        end else if (counting) begin
            cycle_cnt <= cycle_cnt + 1;
        end
    end
    
    // PE active counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || ctrl_reg[CTRL_RESET]) begin
            pe_active_cnt <= '0;
        end else if (counting && pe_active) begin
            pe_active_cnt <= pe_active_cnt + 1;
        end
    end
    
    // PE stall counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || ctrl_reg[CTRL_RESET]) begin
            pe_stall_cnt <= '0;
        end else if (counting && pe_stall) begin
            pe_stall_cnt <= pe_stall_cnt + 1;
        end
    end
    
    // Memory read counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || ctrl_reg[CTRL_RESET]) begin
            mem_read_cnt <= '0;
        end else if (counting && mem_read) begin
            mem_read_cnt <= mem_read_cnt + 1;
        end
    end
    
    // Memory write counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || ctrl_reg[CTRL_RESET]) begin
            mem_write_cnt <= '0;
        end else if (counting && mem_write) begin
            mem_write_cnt <= mem_write_cnt + 1;
        end
    end
    
    // DMA cycles counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || ctrl_reg[CTRL_RESET]) begin
            dma_cycles_cnt <= '0;
        end else if (counting && dma_active) begin
            dma_cycles_cnt <= dma_cycles_cnt + 1;
        end
    end
    
    // Cache hit counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || ctrl_reg[CTRL_RESET]) begin
            cache_hit_cnt <= '0;
        end else if (counting && cache_hit) begin
            cache_hit_cnt <= cache_hit_cnt + 1;
        end
    end
    
    // Cache miss counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || ctrl_reg[CTRL_RESET]) begin
            cache_miss_cnt <= '0;
        end else if (counting && cache_miss) begin
            cache_miss_cnt <= cache_miss_cnt + 1;
        end
    end
    
    // Instruction counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || ctrl_reg[CTRL_RESET]) begin
            instr_cnt <= '0;
        end else if (counting && instr_complete) begin
            instr_cnt <= instr_cnt + 1;
        end
    end
    
    //=========================================================================
    // Register Read
    //=========================================================================
    
    always_comb begin
        reg_rdata = '0;
        case (reg_addr)
            REG_CTRL:          reg_rdata = {{(DATA_WIDTH-8){1'b0}}, ctrl_reg};
            REG_STATUS:        reg_rdata = {{(DATA_WIDTH-2){1'b0}}, frozen, counting};
            REG_CYCLE_LO:      reg_rdata = cycle_cnt[31:0];
            REG_CYCLE_HI:      reg_rdata = {{(DATA_WIDTH-(COUNTER_WIDTH-32)){1'b0}}, cycle_cnt[COUNTER_WIDTH-1:32]};
            REG_PE_ACTIVE_LO:  reg_rdata = pe_active_cnt[31:0];
            REG_PE_ACTIVE_HI:  reg_rdata = {{(DATA_WIDTH-(COUNTER_WIDTH-32)){1'b0}}, pe_active_cnt[COUNTER_WIDTH-1:32]};
            REG_PE_STALL_LO:   reg_rdata = pe_stall_cnt[31:0];
            REG_PE_STALL_HI:   reg_rdata = {{(DATA_WIDTH-(COUNTER_WIDTH-32)){1'b0}}, pe_stall_cnt[COUNTER_WIDTH-1:32]};
            REG_MEM_READ_LO:   reg_rdata = mem_read_cnt[31:0];
            REG_MEM_READ_HI:   reg_rdata = {{(DATA_WIDTH-(COUNTER_WIDTH-32)){1'b0}}, mem_read_cnt[COUNTER_WIDTH-1:32]};
            REG_MEM_WRITE_LO:  reg_rdata = mem_write_cnt[31:0];
            REG_MEM_WRITE_HI:  reg_rdata = {{(DATA_WIDTH-(COUNTER_WIDTH-32)){1'b0}}, mem_write_cnt[COUNTER_WIDTH-1:32]};
            REG_DMA_CYCLES_LO: reg_rdata = dma_cycles_cnt[31:0];
            REG_DMA_CYCLES_HI: reg_rdata = {{(DATA_WIDTH-(COUNTER_WIDTH-32)){1'b0}}, dma_cycles_cnt[COUNTER_WIDTH-1:32]};
            REG_CACHE_HIT_LO:  reg_rdata = cache_hit_cnt[31:0];
            REG_CACHE_HIT_HI:  reg_rdata = {{(DATA_WIDTH-(COUNTER_WIDTH-32)){1'b0}}, cache_hit_cnt[COUNTER_WIDTH-1:32]};
            REG_CACHE_MISS_LO: reg_rdata = cache_miss_cnt[31:0];
            REG_CACHE_MISS_HI: reg_rdata = {{(DATA_WIDTH-(COUNTER_WIDTH-32)){1'b0}}, cache_miss_cnt[COUNTER_WIDTH-1:32]};
            REG_INSTR_CNT_LO:  reg_rdata = instr_cnt[31:0];
            REG_INSTR_CNT_HI:  reg_rdata = {{(DATA_WIDTH-(COUNTER_WIDTH-32)){1'b0}}, instr_cnt[COUNTER_WIDTH-1:32]};
            default:           reg_rdata = '0;
        endcase
    end

endmodule
