//=============================================================================
// NPU Scoreboard
// Check DUT outputs against expected results
//=============================================================================

class npu_scoreboard extends uvm_scoreboard;
    
    `uvm_component_utils(npu_scoreboard)
    
    //=========================================================================
    // Analysis Exports
    //=========================================================================
    
    uvm_analysis_imp #(axil_seq_item, npu_scoreboard) axil_export;
    
    //=========================================================================
    // Statistics
    //=========================================================================
    
    int num_writes;
    int num_reads;
    int num_errors;
    
    // Register shadow
    bit [31:0] reg_ctrl;
    bit [31:0] reg_irq_en;
    bit [31:0] reg_dma_src;
    bit [31:0] reg_dma_dst;
    bit [31:0] reg_dma_len;
    
    //=========================================================================
    // Constructor
    //=========================================================================
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
        axil_export = new("axil_export", this);
    endfunction
    
    //=========================================================================
    // Build Phase
    //=========================================================================
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        num_writes = 0;
        num_reads = 0;
        num_errors = 0;
    endfunction
    
    //=========================================================================
    // Write Implementation
    //=========================================================================
    
    function void write(axil_seq_item item);
        if (item.op_type == AXI_WRITE) begin
            process_write(item);
            num_writes++;
        end else begin
            process_read(item);
            num_reads++;
        end
    endfunction
    
    //=========================================================================
    // Process Write
    //=========================================================================
    
    function void process_write(axil_seq_item item);
        // Update shadow registers
        case (item.addr)
            ADDR_CTRL:     reg_ctrl = item.data;
            ADDR_IRQ_EN:   reg_irq_en = item.data;
            ADDR_DMA_SRC:  reg_dma_src = item.data;
            ADDR_DMA_DST:  reg_dma_dst = item.data;
            ADDR_DMA_LEN:  reg_dma_len = item.data;
        endcase
        
        // Check response
        if (item.resp != 2'b00) begin
            `uvm_error("SCOREBOARD", $sformatf("Write error response: addr=0x%08h, resp=%0d",
                       item.addr, item.resp))
            num_errors++;
        end
    endfunction
    
    //=========================================================================
    // Process Read
    //=========================================================================
    
    function void process_read(axil_seq_item item);
        bit [31:0] expected;
        bit check = 1;
        
        // Determine expected value
        case (item.addr)
            ADDR_VERSION: expected = 32'h0001_0000;
            ADDR_CONFIG:  expected = 32'h0010_0010;  // 16x16 PE array
            ADDR_CTRL:    expected = reg_ctrl;
            ADDR_IRQ_EN:  expected = reg_irq_en;
            default:      check = 0;  // Don't check dynamic registers
        endcase
        
        // Check response
        if (item.resp != 2'b00) begin
            `uvm_error("SCOREBOARD", $sformatf("Read error response: addr=0x%08h, resp=%0d",
                       item.addr, item.resp))
            num_errors++;
        end
        
        // Check data (for static registers)
        if (check && item.rdata != expected) begin
            `uvm_error("SCOREBOARD", $sformatf("Read data mismatch: addr=0x%08h, got=0x%08h, exp=0x%08h",
                       item.addr, item.rdata, expected))
            num_errors++;
        end
    endfunction
    
    //=========================================================================
    // Report Phase
    //=========================================================================
    
    function void report_phase(uvm_phase phase);
        `uvm_info("SCOREBOARD", "========================================", UVM_LOW)
        `uvm_info("SCOREBOARD", "         Scoreboard Summary", UVM_LOW)
        `uvm_info("SCOREBOARD", "========================================", UVM_LOW)
        `uvm_info("SCOREBOARD", $sformatf("  Writes:  %0d", num_writes), UVM_LOW)
        `uvm_info("SCOREBOARD", $sformatf("  Reads:   %0d", num_reads), UVM_LOW)
        `uvm_info("SCOREBOARD", $sformatf("  Errors:  %0d", num_errors), UVM_LOW)
        `uvm_info("SCOREBOARD", "========================================", UVM_LOW)
        
        if (num_errors == 0)
            `uvm_info("SCOREBOARD", "*** TEST PASSED ***", UVM_LOW)
        else
            `uvm_error("SCOREBOARD", "*** TEST FAILED ***")
    endfunction

endclass
