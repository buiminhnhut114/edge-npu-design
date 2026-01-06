//=============================================================================
// NPU Convolution Sequence
// Test convolution operations
//=============================================================================

class npu_conv_seq extends npu_base_seq;
    
    `uvm_object_utils(npu_conv_seq)
    
    //=========================================================================
    // Configuration
    //=========================================================================
    
    rand int input_h;
    rand int input_w;
    rand int input_c;
    rand int output_c;
    rand int kernel_size;
    rand int stride;
    
    constraint c_small_conv {
        input_h inside {[4:16]};
        input_w inside {[4:16]};
        input_c inside {[1:16]};
        output_c inside {[1:16]};
        kernel_size inside {1, 3};
        stride inside {1, 2};
    }
    
    //=========================================================================
    // Constructor
    //=========================================================================
    
    function new(string name = "npu_conv_seq");
        super.new(name);
    endfunction
    
    //=========================================================================
    // Body
    //=========================================================================
    
    task body();
        bit [31:0] data;
        
        `uvm_info("NPU_CONV_SEQ", $sformatf("Starting conv test: %0dx%0dx%0d -> %0d, k=%0d, s=%0d",
                  input_h, input_w, input_c, output_c, kernel_size, stride), UVM_LOW)
        
        //---------------------------------------------------------------------
        // Step 1: Reset and Enable NPU
        //---------------------------------------------------------------------
        reset_npu();
        enable_npu();
        
        //---------------------------------------------------------------------
        // Step 2: Configure DMA for weight loading
        //---------------------------------------------------------------------
        `uvm_info("NPU_CONV_SEQ", "Loading weights via DMA", UVM_MEDIUM)
        
        // Set DMA source (external memory)
        write_reg(ADDR_DMA_SRC, 32'h8000_0000);
        
        // Set DMA destination (weight buffer)
        write_reg(ADDR_DMA_DST, 32'h0000_0000);
        
        // Set DMA length (weight size)
        write_reg(ADDR_DMA_LEN, output_c * input_c * kernel_size * kernel_size);
        
        // Start DMA
        write_reg(ADDR_DMA_CTRL, 32'h0000_0001);
        
        // Wait for DMA done (simplified - just wait)
        #1000;
        
        //---------------------------------------------------------------------
        // Step 3: Configure DMA for input loading
        //---------------------------------------------------------------------
        `uvm_info("NPU_CONV_SEQ", "Loading input via DMA", UVM_MEDIUM)
        
        write_reg(ADDR_DMA_SRC, 32'h8010_0000);
        write_reg(ADDR_DMA_DST, 32'h0004_0000);
        write_reg(ADDR_DMA_LEN, input_h * input_w * input_c);
        write_reg(ADDR_DMA_CTRL, 32'h0000_0001);
        
        #1000;
        
        //---------------------------------------------------------------------
        // Step 4: Start NPU Execution
        //---------------------------------------------------------------------
        `uvm_info("NPU_CONV_SEQ", "Starting NPU execution", UVM_MEDIUM)
        start_npu();
        
        //---------------------------------------------------------------------
        // Step 5: Wait for completion
        //---------------------------------------------------------------------
        `uvm_info("NPU_CONV_SEQ", "Waiting for completion", UVM_MEDIUM)
        wait_npu_done(50000);
        
        //---------------------------------------------------------------------
        // Step 6: Check status
        //---------------------------------------------------------------------
        read_reg(ADDR_STATUS, data);
        if (data[1])
            `uvm_info("NPU_CONV_SEQ", "Convolution completed successfully", UVM_LOW)
        else
            `uvm_warning("NPU_CONV_SEQ", "Convolution may not have completed")
        
        `uvm_info("NPU_CONV_SEQ", "Convolution sequence complete", UVM_LOW)
    endtask

endclass
