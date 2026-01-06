//=============================================================================
// AXI-Lite Monitor
// Monitors AXI-Lite transactions
//=============================================================================

class axil_monitor extends uvm_monitor;
    
    `uvm_component_utils(axil_monitor)
    
    //=========================================================================
    // Virtual Interface
    //=========================================================================
    
    virtual axil_if vif;
    
    //=========================================================================
    // Analysis Port
    //=========================================================================
    
    uvm_analysis_port #(axil_seq_item) ap;
    
    //=========================================================================
    // Constructor
    //=========================================================================
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
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
        fork
            monitor_writes();
            monitor_reads();
        join
    endtask
    
    //=========================================================================
    // Monitor Write Transactions
    //=========================================================================
    
    task monitor_writes();
        axil_seq_item item;
        
        forever begin
            @(posedge vif.clk);
            
            if (vif.awvalid && vif.awready && vif.wvalid && vif.wready) begin
                item = axil_seq_item::type_id::create("item");
                item.op_type = AXI_WRITE;
                item.addr = vif.awaddr;
                item.data = vif.wdata;
                item.strb = vif.wstrb;
                
                // Wait for response
                @(posedge vif.clk);
                while (!vif.bvalid) @(posedge vif.clk);
                item.resp = vif.bresp;
                
                ap.write(item);
                `uvm_info("AXIL_MON", $sformatf("Write: %s", item.convert2string()), UVM_HIGH)
            end
        end
    endtask
    
    //=========================================================================
    // Monitor Read Transactions
    //=========================================================================
    
    task monitor_reads();
        axil_seq_item item;
        
        forever begin
            @(posedge vif.clk);
            
            if (vif.arvalid && vif.arready) begin
                item = axil_seq_item::type_id::create("item");
                item.op_type = AXI_READ;
                item.addr = vif.araddr;
                
                // For combinational read, rdata is valid immediately
                // Wait for rvalid (should be immediate with always-ready slave)
                while (!vif.rvalid) @(posedge vif.clk);
                item.rdata = vif.rdata;
                item.resp = vif.rresp;
                
                ap.write(item);
                `uvm_info("AXIL_MON", $sformatf("Read: %s", item.convert2string()), UVM_HIGH)
            end
        end
    endtask

endclass
