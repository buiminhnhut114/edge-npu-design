//=============================================================================
// AXI-Lite Sequence Item
// Transaction for AXI-Lite register access
//=============================================================================

class axil_seq_item extends uvm_sequence_item;
    
    //=========================================================================
    // Fields
    //=========================================================================
    
    rand axi_op_type_e op_type;
    rand bit [31:0] addr;
    rand bit [31:0] data;
    rand bit [3:0]  strb;
    
    // Response
    bit [31:0] rdata;
    bit [1:0]  resp;
    
    //=========================================================================
    // Constraints
    //=========================================================================
    
    constraint c_addr_aligned {
        addr[1:0] == 2'b00;  // 4-byte aligned
    }
    
    constraint c_strb_default {
        strb == 4'hF;
    }
    
    //=========================================================================
    // UVM Macros
    //=========================================================================
    
    `uvm_object_utils_begin(axil_seq_item)
        `uvm_field_enum(axi_op_type_e, op_type, UVM_ALL_ON)
        `uvm_field_int(addr, UVM_ALL_ON)
        `uvm_field_int(data, UVM_ALL_ON)
        `uvm_field_int(strb, UVM_ALL_ON)
        `uvm_field_int(rdata, UVM_ALL_ON)
        `uvm_field_int(resp, UVM_ALL_ON)
    `uvm_object_utils_end
    
    //=========================================================================
    // Constructor
    //=========================================================================
    
    function new(string name = "axil_seq_item");
        super.new(name);
    endfunction
    
    //=========================================================================
    // Methods
    //=========================================================================
    
    function string convert2string();
        if (op_type == AXI_WRITE)
            return $sformatf("AXIL_WR: addr=0x%08h, data=0x%08h", addr, data);
        else
            return $sformatf("AXIL_RD: addr=0x%08h, rdata=0x%08h", addr, rdata);
    endfunction

endclass
