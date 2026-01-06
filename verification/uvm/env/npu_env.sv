//=============================================================================
// NPU Environment
// Top-level UVM environment
//=============================================================================

class npu_env extends uvm_env;
    
    `uvm_component_utils(npu_env)
    
    //=========================================================================
    // Components
    //=========================================================================
    
    axil_agent      axil_agt;
    npu_scoreboard  scoreboard;
    npu_coverage    coverage;
    
    //=========================================================================
    // Configuration
    //=========================================================================
    
    bit has_scoreboard = 1;
    bit has_coverage = 1;
    
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
        
        // Create AXI-Lite agent
        axil_agt = axil_agent::type_id::create("axil_agt", this);
        
        // Create scoreboard
        if (has_scoreboard)
            scoreboard = npu_scoreboard::type_id::create("scoreboard", this);
        
        // Create coverage
        if (has_coverage)
            coverage = npu_coverage::type_id::create("coverage", this);
    endfunction
    
    //=========================================================================
    // Connect Phase
    //=========================================================================
    
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        
        // Connect monitor to scoreboard
        if (has_scoreboard)
            axil_agt.monitor.ap.connect(scoreboard.axil_export);
        
        // Connect monitor to coverage
        if (has_coverage)
            axil_agt.monitor.ap.connect(coverage.analysis_export);
    endfunction

endclass
