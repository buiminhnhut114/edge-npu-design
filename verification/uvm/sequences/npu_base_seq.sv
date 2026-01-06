//=============================================================================
// NPU Base Sequence
// Base class for all NPU sequences
//=============================================================================

class npu_base_seq extends uvm_sequence #(axil_seq_item);
    
    `uvm_object_utils(npu_base_seq)
    
    //=========================================================================
    // Constructor
    //=========================================================================
    
    function new(string name = "npu_base_seq");
        super.new(name);
    endfunction
    
    //=========================================================================
    // Helper Tasks
    //=========================================================================
    
    // Write register
    task write_reg(bit [31:0] addr, bit [31:0] data);
        axil_seq_item item = axil_seq_item::type_id::create("item");
        
        start_item(item);
        item.op_type = AXI_WRITE;
        item.addr = addr;
        item.data = data;
        item.strb = 4'hF;
        finish_item(item);
        
        `uvm_info("NPU_SEQ", $sformatf("Write: addr=0x%08h, data=0x%08h", addr, data), UVM_MEDIUM)
    endtask
    
    // Read register
    task read_reg(bit [31:0] addr, output bit [31:0] data);
        axil_seq_item item = axil_seq_item::type_id::create("item");
        
        start_item(item);
        item.op_type = AXI_READ;
        item.addr = addr;
        finish_item(item);
        
        data = item.rdata;
        `uvm_info("NPU_SEQ", $sformatf("Read: addr=0x%08h, data=0x%08h", addr, data), UVM_MEDIUM)
    endtask
    
    // Poll register until condition met
    task poll_reg(bit [31:0] addr, bit [31:0] mask, bit [31:0] expected, 
                  int timeout = 1000);
        bit [31:0] data;
        int count = 0;
        
        do begin
            read_reg(addr, data);
            if ((data & mask) == expected) return;
            count++;
            #100;
        end while (count < timeout);
        
        `uvm_error("NPU_SEQ", $sformatf("Poll timeout: addr=0x%08h, got=0x%08h, expected=0x%08h",
                   addr, data & mask, expected))
    endtask
    
    // Enable NPU
    task enable_npu();
        write_reg(ADDR_CTRL, 32'h0000_0001);
    endtask
    
    // Start NPU
    task start_npu();
        write_reg(ADDR_CTRL, 32'h0000_0003);
    endtask
    
    // Wait for NPU done
    task wait_npu_done(int timeout = 10000);
        poll_reg(ADDR_STATUS, 32'h0000_0002, 32'h0000_0002, timeout);
    endtask
    
    // Reset NPU
    task reset_npu();
        write_reg(ADDR_CTRL, 32'h0000_0004);
        #100;
        write_reg(ADDR_CTRL, 32'h0000_0000);
    endtask

endclass
