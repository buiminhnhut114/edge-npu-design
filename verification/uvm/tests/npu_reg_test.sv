//=============================================================================
// NPU Register Test
// Test all register read/write operations
//=============================================================================

class npu_reg_test extends npu_base_test;
    
    `uvm_component_utils(npu_reg_test)
    
    //=========================================================================
    // Constructor
    //=========================================================================
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    
    //=========================================================================
    // Test Sequence
    //=========================================================================
    
    task run_test_sequence();
        npu_reg_seq seq;
        
        `uvm_info("REG_TEST", "Running register test sequence", UVM_LOW)
        
        seq = npu_reg_seq::type_id::create("seq");
        seq.start(env.axil_agt.sequencer);
        
        `uvm_info("REG_TEST", "Register test sequence complete", UVM_LOW)
    endtask

endclass
