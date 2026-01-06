//=============================================================================
// AXI-Lite Agent
// Complete agent with driver, monitor, and sequencer
//=============================================================================

class axil_agent extends uvm_agent;
    
    `uvm_component_utils(axil_agent)
    
    //=========================================================================
    // Components
    //=========================================================================
    
    axil_driver    driver;
    axil_monitor   monitor;
    uvm_sequencer #(axil_seq_item) sequencer;
    
    //=========================================================================
    // Configuration
    //=========================================================================
    
    bit is_active = 1;
    
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
        
        monitor = axil_monitor::type_id::create("monitor", this);
        
        if (is_active) begin
            driver = axil_driver::type_id::create("driver", this);
            sequencer = uvm_sequencer#(axil_seq_item)::type_id::create("sequencer", this);
        end
    endfunction
    
    //=========================================================================
    // Connect Phase
    //=========================================================================
    
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        
        if (is_active) begin
            driver.seq_item_port.connect(sequencer.seq_item_export);
        end
    endfunction

endclass
