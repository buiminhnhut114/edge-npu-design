//=============================================================================
// NPU Base Test
// Base class for all NPU tests
//=============================================================================

class npu_base_test extends uvm_test;
    
    `uvm_component_utils(npu_base_test)
    
    //=========================================================================
    // Components
    //=========================================================================
    
    npu_env env;
    
    //=========================================================================
    // Configuration
    //=========================================================================
    
    int timeout_ns = 100000;
    
    //=========================================================================
    // Constructor
    //=========================================================================
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    
    //=========================================================================
    // Build Phase
    //=========================================================================
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        // Create environment
        env = npu_env::type_id::create("env", this);
        
        // Set timeout
        uvm_top.set_timeout(timeout_ns * 1ns, 0);
    endfunction
    
    //=========================================================================
    // End of Elaboration Phase
    //=========================================================================
    
    function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        
        // Print topology
        `uvm_info("BASE_TEST", "UVM Topology:", UVM_LOW)
        uvm_top.print_topology();
    endfunction
    
    //=========================================================================
    // Run Phase
    //=========================================================================
    
    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        
        `uvm_info("BASE_TEST", "Starting test...", UVM_LOW)
        
        // Wait for reset to complete (reset deasserts at 100ns)
        #200ns;
        
        // Run test sequence (override in derived tests)
        run_test_sequence();
        
        // Drain time
        #1000;
        
        `uvm_info("BASE_TEST", "Test complete", UVM_LOW)
        
        phase.drop_objection(this);
    endtask
    
    //=========================================================================
    // Test Sequence (Override in derived tests)
    //=========================================================================
    
    virtual task run_test_sequence();
        `uvm_info("BASE_TEST", "No test sequence defined", UVM_LOW)
    endtask
    
    //=========================================================================
    // Report Phase
    //=========================================================================
    
    function void report_phase(uvm_phase phase);
        uvm_report_server svr;
        int err_count;
        
        super.report_phase(phase);
        
        svr = uvm_report_server::get_server();
        err_count = svr.get_severity_count(UVM_ERROR) + 
                    svr.get_severity_count(UVM_FATAL);
        
        `uvm_info("BASE_TEST", "========================================", UVM_LOW)
        if (err_count == 0)
            `uvm_info("BASE_TEST", "*** TEST PASSED ***", UVM_LOW)
        else
            `uvm_info("BASE_TEST", $sformatf("*** TEST FAILED *** (%0d errors)", err_count), UVM_LOW)
        `uvm_info("BASE_TEST", "========================================", UVM_LOW)
    endfunction

endclass
