//=============================================================================
// NPU Sanity Test
// Basic sanity check for NPU
//=============================================================================

class npu_sanity_test extends npu_base_test;
    
    `uvm_component_utils(npu_sanity_test)
    
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
        npu_base_seq seq;
        bit [31:0] data;
        
        `uvm_info("SANITY_TEST", "Running sanity test", UVM_LOW)
        
        seq = npu_base_seq::type_id::create("seq");
        seq.start(env.axil_agt.sequencer);
        
        // Test 1: Read version
        `uvm_info("SANITY_TEST", "Test 1: Read version register", UVM_LOW)
        seq.read_reg(ADDR_VERSION, data);
        if (data != 32'h0001_0000)
            `uvm_error("SANITY_TEST", $sformatf("Version mismatch: 0x%08h", data))
        
        // Test 2: Enable NPU
        `uvm_info("SANITY_TEST", "Test 2: Enable NPU", UVM_LOW)
        seq.enable_npu();
        seq.read_reg(ADDR_CTRL, data);
        if (data[0] != 1'b1)
            `uvm_error("SANITY_TEST", "NPU not enabled")
        
        // Test 3: Check status
        `uvm_info("SANITY_TEST", "Test 3: Check status", UVM_LOW)
        seq.read_reg(ADDR_STATUS, data);
        `uvm_info("SANITY_TEST", $sformatf("Status: 0x%08h", data), UVM_LOW)
        
        // Test 4: Reset NPU
        `uvm_info("SANITY_TEST", "Test 4: Reset NPU", UVM_LOW)
        seq.reset_npu();
        
        `uvm_info("SANITY_TEST", "Sanity test complete", UVM_LOW)
    endtask

endclass
