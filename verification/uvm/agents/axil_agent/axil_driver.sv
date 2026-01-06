//=============================================================================
// AXI-Lite Driver
// Drives AXI-Lite transactions to DUT
//=============================================================================

class axil_driver extends uvm_driver #(axil_seq_item);
    
    `uvm_component_utils(axil_driver)
    
    //=========================================================================
    // Virtual Interface
    //=========================================================================
    
    virtual axil_if vif;
    
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
        if (!uvm_config_db#(virtual axil_if)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "Virtual interface not found")
    endfunction
    
    //=========================================================================
    // Run Phase
    //=========================================================================
    
    task run_phase(uvm_phase phase);
        axil_seq_item item;
        
        // Initialize signals
        @(posedge vif.clk);
        #1;
        vif.awaddr  = '0;
        vif.awvalid = 1'b0;
        vif.wdata   = '0;
        vif.wstrb   = '0;
        vif.wvalid  = 1'b0;
        vif.bready  = 1'b0;
        vif.araddr  = '0;
        vif.arvalid = 1'b0;
        vif.rready  = 1'b0;
        
        forever begin
            seq_item_port.get_next_item(item);
            
            if (item.op_type == AXI_WRITE)
                drive_write(item);
            else
                drive_read(item);
            
            seq_item_port.item_done();
        end
    endtask
    
    //=========================================================================
    // Drive Write Transaction
    //=========================================================================
    
    task drive_write(axil_seq_item item);
        // Drive signals at negedge so they're stable for posedge sampling
        @(negedge vif.clk);
        vif.awaddr  = item.addr;
        vif.awvalid = 1'b1;
        vif.wdata   = item.data;
        vif.wstrb   = item.strb;
        vif.wvalid  = 1'b1;
        vif.bready  = 1'b1;
        
        // RTL samples on posedge when awvalid && wvalid && awready && wready
        // Since ready signals are always 1, the write happens at this posedge
        @(posedge vif.clk);
        // Write has now been registered by the RTL
        
        // Hold valid signals for one more cycle to ensure write is complete
        @(posedge vif.clk);
        
        // Deassert signals at negedge
        @(negedge vif.clk);
        vif.awvalid = 1'b0;
        vif.wvalid  = 1'b0;
        
        // Wait for response (bvalid is always 1)
        @(posedge vif.clk);
        item.resp = vif.bresp;
        
        @(negedge vif.clk);
        vif.bready = 1'b0;
        
        // Allow register to settle
        @(posedge vif.clk);
        
        `uvm_info("AXIL_DRV", $sformatf("Write: addr=0x%08h, data=0x%08h", 
                  item.addr, item.data), UVM_MEDIUM)
    endtask
    
    //=========================================================================
    // Drive Read Transaction
    //=========================================================================
    
    task drive_read(axil_seq_item item);
        // Address phase
        @(posedge vif.clk);
        #1;
        vif.araddr  = item.addr;
        vif.arvalid = 1'b1;
        vif.rready  = 1'b1;
        
        // Wait for address handshake
        @(posedge vif.clk);
        while (!vif.arready) @(posedge vif.clk);
        
        // Wait one more cycle for rdata to be valid
        @(posedge vif.clk);
        
        // Wait for rvalid if needed
        while (!vif.rvalid) @(posedge vif.clk);
        
        // Sample data at clock edge
        @(posedge vif.clk);
        item.rdata = vif.rdata;
        item.resp = vif.rresp;
        
        #1;
        vif.arvalid = 1'b0;
        vif.rready = 1'b0;
        
        @(posedge vif.clk);
        
        `uvm_info("AXIL_DRV", $sformatf("Read: addr=0x%08h, data=0x%08h", 
                  item.addr, item.rdata), UVM_MEDIUM)
    endtask

endclass
