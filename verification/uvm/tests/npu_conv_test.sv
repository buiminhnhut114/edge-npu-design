//=============================================================================
// NPU Convolution Test
// Test convolution operations
//=============================================================================

class npu_conv_test extends npu_base_test;
    
    `uvm_component_utils(npu_conv_test)
    
    //=========================================================================
    // Configuration
    //=========================================================================
    
    int num_iterations = 5;
    
    //=========================================================================
    // Constructor
    //=========================================================================
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
        timeout_ns = 500000;  // Longer timeout for conv tests
    endfunction
    
    //=========================================================================
    // Test Sequence
    //=========================================================================
    
    task run_test_sequence();
        npu_conv_seq seq;
        
        `uvm_info("CONV_TEST", $sformatf("Running %0d convolution iterations", num_iterations), UVM_LOW)
        
        for (int i = 0; i < num_iterations; i++) begin
            `uvm_info("CONV_TEST", $sformatf("Iteration %0d/%0d", i+1, num_iterations), UVM_LOW)
            
            seq = npu_conv_seq::type_id::create($sformatf("seq_%0d", i));
            
            // Randomize with constraints
            if (!seq.randomize() with {
                input_h inside {[4:8]};
                input_w inside {[4:8]};
                input_c inside {[1:4]};
                output_c inside {[1:4]};
            }) begin
                `uvm_error("CONV_TEST", "Randomization failed")
                continue;
            end
            
            seq.start(env.axil_agt.sequencer);
        end
        
        `uvm_info("CONV_TEST", "Convolution test complete", UVM_LOW)
    endtask

endclass
