//=============================================================================
// NPU Register Sequence
// Test register read/write operations
//=============================================================================

class npu_reg_seq extends npu_base_seq;
    
    `uvm_object_utils(npu_reg_seq)
    
    //=========================================================================
    // Constructor
    //=========================================================================
    
    function new(string name = "npu_reg_seq");
        super.new(name);
    endfunction
    
    //=========================================================================
    // Body
    //=========================================================================
    
    task body();
        bit [31:0] data;
        
        `uvm_info("NPU_REG_SEQ", "Starting register test sequence", UVM_LOW)
        
        //---------------------------------------------------------------------
        // Test 1: Read Version Register
        //---------------------------------------------------------------------
        `uvm_info("NPU_REG_SEQ", "Test 1: Read Version Register", UVM_LOW)
        read_reg(ADDR_VERSION, data);
        if (data == 32'h0001_0000)
            `uvm_info("NPU_REG_SEQ", "Version check PASSED", UVM_LOW)
        else
            `uvm_error("NPU_REG_SEQ", $sformatf("Version mismatch: got 0x%08h", data))
        
        //---------------------------------------------------------------------
        // Test 2: Read Config Register
        //---------------------------------------------------------------------
        `uvm_info("NPU_REG_SEQ", "Test 2: Read Config Register", UVM_LOW)
        read_reg(ADDR_CONFIG, data);
        `uvm_info("NPU_REG_SEQ", $sformatf("Config: PE_ROWS=%0d, PE_COLS=%0d", 
                  data[31:16], data[15:0]), UVM_LOW)
        
        //---------------------------------------------------------------------
        // Test 3: Write/Read Control Register
        //---------------------------------------------------------------------
        `uvm_info("NPU_REG_SEQ", "Test 3: Write/Read Control Register", UVM_LOW)
        write_reg(ADDR_CTRL, 32'h0000_0001);
        read_reg(ADDR_CTRL, data);
        if (data[0] == 1'b1)
            `uvm_info("NPU_REG_SEQ", "Control write/read PASSED", UVM_LOW)
        else
            `uvm_error("NPU_REG_SEQ", "Control write/read FAILED")
        
        //---------------------------------------------------------------------
        // Test 4: Write/Read IRQ Enable Register
        //---------------------------------------------------------------------
        `uvm_info("NPU_REG_SEQ", "Test 4: Write/Read IRQ Enable Register", UVM_LOW)
        write_reg(ADDR_IRQ_EN, 32'h0000_000F);
        read_reg(ADDR_IRQ_EN, data);
        if (data == 32'h0000_000F)
            `uvm_info("NPU_REG_SEQ", "IRQ Enable write/read PASSED", UVM_LOW)
        else
            `uvm_error("NPU_REG_SEQ", "IRQ Enable write/read FAILED")
        
        //---------------------------------------------------------------------
        // Test 5: Read Status Register
        //---------------------------------------------------------------------
        `uvm_info("NPU_REG_SEQ", "Test 5: Read Status Register", UVM_LOW)
        read_reg(ADDR_STATUS, data);
        `uvm_info("NPU_REG_SEQ", $sformatf("Status: 0x%08h", data), UVM_LOW)
        
        `uvm_info("NPU_REG_SEQ", "Register test sequence complete", UVM_LOW)
    endtask

endclass
