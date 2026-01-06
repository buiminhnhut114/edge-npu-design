//=============================================================================
// NPU Coverage
// Functional coverage collection
//=============================================================================

class npu_coverage extends uvm_subscriber #(axil_seq_item);
    
    `uvm_component_utils(npu_coverage)
    
    //=========================================================================
    // Coverage Groups
    //=========================================================================
    
    // Register access coverage
    covergroup cg_reg_access;
        option.per_instance = 1;
        
        cp_addr: coverpoint item.addr {
            bins ctrl       = {ADDR_CTRL};
            bins status     = {ADDR_STATUS};
            bins irq_en     = {ADDR_IRQ_EN};
            bins irq_status = {ADDR_IRQ_STATUS};
            bins version    = {ADDR_VERSION};
            bins config_reg = {ADDR_CONFIG};
            bins dma_ctrl   = {ADDR_DMA_CTRL};
            bins dma_src    = {ADDR_DMA_SRC};
            bins dma_dst    = {ADDR_DMA_DST};
            bins dma_len    = {ADDR_DMA_LEN};
            bins others     = default;
        }
        
        cp_op: coverpoint item.op_type {
            bins read  = {AXI_READ};
            bins write = {AXI_WRITE};
        }
        
        cp_resp: coverpoint item.resp {
            bins okay   = {2'b00};
            bins slverr = {2'b10};
            bins decerr = {2'b11};
        }
        
        // Cross coverage
        cx_addr_op: cross cp_addr, cp_op;
    endgroup
    
    // Control register coverage
    covergroup cg_ctrl_reg;
        option.per_instance = 1;
        
        cp_enable: coverpoint item.data[0] {
            bins disabled = {0};
            bins enabled  = {1};
        }
        
        cp_start: coverpoint item.data[1] {
            bins idle    = {0};
            bins started = {1};
        }
        
        cp_reset: coverpoint item.data[2] {
            bins normal = {0};
            bins reset  = {1};
        }
    endgroup
    
    //=========================================================================
    // Variables
    //=========================================================================
    
    axil_seq_item item;
    
    //=========================================================================
    // Constructor
    //=========================================================================
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
        cg_reg_access = new();
        cg_ctrl_reg = new();
    endfunction
    
    //=========================================================================
    // Write Implementation
    //=========================================================================
    
    function void write(axil_seq_item t);
        item = t;
        
        // Sample register access coverage
        cg_reg_access.sample();
        
        // Sample control register coverage on writes
        if (t.op_type == AXI_WRITE && t.addr == ADDR_CTRL) begin
            cg_ctrl_reg.sample();
        end
    endfunction
    
    //=========================================================================
    // Report Phase
    //=========================================================================
    
    function void report_phase(uvm_phase phase);
        `uvm_info("COVERAGE", "========================================", UVM_LOW)
        `uvm_info("COVERAGE", "         Coverage Summary", UVM_LOW)
        `uvm_info("COVERAGE", "========================================", UVM_LOW)
        `uvm_info("COVERAGE", $sformatf("  Register Access: %.2f%%", 
                  cg_reg_access.get_coverage()), UVM_LOW)
        `uvm_info("COVERAGE", $sformatf("  Control Register: %.2f%%", 
                  cg_ctrl_reg.get_coverage()), UVM_LOW)
        `uvm_info("COVERAGE", "========================================", UVM_LOW)
    endfunction

endclass
