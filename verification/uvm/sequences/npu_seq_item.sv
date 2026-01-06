//=============================================================================
// NPU Sequence Item
// Base transaction for NPU operations
//=============================================================================

class npu_seq_item extends uvm_sequence_item;
    
    //=========================================================================
    // Fields
    //=========================================================================
    
    // Operation type
    rand npu_op_type_e op_type;
    
    // Convolution parameters
    rand bit [15:0] input_height;
    rand bit [15:0] input_width;
    rand bit [15:0] input_channels;
    rand bit [15:0] output_channels;
    rand bit [3:0]  kernel_size;
    rand bit [3:0]  stride;
    rand bit [3:0]  padding;
    rand bit [2:0]  activation;
    
    // Memory addresses
    rand bit [31:0] weight_addr;
    rand bit [31:0] input_addr;
    rand bit [31:0] output_addr;
    
    // Data
    rand bit [7:0] input_data[];
    rand bit [7:0] weight_data[];
    bit [7:0] output_data[];
    
    // Status
    bit done;
    bit error;
    
    //=========================================================================
    // Constraints
    //=========================================================================
    
    constraint c_kernel_size {
        kernel_size inside {1, 3, 5, 7};
    }
    
    constraint c_stride {
        stride inside {1, 2};
    }
    
    constraint c_padding {
        padding <= kernel_size / 2;
    }
    
    constraint c_dimensions {
        input_height inside {[1:224]};
        input_width inside {[1:224]};
        input_channels inside {[1:512]};
        output_channels inside {[1:512]};
    }
    
    constraint c_activation {
        activation inside {[0:6]};
    }
    
    constraint c_addresses {
        weight_addr[1:0] == 2'b00;  // 4-byte aligned
        input_addr[1:0] == 2'b00;
        output_addr[1:0] == 2'b00;
    }
    
    //=========================================================================
    // UVM Macros
    //=========================================================================
    
    `uvm_object_utils_begin(npu_seq_item)
        `uvm_field_enum(npu_op_type_e, op_type, UVM_ALL_ON)
        `uvm_field_int(input_height, UVM_ALL_ON)
        `uvm_field_int(input_width, UVM_ALL_ON)
        `uvm_field_int(input_channels, UVM_ALL_ON)
        `uvm_field_int(output_channels, UVM_ALL_ON)
        `uvm_field_int(kernel_size, UVM_ALL_ON)
        `uvm_field_int(stride, UVM_ALL_ON)
        `uvm_field_int(padding, UVM_ALL_ON)
        `uvm_field_int(activation, UVM_ALL_ON)
        `uvm_field_int(weight_addr, UVM_ALL_ON)
        `uvm_field_int(input_addr, UVM_ALL_ON)
        `uvm_field_int(output_addr, UVM_ALL_ON)
        `uvm_field_array_int(input_data, UVM_ALL_ON)
        `uvm_field_array_int(weight_data, UVM_ALL_ON)
        `uvm_field_array_int(output_data, UVM_ALL_ON)
        `uvm_field_int(done, UVM_ALL_ON)
        `uvm_field_int(error, UVM_ALL_ON)
    `uvm_object_utils_end
    
    //=========================================================================
    // Constructor
    //=========================================================================
    
    function new(string name = "npu_seq_item");
        super.new(name);
    endfunction
    
    //=========================================================================
    // Methods
    //=========================================================================
    
    function int calc_output_size();
        int out_h, out_w;
        out_h = (input_height + 2*padding - kernel_size) / stride + 1;
        out_w = (input_width + 2*padding - kernel_size) / stride + 1;
        return out_h * out_w * output_channels;
    endfunction
    
    function int calc_weight_size();
        return output_channels * input_channels * kernel_size * kernel_size;
    endfunction
    
    function void post_randomize();
        // Allocate data arrays based on dimensions
        input_data = new[input_height * input_width * input_channels];
        weight_data = new[calc_weight_size()];
        output_data = new[calc_output_size()];
        
        // Randomize data
        foreach (input_data[i])
            input_data[i] = $urandom_range(0, 255);
        foreach (weight_data[i])
            weight_data[i] = $urandom_range(0, 255);
    endfunction
    
    function string convert2string();
        return $sformatf("NPU_SEQ: op=%s, in=%0dx%0dx%0d, out_ch=%0d, k=%0d, s=%0d, p=%0d",
                         op_type.name(), input_height, input_width, input_channels,
                         output_channels, kernel_size, stride, padding);
    endfunction

endclass
