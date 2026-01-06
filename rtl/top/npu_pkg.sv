//=============================================================================
// NPU Global Package
// Contains all parameters, types, and constants for EdgeNPU
//=============================================================================

`ifndef NPU_PKG_SV
`define NPU_PKG_SV

package npu_pkg;

    //=========================================================================
    // NPU Configuration Parameters
    //=========================================================================
    
    // PE Array Dimensions
    parameter int PE_ROWS       = 16;       // Number of PE rows
    parameter int PE_COLS       = 16;       // Number of PE columns
    parameter int NUM_PES       = PE_ROWS * PE_COLS;
    
    // Data Widths
    parameter int DATA_WIDTH    = 8;        // Input data width (INT8)
    parameter int WEIGHT_WIDTH  = 8;        // Weight width (INT8)
    parameter int ACC_WIDTH     = 32;       // Accumulator width
    parameter int OUTPUT_WIDTH  = 8;        // Output data width
    
    // Memory Configuration
    parameter int WEIGHT_BUF_SIZE   = 256 * 1024;   // 256 KB
    parameter int ACT_BUF_SIZE      = 256 * 1024;   // 256 KB
    parameter int INST_BUF_SIZE     = 16 * 1024;    // 16 KB
    
    // AXI Configuration
    parameter int AXI_DATA_WIDTH    = 128;
    parameter int AXI_ADDR_WIDTH    = 40;
    parameter int AXI_ID_WIDTH      = 8;
    parameter int AXI_STRB_WIDTH    = AXI_DATA_WIDTH / 8;
    
    // AXI-Lite Configuration
    parameter int AXIL_DATA_WIDTH   = 32;
    parameter int AXIL_ADDR_WIDTH   = 32;
    
    //=========================================================================
    // Type Definitions
    //=========================================================================
    
    // Data types
    typedef logic [DATA_WIDTH-1:0]      data_t;
    typedef logic [WEIGHT_WIDTH-1:0]    weight_t;
    typedef logic [ACC_WIDTH-1:0]       acc_t;
    typedef logic signed [DATA_WIDTH-1:0]   data_signed_t;
    typedef logic signed [WEIGHT_WIDTH-1:0] weight_signed_t;
    typedef logic signed [ACC_WIDTH-1:0]    acc_signed_t;
    
    // Instruction types
    typedef enum logic [3:0] {
        OP_NOP      = 4'h0,
        OP_CONV     = 4'h1,
        OP_FC       = 4'h2,
        OP_POOL     = 4'h3,
        OP_ACT      = 4'h4,
        OP_LOAD     = 4'h5,
        OP_STORE    = 4'h6,
        OP_SYNC     = 4'h7,
        OP_ADD      = 4'h8,
        OP_MUL      = 4'h9,
        OP_CONCAT   = 4'hA,
        OP_SPLIT    = 4'hB
    } opcode_t;
    
    // Activation function types
    typedef enum logic [2:0] {
        ACT_NONE    = 3'h0,
        ACT_RELU    = 3'h1,
        ACT_RELU6   = 3'h2,
        ACT_SIGMOID = 3'h3,
        ACT_TANH    = 3'h4,
        ACT_SWISH   = 3'h5,
        ACT_GELU    = 3'h6
    } activation_t;
    
    // Pooling types
    typedef enum logic [1:0] {
        POOL_MAX    = 2'h0,
        POOL_AVG    = 2'h1,
        POOL_GLOBAL = 2'h2
    } pooling_t;
    
    // Data format
    typedef enum logic [1:0] {
        FMT_INT8    = 2'h0,
        FMT_INT16   = 2'h1,
        FMT_FP16    = 2'h2,
        FMT_BF16    = 2'h3
    } data_format_t;
    
    //=========================================================================
    // Structure Definitions
    //=========================================================================
    
    // Instruction format (64-bit)
    typedef struct packed {
        opcode_t        opcode;         // [63:60] Opcode
        logic [3:0]     flags;          // [59:56] Flags
        logic [7:0]     dst_addr;       // [55:48] Destination address
        logic [7:0]     src0_addr;      // [47:40] Source 0 address
        logic [7:0]     src1_addr;      // [39:32] Source 1 address
        logic [31:0]    immediate;      // [31:0]  Immediate value
    } instruction_t;
    
    // Convolution parameters
    typedef struct packed {
        logic [15:0]    input_height;
        logic [15:0]    input_width;
        logic [15:0]    input_channels;
        logic [15:0]    output_channels;
        logic [3:0]     kernel_height;
        logic [3:0]     kernel_width;
        logic [3:0]     stride_h;
        logic [3:0]     stride_w;
        logic [3:0]     pad_top;
        logic [3:0]     pad_bottom;
        logic [3:0]     pad_left;
        logic [3:0]     pad_right;
        logic [3:0]     dilation_h;
        logic [3:0]     dilation_w;
        activation_t    activation;
    } conv_param_t;
    
    // DMA descriptor
    typedef struct packed {
        logic [39:0]    src_addr;       // Source address
        logic [39:0]    dst_addr;       // Destination address
        logic [23:0]    length;         // Transfer length
        logic [15:0]    src_stride;     // Source stride
        logic [15:0]    dst_stride;     // Destination stride
        logic [7:0]     flags;          // Control flags
    } dma_desc_t;
    
    //=========================================================================
    // Constants
    //=========================================================================
    
    // Register offsets (AXI-Lite)
    localparam logic [11:0] REG_CTRL        = 12'h000;
    localparam logic [11:0] REG_STATUS      = 12'h004;
    localparam logic [11:0] REG_IRQ_EN      = 12'h008;
    localparam logic [11:0] REG_IRQ_STATUS  = 12'h00C;
    localparam logic [11:0] REG_VERSION     = 12'h010;
    localparam logic [11:0] REG_CONFIG      = 12'h014;
    localparam logic [11:0] REG_PERF_CNT    = 12'h020;
    localparam logic [11:0] REG_DMA_CTRL    = 12'h100;
    localparam logic [11:0] REG_DMA_STATUS  = 12'h104;
    localparam logic [11:0] REG_DMA_SRC     = 12'h108;
    localparam logic [11:0] REG_DMA_DST     = 12'h10C;
    localparam logic [11:0] REG_DMA_LEN     = 12'h110;
    
    // Version
    localparam logic [31:0] NPU_VERSION = 32'h0001_0000; // v1.0.0
    
    //=========================================================================
    // Functions
    //=========================================================================
    
    // Calculate output size after convolution
    function automatic int calc_conv_output_size(
        input int input_size,
        input int kernel_size,
        input int stride,
        input int padding,
        input int dilation
    );
        int effective_kernel = (kernel_size - 1) * dilation + 1;
        return (input_size + 2 * padding - effective_kernel) / stride + 1;
    endfunction
    
    // Saturate value to specified bit width
    function automatic logic [31:0] saturate(
        input logic signed [47:0] value,
        input int width
    );
        logic signed [47:0] max_val = (1 << (width - 1)) - 1;
        logic signed [47:0] min_val = -(1 << (width - 1));
        
        if (value > max_val)
            return max_val[31:0];
        else if (value < min_val)
            return min_val[31:0];
        else
            return value[31:0];
    endfunction

endpackage

`endif // NPU_PKG_SV
