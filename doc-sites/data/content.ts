// EdgeNPU Technical Documentation Content
// Professional documentation following industry standards (NVIDIA, ARM, Google Coral style)
import type { PageContent } from '../types';

const contentData: Record<string, PageContent> = {
    introduction: {
        id: 'introduction',
        title: 'EdgeNPU: High-Performance Neural Processing Unit',
        description: 'Academic Overview of EdgeNPU Architecture for Edge AI Applications',
        lastUpdated: '2026-01-07',
        blocks: [
            {
                type: 'heading',
                content: 'Abstract',
                level: 2,
            },
            {
                type: 'paragraph',
                content: `<strong>EdgeNPU</strong> is a domain-specific processor architecture designed for efficient 
                neural network inference at the edge. The architecture employs a <strong>16×16 weight-stationary 
                systolic array</strong> with 256 processing elements (PEs), achieving peak performance of 
                <strong>512 GOPS</strong> for INT8 operations while maintaining power consumption below 500mW. 
                This results in an energy efficiency exceeding <strong>1 TOPS/W</strong>, making it suitable 
                for battery-powered edge devices and IoT applications.`,
            },
            {
                type: 'diagram',
                content: 'system-overview',
            },
            {
                type: 'heading',
                content: 'Research Motivation',
                level: 2,
            },
            {
                type: 'paragraph',
                content: `The proliferation of deep neural networks (DNNs) in edge computing applications has created 
                a demand for specialized hardware accelerators that can deliver high computational throughput while 
                operating under strict power and area constraints. Traditional general-purpose processors (CPUs) 
                and graphics processing units (GPUs) are inadequate for edge deployment due to their high power 
                consumption and large form factors.`,
            },
            {
                type: 'paragraph',
                content: `EdgeNPU addresses these challenges through several key architectural innovations:
                <br>• <strong>Systolic Array Architecture</strong>: Maximizes data reuse and minimizes memory bandwidth requirements
                <br>• <strong>Weight-Stationary Dataflow</strong>: Optimizes for the compute patterns of convolutional neural networks
                <br>• <strong>Hierarchical Memory System</strong>: 528KB on-chip SRAM reduces external memory access
                <br>• <strong>Mixed-Precision Support</strong>: Native INT8, INT16, FP16, and BF16 computation capabilities`,
            },
            {
                type: 'heading',
                content: 'Target Application Domains',
                level: 2,
            },
            {
                type: 'table',
                content: JSON.stringify({
                    headers: ['Application Domain', 'Representative Models', 'Performance Requirements', 'Power Budget'],
                    rows: [
                        ['Computer Vision', 'MobileNet, EfficientNet, YOLO', '100-500 GOPS', '200-500mW'],
                        ['Smart Surveillance', 'RetinaFace, SSD-MobileNet', '200-400 GOPS', '300-600mW'],
                        ['Industrial IoT', 'Custom CNNs, Autoencoders', '50-200 GOPS', '100-300mW'],
                        ['Autonomous Systems', 'YOLO-Tiny, EfficientDet', '300-600 GOPS', '400-800mW'],
                        ['Voice Processing', 'DS-CNN, Transformer-Tiny', '10-50 GOPS', '50-150mW']
                    ],
                }),
            },
            {
                type: 'heading',
                content: 'Key Contributions',
                level: 2,
            },
            {
                type: 'list',
                content: '',
                items: [
                    '<strong>Novel PE Architecture</strong> — Optimized 8×8 MAC units with 32-bit accumulation for overflow prevention',
                    '<strong>Efficient Memory Hierarchy</strong> — Three-level memory system with double-buffering for latency hiding',
                    '<strong>Flexible Quantization Support</strong> — Hardware support for multiple precision formats with runtime switching',
                    '<strong>Comprehensive Software Stack</strong> — ONNX/TFLite compiler with automatic optimization passes',
                    '<strong>Energy-Efficient Design</strong> — Advanced power management achieving >1 TOPS/W efficiency',
                ],
            },
            {
                type: 'heading',
                content: 'Performance Benchmarks',
                level: 2,
            },
            {
                type: 'table',
                content: JSON.stringify({
                    headers: ['Metric', 'EdgeNPU', 'ARM Ethos-U55', 'Google Edge TPU', 'Intel Movidius'],
                    rows: [
                        ['Peak Performance (TOPS)', '0.512', '0.5', '4.0', '1.0'],
                        ['Power Consumption (W)', '0.5', '0.5', '2.0', '1.5'],
                        ['Energy Efficiency (TOPS/W)', '1.02', '1.0', '2.0', '0.67'],
                        ['On-chip Memory (KB)', '528', '256', '8192', '512'],
                        ['Process Technology', '28nm', '16nm', '14nm', '16nm']
                    ],
                }),
            },
            {
                type: 'note',
                content: 'Performance comparisons are based on published specifications and may vary depending on workload characteristics and implementation details.',
            },
        ],
    },

    features: {
        id: 'features',
        title: 'Key Features',
        description: 'Comprehensive feature overview of EdgeNPU capabilities',
        lastUpdated: '2026-01-06',
        blocks: [
            {
                type: 'heading',
                content: 'Compute Engine Specifications',
                level: 2,
            },
            {
                type: 'table',
                content: JSON.stringify({
                    headers: ['Parameter', 'Specification', 'Notes'],
                    rows: [
                        ['PE Array Size', '16 × 16 (256 MACs)', 'Configurable: 8×8 to 32×32'],
                        ['Peak INT8 Performance', '512 GOPS @ 1GHz', '2 ops/MAC (multiply + accumulate)'],
                        ['Peak INT16 Performance', '256 GOPS @ 1GHz', 'Full precision intermediate'],
                        ['Peak FP16 Performance', '128 GFLOPS @ 1GHz', 'IEEE 754 compliant'],
                        ['Accumulator Width', '32-bit', 'Prevents overflow in deep networks'],
                        ['Activation Functions', 'ReLU, ReLU6, Sigmoid, Tanh, Swish, GELU', 'Hardware accelerated'],
                    ],
                }),
            },
            {
                type: 'heading',
                content: 'Memory Subsystem',
                level: 2,
            },
            {
                type: 'table',
                content: JSON.stringify({
                    headers: ['Buffer', 'Capacity', 'Bus Width', 'Purpose'],
                    rows: [
                        ['Weight Buffer', '256 KB', '128-bit', 'Convolution kernel storage with double-buffering'],
                        ['Activation Buffer', '256 KB', '128-bit', 'Input/output feature map storage'],
                        ['Instruction Buffer', '16 KB', '64-bit', 'NPU microcode and layer descriptors'],
                        ['Total On-Chip SRAM', '528 KB', '—', 'Eliminates external memory access for small models'],
                    ],
                }),
            },
            {
                type: 'heading',
                content: 'Supported Neural Network Operations',
                level: 2,
            },
            {
                type: 'table',
                content: JSON.stringify({
                    headers: ['Category', 'Operations', 'Kernel Sizes'],
                    rows: [
                        ['Convolution', 'Conv2D, DepthwiseConv2D, TransposeConv2D, Dilated Conv', '1×1, 3×3, 5×5, 7×7'],
                        ['Pooling', 'MaxPool2D, AvgPool2D, GlobalAveragePool', '2×2, 3×3'],
                        ['Activation', 'ReLU, ReLU6, LeakyReLU, Sigmoid, Tanh, Swish, GELU, HardSwish', '—'],
                        ['Normalization', 'BatchNorm (fused), LayerNorm', '—'],
                        ['Element-wise', 'Add, Multiply, Subtract, Concat, Split, Reshape', '—'],
                        ['Linear', 'FullyConnected, MatMul', '—'],
                    ],
                }),
            },
            {
                type: 'heading',
                content: 'Interface Specifications',
                level: 2,
            },
            {
                type: 'table',
                content: JSON.stringify({
                    headers: ['Interface', 'Protocol', 'Width', 'Description'],
                    rows: [
                        ['Data Port', 'AXI4 Master', '128-bit', 'High-bandwidth DDR access, burst support'],
                        ['Control Port', 'AXI4-Lite Slave', '32-bit', 'Register configuration and status'],
                        ['Interrupt', 'Level-triggered', '1-bit', 'Completion, error, and DMA events'],
                        ['Debug Port', 'JTAG (optional)', '—', 'On-chip debugging and profiling'],
                    ],
                }),
            },
        ],
    },

    specifications: {
        id: 'specifications',
        title: 'Technical Specifications',
        description: 'Detailed technical specifications and electrical characteristics',
        lastUpdated: '2026-01-06',
        blocks: [
            {
                type: 'heading',
                content: 'Performance Specifications',
                level: 2,
            },
            {
                type: 'table',
                content: JSON.stringify({
                    headers: ['Parameter', 'Value', 'Conditions'],
                    rows: [
                        ['Peak INT8 Throughput', '512 GOPS', '@ 1 GHz, 100% utilization'],
                        ['Sustained INT8 Throughput', '~400 GOPS', 'Typical CNN workload'],
                        ['Peak FP16 Throughput', '128 GFLOPS', '@ 1 GHz'],
                        ['Memory Bandwidth (Internal)', '16 GB/s', '128-bit @ 1 GHz'],
                        ['Memory Bandwidth (External)', '12.8 GB/s', 'AXI4 128-bit @ 800 MHz'],
                        ['Latency (Single Layer)', '< 100 µs', 'Typical 3×3 Conv, 224×224 input'],
                    ],
                }),
            },
            {
                type: 'heading',
                content: 'Power Specifications',
                level: 2,
            },
            {
                type: 'table',
                content: JSON.stringify({
                    headers: ['Operating Mode', 'Power', 'Description'],
                    rows: [
                        ['Active (Peak)', '500 mW', 'Full PE utilization @ 1 GHz'],
                        ['Active (Typical)', '300 mW', '60% utilization @ 800 MHz'],
                        ['Idle', '50 mW', 'Clock gated, registers retained'],
                        ['Sleep', '5 mW', 'Power gated, state lost'],
                        ['Efficiency (Peak)', '> 1 TOPS/W', 'INT8 operations'],
                    ],
                }),
            },
            {
                type: 'heading',
                content: 'Electrical Characteristics',
                level: 2,
            },
            {
                type: 'table',
                content: JSON.stringify({
                    headers: ['Parameter', 'Min', 'Typical', 'Max', 'Unit'],
                    rows: [
                        ['Core Voltage (VDD)', '0.72', '0.80', '0.88', 'V'],
                        ['I/O Voltage (VDDIO)', '1.62', '1.80', '1.98', 'V'],
                        ['Operating Temperature', '-40', '25', '105', '°C'],
                        ['Clock Frequency', '100', '800', '1000', 'MHz'],
                    ],
                }),
            },
            {
                type: 'heading',
                content: 'Physical Implementation',
                level: 2,
            },
            {
                type: 'table',
                content: JSON.stringify({
                    headers: ['Parameter', '28nm', '16nm', '7nm'],
                    rows: [
                        ['Area Estimate', '2.5 mm²', '1.2 mm²', '0.6 mm²'],
                        ['Gate Count', '~5M', '~5M', '~5M'],
                        ['Max Frequency', '800 MHz', '1.0 GHz', '1.2 GHz'],
                        ['Power (Typical)', '400 mW', '250 mW', '150 mW'],
                    ],
                }),
            },
        ],
    },

    'system-architecture': {
        id: 'system-architecture',
        title: 'System Architecture',
        description: 'Detailed architectural analysis of EdgeNPU microarchitecture',
        lastUpdated: '2026-01-07',
        blocks: [
            {
                type: 'heading',
                content: 'Architectural Overview',
                level: 2,
            },
            {
                type: 'paragraph',
                content: `EdgeNPU implements a <strong>heterogeneous multicore architecture</strong> optimized for 
                deep neural network inference workloads. The design follows a <strong>dataflow computing paradigm</strong> 
                where computation is driven by data availability rather than instruction sequencing, enabling 
                high throughput and energy efficiency for tensor operations.`,
            },
            {
                type: 'diagram',
                content: 'system-overview',
            },
            {
                type: 'heading',
                content: 'Architectural Design Principles',
                level: 2,
            },
            {
                type: 'list',
                content: '',
                items: [
                    '<strong>Spatial Computing</strong> — 256 processing elements operate in parallel with dedicated datapaths',
                    '<strong>Data Locality</strong> — Hierarchical memory system minimizes data movement energy',
                    '<strong>Compute-Memory Balance</strong> — Memory bandwidth provisioned to sustain peak compute throughput',
                    '<strong>Scalable Design</strong> — Modular architecture supports 8×8 to 32×32 PE array configurations',
                ],
            },
            {
                type: 'heading',
                content: 'Major Functional Units',
                level: 2,
            },
            {
                type: 'table',
                content: JSON.stringify({
                    headers: ['Component', 'Function', 'Implementation Details', 'Area (mm²)'],
                    rows: [
                        ['PE Array', 'Matrix-matrix multiplication', '16×16 systolic array, weight-stationary', '1.2'],
                        ['Memory Subsystem', 'On-chip data storage', '528KB SRAM, 3-level hierarchy', '0.8'],
                        ['DMA Engine', 'Data movement controller', '4-channel, 2D/3D addressing', '0.3'],
                        ['NPU Controller', 'Instruction processing', 'RISC-based microcontroller', '0.2'],
                        ['Post-Processing', 'Activation & pooling', 'Configurable function units', '0.1'],
                        ['AXI Interface', 'System interconnect', 'AXI4 master + AXI4-Lite slave', '0.1']
                    ],
                }),
            },
            {
                type: 'heading',
                content: 'Memory Architecture',
                level: 2,
            },
            {
                type: 'diagram',
                content: 'memory-architecture',
            },
            {
                type: 'paragraph',
                content: `The memory subsystem implements a <strong>three-level hierarchy</strong> designed to exploit 
                the temporal and spatial locality characteristics of neural network computations:`,
            },
            {
                type: 'list',
                content: '',
                items: [
                    '<strong>L1: PE Registers</strong> — 1KB total capacity, 1-cycle access latency, distributed across PEs',
                    '<strong>L2: On-chip SRAM</strong> — 528KB capacity, 2-3 cycle access latency, banked for parallel access',
                    '<strong>L3: External DRAM</strong> — GB-scale capacity, 100+ cycle access latency, accessed via DMA',
                ],
            },
            {
                type: 'heading',
                content: 'Dataflow Execution Model',
                level: 2,
            },
            {
                type: 'diagram',
                content: 'dataflow-pipeline',
            },
            {
                type: 'paragraph',
                content: `EdgeNPU employs a <strong>layer-by-layer execution model</strong> with four-stage pipeline 
                overlapping to maximize resource utilization. The execution follows these phases:`,
            },
            {
                type: 'code',
                content: `// Pseudocode for layer execution
for each layer L in neural_network:
    // Stage 1: Instruction Fetch
    instruction = fetch_instruction(L.descriptor)
    
    // Stage 2: Data Loading (overlapped with previous layer)
    DMA.load_weights(L.weights → weight_buffer)
    DMA.load_activations(L.input → activation_buffer)
    
    // Stage 3: Computation
    PE_Array.configure(L.operation_type, L.dimensions)
    results = PE_Array.execute(weight_buffer, activation_buffer)
    
    // Stage 4: Post-processing & Store
    output = PostProcessor.apply(results, L.activation_func)
    DMA.store_results(output → L.output_location)`,
                language: 'text',
            },
            {
                type: 'heading',
                content: 'Performance Analysis',
                level: 2,
            },
            {
                type: 'table',
                content: JSON.stringify({
                    headers: ['Metric', 'Peak', 'Sustained', 'Bottleneck Analysis'],
                    rows: [
                        ['Compute (GOPS)', '512', '~400', 'Memory bandwidth limited'],
                        ['Memory BW (GB/s)', '16', '12.8', 'External DRAM interface'],
                        ['Power (mW)', '500', '300-400', 'PE array dominates (60%)'],
                        ['Utilization (%)', '100', '75-85', 'Depends on model structure']
                    ],
                }),
            },
        ],
    },

    'pe-array': {
        id: 'pe-array',
        title: 'Processing Element Array Architecture',
        description: 'Detailed microarchitectural analysis of the systolic array',
        lastUpdated: '2026-01-07',
        blocks: [
            {
                type: 'heading',
                content: 'Systolic Array Fundamentals',
                level: 2,
            },
            {
                type: 'paragraph',
                content: `The PE Array implements a <strong>weight-stationary systolic architecture</strong> based on 
                the seminal work by Kung and Leiserson (1978). This design choice optimizes for the computational 
                patterns of convolutional neural networks, where weights exhibit high reuse across multiple 
                input activations. The 16×16 configuration provides an optimal balance between computational 
                throughput and hardware complexity for edge deployment scenarios.`,
            },
            {
                type: 'diagram',
                content: 'pe-detail',
            },
            {
                type: 'heading',
                content: 'Processing Element Microarchitecture',
                level: 2,
            },
            {
                type: 'paragraph',
                content: `Each PE implements a single-cycle multiply-accumulate (MAC) operation with the following 
                architectural features:`,
            },
            {
                type: 'table',
                content: JSON.stringify({
                    headers: ['Component', 'Specification', 'Design Rationale', 'Area (μm²)'],
                    rows: [
                        ['Multiplier', '8×8 → 16-bit signed', 'Booth radix-4 encoding for area efficiency', '2400'],
                        ['Accumulator', '32-bit with saturation', 'Prevents overflow in deep networks', '800'],
                        ['Weight Register', '8-bit with bypass', 'Supports weight-stationary dataflow', '200'],
                        ['Control Logic', 'FSM-based', 'Handles load/clear/enable signals', '400'],
                        ['Interconnect', 'Nearest-neighbor', 'Minimizes routing complexity', '600']
                    ],
                }),
            },
            {
                type: 'heading',
                content: 'Dataflow Analysis',
                level: 2,
            },
            {
                type: 'paragraph',
                content: `The weight-stationary dataflow offers several advantages for CNN acceleration:`,
            },
            {
                type: 'list',
                content: '',
                items: [
                    '<strong>Weight Reuse</strong> — Each weight is used for H×W computations (where H,W are output dimensions)',
                    '<strong>Reduced Memory Traffic</strong> — Weights loaded once per output channel group',
                    '<strong>Predictable Access Patterns</strong> — Enables efficient memory controller design',
                    '<strong>Energy Efficiency</strong> — Minimizes data movement, the dominant energy consumer',
                ],
            },
            {
                type: 'code',
                content: `// PE RTL implementation (simplified)
module processing_element #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32
)(
    input  logic                        clk,
    input  logic                        rst_n,
    input  logic                        enable,
    input  logic                        load_weight,
    input  logic                        clear_acc,
    
    // Systolic dataflow
    input  logic [DATA_WIDTH-1:0]      data_in,
    input  logic [DATA_WIDTH-1:0]      weight_in,
    output logic [DATA_WIDTH-1:0]      data_out,
    output logic [ACC_WIDTH-1:0]       acc_out
);

    // Weight register (stationary)
    logic [DATA_WIDTH-1:0] weight_reg;
    always_ff @(posedge clk) begin
        if (load_weight) weight_reg <= weight_in;
    end
    
    // MAC operation
    logic [2*DATA_WIDTH-1:0] mult_result;
    logic [ACC_WIDTH-1:0] acc_reg;
    
    assign mult_result = $signed(data_in) * $signed(weight_reg);
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc_reg <= '0;
        end else if (clear_acc) begin
            acc_reg <= '0;
        end else if (enable) begin
            acc_reg <= acc_reg + {{(ACC_WIDTH-2*DATA_WIDTH){mult_result[2*DATA_WIDTH-1]}}, mult_result};
        end
    end
    
    // Systolic propagation
    always_ff @(posedge clk) begin
        if (enable) data_out <= data_in;
    end
    
    assign acc_out = acc_reg;
    
endmodule`,
                language: 'verilog',
            },
            {
                type: 'heading',
                content: 'Mapping Strategies',
                level: 2,
            },
            {
                type: 'paragraph',
                content: `Efficient mapping of neural network layers to the systolic array requires careful consideration 
                of data reuse patterns and memory constraints:`,
            },
            {
                type: 'table',
                content: JSON.stringify({
                    headers: ['Layer Type', 'Mapping Strategy', 'PE Utilization', 'Memory Requirement'],
                    rows: [
                        ['Conv2D (3×3)', 'Output-stationary tiling', '95-100%', 'O(K²×C) weights'],
                        ['Conv2D (1×1)', 'Channel-parallel mapping', '100%', 'O(C_in×C_out) weights'],
                        ['DepthwiseConv', 'Spatial parallelism', '60-80%', 'O(K²×C) weights'],
                        ['Fully Connected', 'Weight-parallel mapping', '100%', 'O(N×M) weights'],
                        ['Element-wise ops', 'Vector processing', '25-50%', 'Minimal weight storage']
                    ],
                }),
            },
            {
                type: 'heading',
                content: 'Performance Modeling',
                level: 2,
            },
            {
                type: 'paragraph',
                content: `The theoretical peak performance can be calculated as:`,
            },
            {
                type: 'code',
                content: `Peak_GOPS = PE_count × Clock_frequency × Operations_per_cycle
          = 256 × 1 GHz × 2 ops/cycle
          = 512 GOPS (for INT8 MAC operations)

Sustained performance depends on:
- Memory bandwidth utilization: η_mem
- PE array utilization: η_pe  
- Pipeline efficiency: η_pipe

Sustained_GOPS = Peak_GOPS × η_mem × η_pe × η_pipe
               ≈ 512 × 0.8 × 0.9 × 0.95
               ≈ 350-400 GOPS (typical CNN workloads)`,
                language: 'text',
            },
            {
                type: 'warning',
                content: 'Actual performance varies significantly based on layer dimensions, data types, and memory access patterns. The compiler performs automatic tiling optimization to maximize utilization.',
            },
        ],
    },

    'memory-subsystem': {
        id: 'memory-subsystem',
        title: 'Memory Subsystem',
        description: 'On-chip memory architecture and buffer management',
        lastUpdated: '2026-01-06',
        blocks: [
            {
                type: 'heading',
                content: 'Memory Architecture Overview',
                level: 2,
            },
            {
                type: 'paragraph',
                content: `EdgeNPU features a <strong>528KB on-chip SRAM subsystem</strong> designed to minimize 
                external memory access and maximize data reuse. The memory is partitioned into specialized 
                buffers optimized for different data types.`,
            },
            {
                type: 'table',
                content: JSON.stringify({
                    headers: ['Buffer', 'Size', 'Banks', 'Access Pattern'],
                    rows: [
                        ['Weight Buffer', '256 KB', '16', 'Sequential read, DMA write'],
                        ['Activation Buffer', '256 KB', '16', 'Random read/write, double-buffered'],
                        ['Instruction Buffer', '16 KB', '2', 'Sequential fetch'],
                    ],
                }),
            },
            {
                type: 'heading',
                content: 'Double Buffering',
                level: 2,
            },
            {
                type: 'paragraph',
                content: `The activation buffer supports <strong>double buffering</strong> to overlap computation 
                with data transfer. While the PE array processes data from one buffer half, the DMA engine 
                loads the next layer's data into the other half.`,
            },
            {
                type: 'code',
                content: `// Double buffering timeline
Cycle:    |----Layer N Compute----|----Layer N+1 Compute----|
DMA:      |--Load N+1--|          |--Load N+2--|
Buffer A: [Layer N Data]          [Layer N+2 Data]
Buffer B:              [Layer N+1 Data]`,
                language: 'text',
            },
            {
                type: 'heading',
                content: 'Memory Bandwidth Analysis',
                level: 2,
            },
            {
                type: 'table',
                content: JSON.stringify({
                    headers: ['Path', 'Bandwidth', 'Calculation'],
                    rows: [
                        ['Weight Buffer → PE Array', '16 GB/s', '128-bit × 16 banks × 1 GHz'],
                        ['Act Buffer → PE Array', '16 GB/s', '128-bit × 16 banks × 1 GHz'],
                        ['External DDR (AXI4)', '12.8 GB/s', '128-bit × 800 MHz'],
                    ],
                }),
            },
        ],
    },

    'dma-engine': {
        id: 'dma-engine',
        title: 'DMA Engine',
        description: 'Direct Memory Access controller for efficient data movement',
        lastUpdated: '2026-01-06',
        blocks: [
            {
                type: 'heading',
                content: 'DMA Controller Architecture',
                level: 2,
            },
            {
                type: 'paragraph',
                content: `The DMA Engine provides high-bandwidth data transfer between external memory and 
                on-chip buffers. It supports <strong>4 independent channels</strong> for concurrent 
                weight, activation, instruction, and output transfers.`,
            },
            {
                type: 'table',
                content: JSON.stringify({
                    headers: ['Channel', 'Direction', 'Target Buffer', 'Use Case'],
                    rows: [
                        ['Channel 0', 'Read', 'Weight Buffer', 'Load convolution kernels'],
                        ['Channel 1', 'Read', 'Activation Buffer', 'Load input feature maps'],
                        ['Channel 2', 'Write', 'External Memory', 'Store output results'],
                        ['Channel 3', 'Read', 'Instruction Buffer', 'Load layer descriptors'],
                    ],
                }),
            },
            {
                type: 'heading',
                content: 'DMA Features',
                level: 2,
            },
            {
                type: 'list',
                content: '',
                items: [
                    '<strong>2D/3D Transfers</strong> — Strided access for tensor slicing and tiling',
                    '<strong>Scatter-Gather</strong> — Non-contiguous memory access via descriptor chains',
                    '<strong>Address Generation</strong> — Automatic address calculation for common patterns',
                    '<strong>Burst Optimization</strong> — AXI4 burst transactions up to 256 beats',
                ],
            },
            {
                type: 'heading',
                content: 'DMA Descriptor Format',
                level: 2,
            },
            {
                type: 'code',
                content: `typedef struct packed {
    logic [39:0] src_addr;      // Source address (40-bit)
    logic [39:0] dst_addr;      // Destination address (40-bit)
    logic [23:0] length;        // Transfer length in bytes
    logic [15:0] src_stride;    // Source stride for 2D transfers
    logic [15:0] dst_stride;    // Destination stride for 2D transfers
    logic [7:0]  flags;         // Control flags
    // flags[0]: Enable interrupt on completion
    // flags[1]: Chain to next descriptor
    // flags[2]: 2D transfer mode
    // flags[3]: Increment source address
    // flags[4]: Increment destination address
} dma_desc_t;`,
                language: 'verilog',
            },
        ],
    },

    'register-map': {
        id: 'register-map',
        title: 'Register Map',
        description: 'Complete register reference for NPU control and status',
        lastUpdated: '2026-01-06',
        blocks: [
            {
                type: 'heading',
                content: 'Register Overview',
                level: 2,
            },
            {
                type: 'paragraph',
                content: `EdgeNPU is controlled via memory-mapped registers accessible through the 
                <strong>AXI4-Lite slave interface</strong>. The register space is organized into 
                control, status, interrupt, and DMA register groups.`,
            },
            {
                type: 'table',
                content: JSON.stringify({
                    headers: ['Offset', 'Name', 'Access', 'Reset', 'Description'],
                    rows: [
                        ['0x000', 'CTRL', 'R/W', '0x0', 'NPU control register'],
                        ['0x004', 'STATUS', 'R', '0x0', 'NPU status register'],
                        ['0x008', 'IRQ_EN', 'R/W', '0x0', 'Interrupt enable mask'],
                        ['0x00C', 'IRQ_STATUS', 'R/W1C', '0x0', 'Interrupt status (write 1 to clear)'],
                        ['0x010', 'VERSION', 'R', '0x00010000', 'Hardware version (v1.0.0)'],
                        ['0x014', 'CONFIG', 'R', '—', 'PE array configuration'],
                        ['0x020', 'PERF_CNT', 'R', '0x0', 'Performance counter'],
                    ],
                }),
            },
            {
                type: 'heading',
                content: 'Control Register (CTRL) — 0x000',
                level: 2,
            },
            {
                type: 'table',
                content: JSON.stringify({
                    headers: ['Bits', 'Field', 'Access', 'Description'],
                    rows: [
                        ['0', 'ENABLE', 'R/W', 'NPU enable (1=enabled)'],
                        ['1', 'START', 'R/W', 'Start execution (auto-clears)'],
                        ['2', 'SOFT_RESET', 'R/W', 'Soft reset (auto-clears)'],
                        ['3', 'IRQ_GLOBAL_EN', 'R/W', 'Global interrupt enable'],
                        ['7:4', 'MODE', 'R/W', 'Operating mode (0=normal, 1=debug)'],
                        ['31:8', 'Reserved', 'R', 'Reserved, read as 0'],
                    ],
                }),
            },
            {
                type: 'heading',
                content: 'Status Register (STATUS) — 0x004',
                level: 2,
            },
            {
                type: 'table',
                content: JSON.stringify({
                    headers: ['Bits', 'Field', 'Description'],
                    rows: [
                        ['0', 'BUSY', 'NPU is executing (1=busy)'],
                        ['1', 'DONE', 'Execution complete (1=done)'],
                        ['2', 'ERROR', 'Error occurred (1=error)'],
                        ['7:4', 'STATE', 'Controller state machine'],
                        ['15:8', 'LAYER_CNT', 'Current layer being processed'],
                        ['31:16', 'Reserved', 'Reserved'],
                    ],
                }),
            },
            {
                type: 'heading',
                content: 'DMA Registers',
                level: 2,
            },
            {
                type: 'table',
                content: JSON.stringify({
                    headers: ['Offset', 'Name', 'Access', 'Description'],
                    rows: [
                        ['0x100', 'DMA_CTRL', 'R/W', 'DMA control (bit 0: start)'],
                        ['0x104', 'DMA_STATUS', 'R', 'DMA status (bit 0: busy, bit 1: done)'],
                        ['0x108', 'DMA_SRC', 'R/W', 'Source address [31:0]'],
                        ['0x10C', 'DMA_DST', 'R/W', 'Destination address [31:0]'],
                        ['0x110', 'DMA_LEN', 'R/W', 'Transfer length in bytes'],
                        ['0x114', 'DMA_STRIDE', 'R/W', 'Source/dest stride for 2D'],
                    ],
                }),
            },
            {
                type: 'heading',
                content: 'Register Access Example',
                level: 2,
            },
            {
                type: 'code',
                content: `#define NPU_BASE        0x40000000

// Register access macros
#define NPU_REG(offset) (*(volatile uint32_t *)(NPU_BASE + (offset)))
#define NPU_CTRL        NPU_REG(0x000)
#define NPU_STATUS      NPU_REG(0x004)
#define NPU_IRQ_EN      NPU_REG(0x008)
#define NPU_IRQ_STATUS  NPU_REG(0x00C)
#define NPU_VERSION     NPU_REG(0x010)

// Start NPU execution
void npu_start(void) {
    NPU_CTRL |= (1 << 0);  // Enable
    NPU_CTRL |= (1 << 1);  // Start (auto-clears)
}

// Wait for completion
void npu_wait_done(void) {
    while (!(NPU_STATUS & (1 << 1)));  // Poll DONE bit
}

// Check for errors
bool npu_check_error(void) {
    return (NPU_STATUS & (1 << 2)) != 0;
}`,
                language: 'c',
            },
        ],
    },

    'instruction-set': {
        id: 'instruction-set',
        title: 'Instruction Set Architecture',
        description: 'NPU instruction encoding and operation reference',
        lastUpdated: '2026-01-06',
        blocks: [
            {
                type: 'heading',
                content: 'Instruction Format',
                level: 2,
            },
            {
                type: 'paragraph',
                content: `EdgeNPU uses a <strong>64-bit fixed-width instruction format</strong> designed for 
                efficient decoding and compact representation of neural network operations.`,
            },
            {
                type: 'code',
                content: `// 64-bit Instruction Format
┌────────┬────────┬──────────┬──────────┬──────────┬────────────────────┐
│ 63:60  │ 59:56  │  55:48   │  47:40   │  39:32   │       31:0         │
├────────┼────────┼──────────┼──────────┼──────────┼────────────────────┤
│ OPCODE │ FLAGS  │ DST_ADDR │ SRC0_ADDR│ SRC1_ADDR│     IMMEDIATE      │
│ 4-bit  │ 4-bit  │  8-bit   │  8-bit   │  8-bit   │      32-bit        │
└────────┴────────┴──────────┴──────────┴──────────┴────────────────────┘`,
                language: 'text',
            },
            {
                type: 'heading',
                content: 'Opcode Reference',
                level: 2,
            },
            {
                type: 'table',
                content: JSON.stringify({
                    headers: ['Opcode', 'Mnemonic', 'Description', 'Operands'],
                    rows: [
                        ['0x0', 'NOP', 'No operation', '—'],
                        ['0x1', 'CONV', 'Convolution operation', 'dst, src_act, src_weight'],
                        ['0x2', 'FC', 'Fully connected layer', 'dst, src_act, src_weight'],
                        ['0x3', 'POOL', 'Pooling operation', 'dst, src, pool_type'],
                        ['0x4', 'ACT', 'Activation function', 'dst, src, act_type'],
                        ['0x5', 'LOAD', 'Load from external memory', 'dst_buf, ext_addr, len'],
                        ['0x6', 'STORE', 'Store to external memory', 'ext_addr, src_buf, len'],
                        ['0x7', 'SYNC', 'Synchronization barrier', '—'],
                        ['0x8', 'ADD', 'Element-wise addition', 'dst, src0, src1'],
                        ['0x9', 'MUL', 'Element-wise multiply', 'dst, src0, src1'],
                        ['0xA', 'CONCAT', 'Tensor concatenation', 'dst, src0, src1, axis'],
                        ['0xB', 'SPLIT', 'Tensor splitting', 'dst0, dst1, src, axis'],
                    ],
                }),
            },
            {
                type: 'heading',
                content: 'Activation Function Encoding',
                level: 2,
            },
            {
                type: 'table',
                content: JSON.stringify({
                    headers: ['Code', 'Function', 'Formula'],
                    rows: [
                        ['0', 'None', 'f(x) = x'],
                        ['1', 'ReLU', 'f(x) = max(0, x)'],
                        ['2', 'ReLU6', 'f(x) = min(max(0, x), 6)'],
                        ['3', 'Sigmoid', 'f(x) = 1 / (1 + e^(-x))'],
                        ['4', 'Tanh', 'f(x) = tanh(x)'],
                        ['5', 'Swish', 'f(x) = x × sigmoid(x)'],
                        ['6', 'GELU', 'f(x) = x × Φ(x)'],
                    ],
                }),
            },
        ],
    },

    'c-api': {
        id: 'c-api',
        title: 'C/C++ Runtime API',
        description: 'C/C++ API reference for EdgeNPU runtime library',
        lastUpdated: '2026-01-06',
        blocks: [
            {
                type: 'heading',
                content: 'API Overview',
                level: 2,
            },
            {
                type: 'paragraph',
                content: `The EdgeNPU C/C++ Runtime provides a low-level API for model loading, 
                inference execution, and device management. The API follows a handle-based design 
                pattern for resource management.`,
            },
            {
                type: 'heading',
                content: 'Core Types',
                level: 2,
            },
            {
                type: 'code',
                content: `#include <edgenpu/runtime.h>

// Status codes
typedef enum {
    ENPU_OK = 0,
    ENPU_ERROR_INVALID_PARAM = -1,
    ENPU_ERROR_OUT_OF_MEMORY = -2,
    ENPU_ERROR_DEVICE_NOT_FOUND = -3,
    ENPU_ERROR_MODEL_INVALID = -4,
    ENPU_ERROR_TIMEOUT = -5,
    ENPU_ERROR_HARDWARE = -6,
} enpu_status_t;

// Data types
typedef enum {
    ENPU_DTYPE_INT8 = 0,
    ENPU_DTYPE_INT16 = 1,
    ENPU_DTYPE_FP16 = 2,
    ENPU_DTYPE_BF16 = 3,
    ENPU_DTYPE_FP32 = 4,  // For host-side only
} enpu_dtype_t;

// Opaque handles
typedef struct enpu_context_s* enpu_context_t;
typedef struct enpu_model_s* enpu_model_t;
typedef struct enpu_tensor_s* enpu_tensor_t;`,
                language: 'c',
            },
            {
                type: 'heading',
                content: 'Initialization & Cleanup',
                level: 2,
            },
            {
                type: 'code',
                content: `// Initialize EdgeNPU runtime
enpu_status_t enpu_init(enpu_context_t* ctx);

// Get device information
enpu_status_t enpu_get_device_info(
    enpu_context_t ctx,
    enpu_device_info_t* info
);

// Shutdown and release resources
void enpu_deinit(enpu_context_t ctx);`,
                language: 'c',
            },
            {
                type: 'heading',
                content: 'Model Management',
                level: 2,
            },
            {
                type: 'code',
                content: `// Load compiled model from file
enpu_status_t enpu_load_model(
    enpu_context_t ctx,
    const char* model_path,
    enpu_model_t* model
);

// Load model from memory buffer
enpu_status_t enpu_load_model_from_buffer(
    enpu_context_t ctx,
    const void* buffer,
    size_t size,
    enpu_model_t* model
);

// Get model input/output tensor info
enpu_status_t enpu_get_input_tensor_info(
    enpu_model_t model,
    int index,
    enpu_tensor_info_t* info
);

enpu_status_t enpu_get_output_tensor_info(
    enpu_model_t model,
    int index,
    enpu_tensor_info_t* info
);

// Release model resources
void enpu_unload_model(enpu_model_t model);`,
                language: 'c',
            },
            {
                type: 'heading',
                content: 'Inference Execution',
                level: 2,
            },
            {
                type: 'code',
                content: `// Set input tensor data
enpu_status_t enpu_set_input(
    enpu_model_t model,
    int input_index,
    const void* data,
    size_t size
);

// Run inference (blocking)
enpu_status_t enpu_invoke(enpu_model_t model);

// Run inference (non-blocking)
enpu_status_t enpu_invoke_async(
    enpu_model_t model,
    enpu_callback_t callback,
    void* user_data
);

// Wait for async completion
enpu_status_t enpu_wait(enpu_model_t model, uint32_t timeout_ms);

// Get output tensor data
enpu_status_t enpu_get_output(
    enpu_model_t model,
    int output_index,
    void* buffer,
    size_t buffer_size
);`,
                language: 'c',
            },
            {
                type: 'heading',
                content: 'Complete Example',
                level: 2,
            },
            {
                type: 'code',
                content: `#include <stdio.h>
#include <edgenpu/runtime.h>

int main(int argc, char* argv[]) {
    enpu_context_t ctx;
    enpu_model_t model;
    enpu_status_t status;
    
    // Initialize runtime
    status = enpu_init(&ctx);
    if (status != ENPU_OK) {
        fprintf(stderr, "Failed to initialize: %d\\n", status);
        return 1;
    }
    
    // Print device info
    enpu_device_info_t info;
    enpu_get_device_info(ctx, &info);
    printf("Device: %s v%d.%d.%d\\n", 
           info.name, info.version_major, 
           info.version_minor, info.version_patch);
    printf("PE Array: %dx%d\\n", info.pe_rows, info.pe_cols);
    
    // Load model
    status = enpu_load_model(ctx, "mobilenet_v2_int8.enpu", &model);
    if (status != ENPU_OK) {
        fprintf(stderr, "Failed to load model: %d\\n", status);
        enpu_deinit(ctx);
        return 1;
    }
    
    // Prepare input (224x224x3 INT8 image)
    int8_t input[224 * 224 * 3];
    // ... load and preprocess image ...
    
    // Set input and run inference
    enpu_set_input(model, 0, input, sizeof(input));
    status = enpu_invoke(model);
    
    if (status == ENPU_OK) {
        // Get output (1000 class scores)
        int8_t output[1000];
        enpu_get_output(model, 0, output, sizeof(output));
        
        // Find top prediction
        int top_class = 0;
        for (int i = 1; i < 1000; i++) {
            if (output[i] > output[top_class])
                top_class = i;
        }
        printf("Predicted class: %d\\n", top_class);
    }
    
    // Cleanup
    enpu_unload_model(model);
    enpu_deinit(ctx);
    return 0;
}`,
                language: 'c',
            },
        ],
    },

    'python-api': {
        id: 'python-api',
        title: 'Python SDK',
        description: 'Python SDK reference for EdgeNPU',
        lastUpdated: '2026-01-06',
        blocks: [
            {
                type: 'heading',
                content: 'Installation',
                level: 2,
            },
            {
                type: 'code',
                content: `# Install from PyPI
pip install edgenpu

# Or install from source
git clone https://github.com/edgenpu/edgenpu-python.git
cd edgenpu-python
pip install -e .`,
                language: 'bash',
            },
            {
                type: 'heading',
                content: 'Quick Start',
                level: 2,
            },
            {
                type: 'code',
                content: `import edgenpu as enpu
import numpy as np

# Initialize runtime
enpu.init()

# Load and run model
model = enpu.load_model("mobilenet_v2.onnx", dtype="int8")
output = model(input_image)

# Cleanup
enpu.deinit()`,
                language: 'python',
            },
            {
                type: 'heading',
                content: 'API Reference',
                level: 2,
            },
            {
                type: 'code',
                content: `import edgenpu as enpu

# ============ Initialization ============
enpu.init()                    # Initialize runtime
enpu.deinit()                  # Shutdown runtime
info = enpu.get_device_info()  # Get device information

# ============ Model Loading ============
# Load from ONNX (auto-compile)
model = enpu.load_model("model.onnx", dtype="int8")

# Load from TFLite (auto-compile)
model = enpu.load_model("model.tflite", dtype="int8")

# Load pre-compiled model
model = enpu.load_model("model.enpu")

# ============ Model Information ============
print(model.summary())         # Print model summary
model.input_shapes             # List of input shapes
model.output_shapes            # List of output shapes
model.input_dtypes             # List of input dtypes
model.output_dtypes            # List of output dtypes

# ============ Inference ============
# Single input
output = model(input_data)

# Multiple inputs
outputs = model([input1, input2])

# Named inputs
outputs = model({"input_0": data0, "input_1": data1})

# ============ Profiling ============
result = model.profile(input_data, num_runs=100)
print(f"Latency: {result.latency_ms:.2f} ms")
print(f"Throughput: {result.throughput_fps:.1f} FPS")`,
                language: 'python',
            },
            {
                type: 'heading',
                content: 'Complete Example',
                level: 2,
            },
            {
                type: 'code',
                content: `import edgenpu as enpu
import numpy as np
from PIL import Image

def preprocess_image(image_path, size=(224, 224)):
    """Preprocess image for MobileNet inference."""
    img = Image.open(image_path).convert('RGB')
    img = img.resize(size, Image.BILINEAR)
    arr = np.array(img, dtype=np.float32)
    
    # Normalize to [-1, 1] range
    arr = (arr - 128.0) / 128.0
    
    # Quantize to INT8
    arr = np.clip(arr * 127, -128, 127).astype(np.int8)
    
    # Add batch dimension: (H, W, C) -> (1, H, W, C)
    return np.expand_dims(arr, axis=0)

def main():
    # Initialize EdgeNPU
    enpu.init()
    
    # Print device information
    info = enpu.get_device_info()
    print(f"Device: {info.name}")
    print(f"Version: {info.version}")
    print(f"PE Array: {info.pe_rows}×{info.pe_cols}")
    print(f"On-chip Memory: {info.sram_size // 1024} KB")
    
    # Load model
    model = enpu.load_model(
        "mobilenet_v2_1.0_224_quant.tflite",
        dtype="int8"
    )
    print(f"\\nModel loaded: {model.name}")
    print(model.summary())
    
    # Preprocess input
    input_data = preprocess_image("cat.jpg")
    
    # Run inference
    output = model(input_data)
    
    # Get prediction
    class_id = np.argmax(output)
    confidence = np.max(output) / 127.0  # Dequantize
    print(f"\\nPrediction: class {class_id}")
    print(f"Confidence: {confidence:.2%}")
    
    # Performance profiling
    print("\\nProfiling (100 runs)...")
    result = model.profile(input_data, num_runs=100)
    print(f"  Latency: {result.latency_ms:.2f} ms")
    print(f"  Throughput: {result.throughput_fps:.1f} FPS")
    print(f"  Power: {result.power_mw:.0f} mW")
    
    # Cleanup
    enpu.deinit()

if __name__ == "__main__":
    main()`,
                language: 'python',
            },
        ],
    },

    'soc-integration': {
        id: 'soc-integration',
        title: 'SoC Integration',
        description: 'Guide for integrating EdgeNPU into System-on-Chip designs',
        lastUpdated: '2026-01-06',
        blocks: [
            {
                type: 'heading',
                content: 'Integration Overview',
                level: 2,
            },
            {
                type: 'paragraph',
                content: `EdgeNPU is designed as a drop-in IP block for SoC integration. It connects to the 
                system through standard <strong>AXI4</strong> and <strong>AXI4-Lite</strong> interfaces, 
                making it compatible with most ARM-based and RISC-V SoC platforms.`,
            },
            {
                type: 'heading',
                content: 'Interface Summary',
                level: 2,
            },
            {
                type: 'table',
                content: JSON.stringify({
                    headers: ['Interface', 'Type', 'Width', 'Connection'],
                    rows: [
                        ['m_axi_*', 'AXI4 Master', '128-bit data', 'Memory interconnect'],
                        ['s_axil_*', 'AXI4-Lite Slave', '32-bit data', 'APB/AXI bridge'],
                        ['clk', 'Input', '1-bit', 'NPU clock domain'],
                        ['rst_n', 'Input', '1-bit', 'Active-low reset'],
                        ['irq', 'Output', '1-bit', 'Interrupt controller'],
                    ],
                }),
            },
            {
                type: 'heading',
                content: 'RTL Instantiation',
                level: 2,
            },
            {
                type: 'code',
                content: `// EdgeNPU instantiation example
npu_top #(
    .PE_ROWS      (16),           // PE array rows
    .PE_COLS      (16),           // PE array columns
    .DATA_WIDTH   (8),            // Data precision
    .AXI_DATA_W   (128),          // AXI data width
    .AXI_ADDR_W   (40),           // AXI address width
    .AXIL_DATA_W  (32),           // AXI-Lite data width
    .AXIL_ADDR_W  (32)            // AXI-Lite address width
) u_edgenpu (
    // Clock and Reset
    .clk          (npu_clk),
    .rst_n        (npu_rst_n),
    
    // AXI4 Master Interface (to memory)
    .m_axi_awaddr (npu_axi_awaddr),
    .m_axi_awlen  (npu_axi_awlen),
    .m_axi_awsize (npu_axi_awsize),
    .m_axi_awburst(npu_axi_awburst),
    .m_axi_awvalid(npu_axi_awvalid),
    .m_axi_awready(npu_axi_awready),
    .m_axi_wdata  (npu_axi_wdata),
    .m_axi_wstrb  (npu_axi_wstrb),
    .m_axi_wlast  (npu_axi_wlast),
    .m_axi_wvalid (npu_axi_wvalid),
    .m_axi_wready (npu_axi_wready),
    .m_axi_bresp  (npu_axi_bresp),
    .m_axi_bvalid (npu_axi_bvalid),
    .m_axi_bready (npu_axi_bready),
    .m_axi_araddr (npu_axi_araddr),
    .m_axi_arlen  (npu_axi_arlen),
    .m_axi_arsize (npu_axi_arsize),
    .m_axi_arburst(npu_axi_arburst),
    .m_axi_arvalid(npu_axi_arvalid),
    .m_axi_arready(npu_axi_arready),
    .m_axi_rdata  (npu_axi_rdata),
    .m_axi_rresp  (npu_axi_rresp),
    .m_axi_rlast  (npu_axi_rlast),
    .m_axi_rvalid (npu_axi_rvalid),
    .m_axi_rready (npu_axi_rready),
    
    // AXI4-Lite Slave Interface (registers)
    .s_axil_awaddr (npu_axil_awaddr),
    .s_axil_awvalid(npu_axil_awvalid),
    .s_axil_awready(npu_axil_awready),
    .s_axil_wdata  (npu_axil_wdata),
    .s_axil_wstrb  (npu_axil_wstrb),
    .s_axil_wvalid (npu_axil_wvalid),
    .s_axil_wready (npu_axil_wready),
    .s_axil_bresp  (npu_axil_bresp),
    .s_axil_bvalid (npu_axil_bvalid),
    .s_axil_bready (npu_axil_bready),
    .s_axil_araddr (npu_axil_araddr),
    .s_axil_arvalid(npu_axil_arvalid),
    .s_axil_arready(npu_axil_arready),
    .s_axil_rdata  (npu_axil_rdata),
    .s_axil_rresp  (npu_axil_rresp),
    .s_axil_rvalid (npu_axil_rvalid),
    .s_axil_rready (npu_axil_rready),
    
    // Interrupt
    .irq          (npu_irq)
);`,
                language: 'verilog',
            },
            {
                type: 'heading',
                content: 'Memory Map Recommendations',
                level: 2,
            },
            {
                type: 'table',
                content: JSON.stringify({
                    headers: ['Region', 'Base Address', 'Size', 'Description'],
                    rows: [
                        ['NPU Registers', '0x4000_0000', '4 KB', 'AXI-Lite register space'],
                        ['Weight Memory', '0x8000_0000', '16 MB', 'DDR region for weights'],
                        ['Activation Memory', '0x8100_0000', '16 MB', 'DDR region for activations'],
                        ['Model Storage', '0x8200_0000', '32 MB', 'DDR region for compiled models'],
                    ],
                }),
            },
            {
                type: 'note',
                content: 'Memory addresses are examples. Actual addresses depend on your SoC memory map. Ensure NPU has access to contiguous physical memory for optimal DMA performance.',
            },
        ],
    },

    quickstart: {
        id: 'quickstart',
        title: 'Quick Start Guide',
        description: 'Get started with EdgeNPU in 5 minutes',
        lastUpdated: '2026-01-06',
        blocks: [
            {
                type: 'heading',
                content: 'Prerequisites',
                level: 2,
            },
            {
                type: 'list',
                content: '',
                items: [
                    'Linux system (Ubuntu 20.04+ recommended)',
                    'Python 3.8 or later',
                    'EdgeNPU hardware or simulation environment',
                ],
            },
            {
                type: 'heading',
                content: 'Step 1: Install SDK',
                level: 2,
            },
            {
                type: 'code',
                content: `# Install EdgeNPU Python SDK
pip install edgenpu

# Verify installation
python -c "import edgenpu; print(edgenpu.__version__)"`,
                language: 'bash',
            },
            {
                type: 'heading',
                content: 'Step 2: Download Sample Model',
                level: 2,
            },
            {
                type: 'code',
                content: `# Download pre-quantized MobileNetV2
wget https://github.com/edgenpu/models/releases/download/v1.0/mobilenet_v2_int8.tflite

# Or use the model zoo
edgenpu-model download mobilenet_v2`,
                language: 'bash',
            },
            {
                type: 'heading',
                content: 'Step 3: Run Inference',
                level: 2,
            },
            {
                type: 'code',
                content: `import edgenpu as enpu
import numpy as np

# Initialize
enpu.init()

# Load model (auto-compiles TFLite to EdgeNPU format)
model = enpu.load_model("mobilenet_v2_int8.tflite")

# Create dummy input (224x224x3 INT8)
input_data = np.random.randint(-128, 127, (1, 224, 224, 3), dtype=np.int8)

# Run inference
output = model(input_data)
print(f"Output shape: {output.shape}")
print(f"Top-5 classes: {np.argsort(output[0])[-5:][::-1]}")

# Cleanup
enpu.deinit()`,
                language: 'python',
            },
            {
                type: 'heading',
                content: 'Step 4: Benchmark Performance',
                level: 2,
            },
            {
                type: 'code',
                content: `# Profile model performance
result = model.profile(input_data, num_runs=100)

print(f"Latency: {result.latency_ms:.2f} ms")
print(f"Throughput: {result.throughput_fps:.1f} FPS")
print(f"Power: {result.power_mw:.0f} mW")
print(f"Efficiency: {result.tops_per_watt:.2f} TOPS/W")`,
                language: 'python',
            },
            {
                type: 'note',
                content: 'For hardware simulation without physical EdgeNPU, set ENPU_SIMULATION=1 environment variable before running.',
            },
        ],
    },

    comparison: {
        id: 'comparison',
        title: 'Performance Comparison',
        description: 'EdgeNPU performance benchmarks and comparisons',
        lastUpdated: '2026-01-06',
        blocks: [
            {
                type: 'heading',
                content: 'Benchmark Results',
                level: 2,
            },
            {
                type: 'paragraph',
                content: `Performance measured on common neural network models with INT8 quantization. 
                All measurements at 800 MHz clock frequency.`,
            },
            {
                type: 'table',
                content: JSON.stringify({
                    headers: ['Model', 'Input Size', 'Latency', 'Throughput', 'Power'],
                    rows: [
                        ['MobileNetV1', '224×224', '2.1 ms', '476 FPS', '320 mW'],
                        ['MobileNetV2', '224×224', '2.8 ms', '357 FPS', '340 mW'],
                        ['MobileNetV3-Small', '224×224', '1.5 ms', '667 FPS', '280 mW'],
                        ['EfficientNet-Lite0', '224×224', '3.2 ms', '312 FPS', '360 mW'],
                        ['ResNet-18', '224×224', '8.5 ms', '118 FPS', '420 mW'],
                        ['YOLO-Tiny', '416×416', '12.3 ms', '81 FPS', '450 mW'],
                        ['SSD-MobileNetV2', '300×300', '6.8 ms', '147 FPS', '380 mW'],
                    ],
                }),
            },
            {
                type: 'heading',
                content: 'Efficiency Comparison',
                level: 2,
            },
            {
                type: 'table',
                content: JSON.stringify({
                    headers: ['Platform', 'Peak TOPS', 'Power', 'TOPS/W', 'Process'],
                    rows: [
                        ['EdgeNPU', '0.51', '0.5W', '1.02', '28nm'],
                        ['Google Edge TPU', '4.0', '2.0W', '2.0', '—'],
                        ['Intel Movidius', '1.0', '1.5W', '0.67', '—'],
                        ['ARM Ethos-U55', '0.5', '0.5W', '1.0', '—'],
                        ['Cortex-A76 (CPU)', '0.02', '2.0W', '0.01', '7nm'],
                    ],
                }),
            },
            {
                type: 'note',
                content: 'Comparison data is approximate and based on published specifications. Actual performance varies by workload and implementation.',
            },
        ],
    },

    setup: {
        id: 'setup',
        title: 'Environment Setup',
        description: 'Complete environment setup guide for EdgeNPU development',
        lastUpdated: '2026-01-06',
        blocks: [
            {
                type: 'heading',
                content: 'System Requirements',
                level: 2,
            },
            {
                type: 'table',
                content: JSON.stringify({
                    headers: ['Component', 'Minimum', 'Recommended'],
                    rows: [
                        ['Operating System', 'Ubuntu 20.04 LTS', 'Ubuntu 22.04 LTS'],
                        ['RAM', '8 GB', '16 GB'],
                        ['Disk Space', '10 GB', '50 GB'],
                        ['Python', '3.8', '3.10+'],
                    ],
                }),
            },
            {
                type: 'heading',
                content: 'Software Installation',
                level: 2,
            },
            {
                type: 'code',
                content: `# Update system packages
sudo apt update && sudo apt upgrade -y

# Install build dependencies
sudo apt install -y build-essential git cmake python3 python3-pip python3-venv

# Install HDL simulation tools (for RTL development)
sudo apt install -y iverilog verilator gtkwave

# Create Python virtual environment
python3 -m venv ~/edgenpu-env
source ~/edgenpu-env/bin/activate

# Install EdgeNPU SDK
pip install --upgrade pip
pip install edgenpu edgenpu-compiler`,
                language: 'bash',
            },
            {
                type: 'heading',
                content: 'Clone Repository',
                level: 2,
            },
            {
                type: 'code',
                content: `# Clone EdgeNPU repository
git clone https://github.com/edgenpu/EdgeNPU.git
cd EdgeNPU

# Install Python dependencies
pip install -r requirements.txt

# Verify installation
make test`,
                language: 'bash',
            },
        ],
    },

    dataflow: {
        id: 'dataflow',
        title: 'Data Flow & Pipeline',
        description: 'Understanding the NPU data flow and execution pipeline',
        lastUpdated: '2026-01-06',
        blocks: [
            {
                type: 'heading',
                content: 'Execution Pipeline',
                level: 2,
            },
            {
                type: 'paragraph',
                content: `EdgeNPU implements a <strong>4-stage execution pipeline</strong> that overlaps 
                data movement with computation to maximize throughput.`,
            },
            {
                type: 'code',
                content: `Pipeline Stages:
┌─────────────────────────────────────────────────────────────────────┐
│ Stage 1: FETCH    │ Load instructions from instruction buffer      │
├───────────────────┼─────────────────────────────────────────────────┤
│ Stage 2: DECODE   │ Decode instruction, setup DMA descriptors      │
├───────────────────┼─────────────────────────────────────────────────┤
│ Stage 3: EXECUTE  │ PE array computation, activation, pooling      │
├───────────────────┼─────────────────────────────────────────────────┤
│ Stage 4: WRITEBACK│ Store results to activation buffer or memory   │
└───────────────────┴─────────────────────────────────────────────────┘

Timeline (overlapped execution):
Layer N:    |--FETCH--|--DECODE--|--EXECUTE--|--WRITEBACK--|
Layer N+1:            |--FETCH--|--DECODE--|--EXECUTE--|--WRITEBACK--|
Layer N+2:                      |--FETCH--|--DECODE--|--EXECUTE--|...`,
                language: 'text',
            },
            {
                type: 'heading',
                content: 'Convolution Mapping',
                level: 2,
            },
            {
                type: 'paragraph',
                content: `Convolution operations are mapped to the systolic array using <strong>output-stationary 
                tiling</strong>. Large convolutions are broken into tiles that fit in on-chip memory.`,
            },
            {
                type: 'code',
                content: `// Convolution tiling strategy
for (oc_tile = 0; oc_tile < output_channels; oc_tile += 16) {
    for (ic_tile = 0; ic_tile < input_channels; ic_tile += 16) {
        // Load weight tile [16 x 16 x K x K]
        DMA.load(weights[oc_tile:oc_tile+16, ic_tile:ic_tile+16, :, :])
        
        for (oh_tile = 0; oh_tile < output_height; oh_tile += TILE_H) {
            for (ow_tile = 0; ow_tile < output_width; ow_tile += TILE_W) {
                // Load input activation tile
                DMA.load(input[ic_tile:ic_tile+16, oh_tile:oh_tile+TILE_H, ...])
                
                // Compute on PE array
                PE_Array.compute()
                
                // Accumulate partial sums
                if (ic_tile > 0)
                    output += partial_sum
            }
        }
    }
}`,
                language: 'text',
            },
        ],
    },

    'axi-interface': {
        id: 'axi-interface',
        title: 'AXI Interface',
        description: 'AXI4 and AXI4-Lite interface specifications',
        lastUpdated: '2026-01-06',
        blocks: [
            {
                type: 'heading',
                content: 'AXI4 Master Interface',
                level: 2,
            },
            {
                type: 'paragraph',
                content: `The AXI4 master interface provides high-bandwidth access to external memory 
                for DMA transfers. It supports burst transactions up to 256 beats.`,
            },
            {
                type: 'table',
                content: JSON.stringify({
                    headers: ['Signal', 'Width', 'Direction', 'Description'],
                    rows: [
                        ['m_axi_awaddr', '40', 'Output', 'Write address'],
                        ['m_axi_awlen', '8', 'Output', 'Burst length (0-255)'],
                        ['m_axi_awsize', '3', 'Output', 'Burst size (4=16B)'],
                        ['m_axi_awburst', '2', 'Output', 'Burst type (INCR)'],
                        ['m_axi_wdata', '128', 'Output', 'Write data'],
                        ['m_axi_wstrb', '16', 'Output', 'Write strobes'],
                        ['m_axi_araddr', '40', 'Output', 'Read address'],
                        ['m_axi_rdata', '128', 'Input', 'Read data'],
                    ],
                }),
            },
            {
                type: 'heading',
                content: 'AXI4-Lite Slave Interface',
                level: 2,
            },
            {
                type: 'paragraph',
                content: `The AXI4-Lite slave interface provides register access for configuration 
                and status monitoring. All registers are 32-bit aligned.`,
            },
            {
                type: 'table',
                content: JSON.stringify({
                    headers: ['Signal', 'Width', 'Direction', 'Description'],
                    rows: [
                        ['s_axil_awaddr', '32', 'Input', 'Write address'],
                        ['s_axil_wdata', '32', 'Input', 'Write data'],
                        ['s_axil_wstrb', '4', 'Input', 'Write strobes'],
                        ['s_axil_araddr', '32', 'Input', 'Read address'],
                        ['s_axil_rdata', '32', 'Output', 'Read data'],
                    ],
                }),
            },
        ],
    },

    'programming-overview': {
        id: 'programming-overview',
        title: 'Programming Overview',
        description: 'Introduction to EdgeNPU programming model',
        lastUpdated: '2026-01-06',
        blocks: [
            {
                type: 'heading',
                content: 'Programming Model',
                level: 2,
            },
            {
                type: 'paragraph',
                content: `EdgeNPU supports two programming approaches: <strong>High-level SDK</strong> for 
                application developers and <strong>Low-level register access</strong> for system integrators.`,
            },
            {
                type: 'table',
                content: JSON.stringify({
                    headers: ['Approach', 'Use Case', 'Complexity'],
                    rows: [
                        ['Python SDK', 'Rapid prototyping, ML research', 'Low'],
                        ['C/C++ Runtime', 'Production deployment, embedded', 'Medium'],
                        ['Register Access', 'Custom drivers, bare-metal', 'High'],
                    ],
                }),
            },
            {
                type: 'heading',
                content: 'Workflow Overview',
                level: 2,
            },
            {
                type: 'list',
                content: '',
                items: [
                    '<strong>1. Model Preparation</strong> — Train model in PyTorch/TensorFlow, export to ONNX/TFLite',
                    '<strong>2. Quantization</strong> — Convert FP32 weights to INT8 using post-training or QAT',
                    '<strong>3. Compilation</strong> — Use EdgeNPU compiler to generate optimized binary',
                    '<strong>4. Deployment</strong> — Load model via SDK and run inference',
                ],
            },
        ],
    },

    quantization: {
        id: 'quantization',
        title: 'Quantization Guide',
        description: 'Guide to model quantization for EdgeNPU',
        lastUpdated: '2026-01-06',
        blocks: [
            {
                type: 'heading',
                content: 'Quantization Overview',
                level: 2,
            },
            {
                type: 'paragraph',
                content: `EdgeNPU achieves peak performance with <strong>INT8 quantized models</strong>. 
                Quantization reduces model size by 4× and increases throughput while maintaining accuracy.`,
            },
            {
                type: 'table',
                content: JSON.stringify({
                    headers: ['Method', 'Accuracy Impact', 'Effort', 'Recommended For'],
                    rows: [
                        ['Post-Training (PTQ)', 'Low-Medium', 'Low', 'Most models'],
                        ['Quantization-Aware Training (QAT)', 'Minimal', 'High', 'Accuracy-critical'],
                        ['Dynamic Quantization', 'Low', 'Very Low', 'Quick testing'],
                    ],
                }),
            },
            {
                type: 'heading',
                content: 'Quantization Formula',
                level: 2,
            },
            {
                type: 'code',
                content: `# Quantization: FP32 → INT8
q = round(x / scale) + zero_point

# Dequantization: INT8 → FP32  
x = (q - zero_point) × scale

# Per-tensor quantization
scale = (max_val - min_val) / 255
zero_point = round(-min_val / scale)`,
                language: 'python',
            },
            {
                type: 'heading',
                content: 'Best Practices',
                level: 2,
            },
            {
                type: 'list',
                content: '',
                items: [
                    'Use representative calibration dataset (100-1000 samples)',
                    'Prefer per-channel quantization for convolution weights',
                    'Keep first and last layers in higher precision if needed',
                    'Monitor accuracy on validation set during quantization',
                ],
            },
        ],
    },

    'sdk-overview': {
        id: 'sdk-overview',
        title: 'SDK Overview',
        description: 'Overview of EdgeNPU Software Development Kit',
        lastUpdated: '2026-01-06',
        blocks: [
            {
                type: 'heading',
                content: 'SDK Components',
                level: 2,
            },
            {
                type: 'table',
                content: JSON.stringify({
                    headers: ['Component', 'Description', 'Language'],
                    rows: [
                        ['edgenpu-runtime', 'Core inference runtime library', 'C/C++'],
                        ['edgenpu-python', 'Python bindings and high-level API', 'Python'],
                        ['edgenpu-compiler', 'Model compiler and optimizer', 'Python'],
                        ['edgenpu-profiler', 'Performance analysis tools', 'Python'],
                    ],
                }),
            },
            {
                type: 'heading',
                content: 'Supported Frameworks',
                level: 2,
            },
            {
                type: 'list',
                content: '',
                items: [
                    '<strong>ONNX</strong> — Primary format, best optimization support',
                    '<strong>TensorFlow Lite</strong> — Direct import, quantized models',
                    '<strong>PyTorch</strong> — Via ONNX export',
                ],
            },
        ],
    },

    compiler: {
        id: 'compiler',
        title: 'Model Compiler',
        description: 'EdgeNPU model compiler documentation',
        lastUpdated: '2026-01-06',
        blocks: [
            {
                type: 'heading',
                content: 'Compiler Overview',
                level: 2,
            },
            {
                type: 'paragraph',
                content: `The EdgeNPU compiler transforms neural network models into optimized instruction 
                sequences for the NPU hardware. It performs graph optimization, layer fusion, and memory planning.`,
            },
            {
                type: 'heading',
                content: 'Usage',
                level: 2,
            },
            {
                type: 'code',
                content: `# Basic compilation
edgenpu-compile model.onnx -o model.enpu

# With quantization
edgenpu-compile model.onnx -o model.enpu --quantize int8 --calibration-data calib.npz

# With optimization level
edgenpu-compile model.onnx -o model.enpu -O3`,
                language: 'bash',
            },
            {
                type: 'heading',
                content: 'Optimization Passes',
                level: 2,
            },
            {
                type: 'list',
                content: '',
                items: [
                    '<strong>Layer Fusion</strong> — Conv+BN+ReLU merged into single operation',
                    '<strong>Constant Folding</strong> — Pre-compute static expressions',
                    '<strong>Memory Planning</strong> — Optimize buffer allocation',
                    '<strong>Tiling</strong> — Split large tensors to fit on-chip memory',
                ],
            },
        ],
    },

    'first-inference': {
        id: 'first-inference',
        title: 'Running First Inference',
        description: 'Step-by-step guide to run your first inference',
        lastUpdated: '2026-01-06',
        blocks: [
            {
                type: 'heading',
                content: 'Prerequisites',
                level: 2,
            },
            {
                type: 'list',
                content: '',
                items: [
                    'EdgeNPU SDK installed',
                    'Sample model downloaded',
                    'Test image prepared',
                ],
            },
            {
                type: 'heading',
                content: 'Python Example',
                level: 2,
            },
            {
                type: 'code',
                content: `import edgenpu as enpu
import numpy as np
from PIL import Image

# Initialize
enpu.init()

# Load model
model = enpu.load_model("mobilenet_v2_int8.enpu")

# Prepare input
img = Image.open("test.jpg").resize((224, 224))
input_data = np.array(img, dtype=np.int8).reshape(1, 224, 224, 3)

# Run inference
output = model(input_data)

# Get result
predicted_class = np.argmax(output)
print(f"Predicted: class {predicted_class}")

# Cleanup
enpu.deinit()`,
                language: 'python',
            },
        ],
    },

    examples: {
        id: 'examples',
        title: 'Example Applications',
        description: 'Sample applications and use cases',
        lastUpdated: '2026-01-06',
        blocks: [
            {
                type: 'heading',
                content: 'Available Examples',
                level: 2,
            },
            {
                type: 'table',
                content: JSON.stringify({
                    headers: ['Example', 'Model', 'Description'],
                    rows: [
                        ['image_classification', 'MobileNetV2', 'Classify images into 1000 categories'],
                        ['object_detection', 'YOLO-Tiny', 'Detect objects with bounding boxes'],
                        ['face_detection', 'RetinaFace', 'Detect faces in images'],
                        ['pose_estimation', 'MoveNet', 'Human pose keypoint detection'],
                    ],
                }),
            },
            {
                type: 'heading',
                content: 'Running Examples',
                level: 2,
            },
            {
                type: 'code',
                content: `# Clone examples repository
git clone https://github.com/edgenpu/examples.git
cd examples

# Run image classification
python image_classification/run.py --image cat.jpg

# Run object detection
python object_detection/run.py --image street.jpg`,
                language: 'bash',
            },
        ],
    },

    'clocking-reset': {
        id: 'clocking-reset',
        title: 'Clocking & Reset',
        description: 'Clock and reset requirements for EdgeNPU',
        lastUpdated: '2026-01-06',
        blocks: [
            {
                type: 'heading',
                content: 'Clock Requirements',
                level: 2,
            },
            {
                type: 'table',
                content: JSON.stringify({
                    headers: ['Clock', 'Frequency', 'Description'],
                    rows: [
                        ['clk', '100-1000 MHz', 'Main NPU clock'],
                        ['axi_clk', 'Same as clk', 'AXI interface clock (synchronous)'],
                    ],
                }),
            },
            {
                type: 'heading',
                content: 'Reset Requirements',
                level: 2,
            },
            {
                type: 'list',
                content: '',
                items: [
                    '<strong>rst_n</strong> — Active-low asynchronous reset',
                    'Assert for minimum 10 clock cycles',
                    'Synchronize release to clock domain',
                ],
            },
        ],
    },

    verification: {
        id: 'verification',
        title: 'Verification Guide',
        description: 'Verification methodology for EdgeNPU integration',
        lastUpdated: '2026-01-06',
        blocks: [
            {
                type: 'heading',
                content: 'Verification Environment',
                level: 2,
            },
            {
                type: 'paragraph',
                content: `EdgeNPU includes a comprehensive UVM-based verification environment for 
                integration testing and validation.`,
            },
            {
                type: 'heading',
                content: 'Test Categories',
                level: 2,
            },
            {
                type: 'table',
                content: JSON.stringify({
                    headers: ['Category', 'Tests', 'Coverage'],
                    rows: [
                        ['Unit Tests', 'PE, Activation, Pooling', 'Functional'],
                        ['Integration Tests', 'PE Array, DMA, Controller', 'Interface'],
                        ['System Tests', 'Full inference flows', 'End-to-end'],
                        ['Regression Tests', 'Known model benchmarks', 'Accuracy'],
                    ],
                }),
            },
            {
                type: 'heading',
                content: 'Running Tests',
                level: 2,
            },
            {
                type: 'code',
                content: `# Run all unit tests
make test_unit

# Run PE array tests
make test_pe_array

# Run full system test
make test_system`,
                language: 'bash',
            },
        ],
    },
};


export const getContent = (pageId: string): PageContent => {
    return contentData[pageId] || {
        id: pageId,
        title: 'Page Not Found',
        description: 'The requested documentation page does not exist.',
        lastUpdated: '—',
        blocks: [
            {
                type: 'paragraph',
                content: 'Please select a topic from the navigation menu.',
            },
        ],
    };
};

export default contentData;
