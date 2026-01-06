# EdgeNPU Architecture Diagrams (Mermaid)

Các diagram dưới đây có thể paste trực tiếp vào https://mermaid.live/ để render.

---

## 1. High-Level System Architecture

```mermaid
flowchart TB
    subgraph HOST["Host System"]
        CPU["CPU/SoC"]
        DDR["DDR Memory"]
    end
    
    subgraph EDGENPU["EdgeNPU"]
        subgraph INTERFACE["Interface Layer"]
            AXI4M["AXI4 Master<br/>128-bit Data"]
            AXI4LS["AXI4-Lite Slave<br/>32-bit Config"]
        end
        
        subgraph CORE["NPU Core"]
            CTRL["Controller<br/>FSM + Scheduler"]
            PE_ARRAY["PE Array<br/>16×16 Systolic"]
            ACT["Activation Unit<br/>ReLU/Sigmoid/Tanh"]
            POOL["Pooling Unit<br/>Max/Avg/Global"]
        end
        
        subgraph MEMORY["Memory Subsystem"]
            WBUF["Weight Buffer<br/>256KB"]
            ABUF["Activation Buffer<br/>256KB"]
            DMA["DMA Engine<br/>4 Channels"]
        end
        
        subgraph QUANT["Quantization"]
            Q["Quantizer<br/>INT8"]
            DQ["Dequantizer"]
        end
    end
    
    CPU <-->|"Config/Status"| AXI4LS
    DDR <-->|"Data Transfer"| AXI4M
    
    AXI4M <--> DMA
    AXI4LS <--> CTRL
    
    DMA <--> WBUF
    DMA <--> ABUF
    
    CTRL --> PE_ARRAY
    CTRL --> ACT
    CTRL --> POOL
    
    WBUF --> PE_ARRAY
    ABUF <--> PE_ARRAY
    
    PE_ARRAY --> Q
    Q --> ACT
    ACT --> POOL
    POOL --> DQ
    DQ --> ABUF
    
    style EDGENPU fill:#e3f2fd
    style CORE fill:#bbdefb
    style MEMORY fill:#c8e6c9
    style QUANT fill:#fff9c4
```

---

## 2. PE Array (Systolic Array) Architecture

```mermaid
flowchart LR
    subgraph INPUT["Input"]
        W["Weights<br/>(from Weight Buffer)"]
        A["Activations<br/>(from Act Buffer)"]
    end
    
    subgraph SYSTOLIC["16×16 Systolic Array"]
        direction TB
        subgraph ROW0["Row 0"]
            PE00["PE<br/>0,0"] --> PE01["PE<br/>0,1"] --> PE02["PE<br/>0,2"] --> PE0N["..."] --> PE0F["PE<br/>0,15"]
        end
        subgraph ROW1["Row 1"]
            PE10["PE<br/>1,0"] --> PE11["PE<br/>1,1"] --> PE12["PE<br/>1,2"] --> PE1N["..."] --> PE1F["PE<br/>1,15"]
        end
        subgraph ROWN["..."]
            PEN0["..."] --> PEN1["..."] --> PEN2["..."] --> PENN["..."] --> PENF["..."]
        end
        subgraph ROWF["Row 15"]
            PEF0["PE<br/>15,0"] --> PEF1["PE<br/>15,1"] --> PEF2["PE<br/>15,2"] --> PEFN["..."] --> PEFF["PE<br/>15,15"]
        end
    end
    
    W -->|"Vertical Load"| PE00
    W -->|"Vertical Load"| PE10
    W -->|"Vertical Load"| PEN0
    W -->|"Vertical Load"| PEF0
    
    A -->|"Horizontal Flow"| PE00
    A -->|"Horizontal Flow"| PE10
    A -->|"Horizontal Flow"| PEN0
    A -->|"Horizontal Flow"| PEF0
    
    PE0F --> ACC0["Accumulator"]
    PE1F --> ACC1["Accumulator"]
    PENF --> ACCN["..."]
    PEFF --> ACCF["Accumulator"]
    
    style SYSTOLIC fill:#e8f5e9
```

---

## 3. Processing Element (PE) Internal Structure

```mermaid
flowchart TB
    subgraph PE["Processing Element"]
        subgraph INPUTS["Inputs"]
            DIN["data_in<br/>(8-bit signed)"]
            WIN["weight_in<br/>(8-bit signed)"]
        end
        
        WREG["Weight<br/>Register"]
        
        subgraph MAC["MAC Unit"]
            MUL["Multiplier<br/>8×8 → 16-bit"]
            ADD["Adder<br/>32-bit"]
        end
        
        ACC["Accumulator<br/>32-bit"]
        
        subgraph OUTPUTS["Outputs"]
            DOUT["data_out<br/>(to next PE)"]
            AOUT["acc_out<br/>(32-bit result)"]
        end
        
        subgraph CTRL["Control"]
            EN["enable"]
            CLR["clear_acc"]
            LD["load_weight"]
        end
    end
    
    WIN -->|"load_weight"| WREG
    DIN --> MUL
    WREG --> MUL
    MUL --> ADD
    ACC --> ADD
    ADD -->|"enable"| ACC
    
    DIN -->|"Systolic Pass"| DOUT
    ACC --> AOUT
    
    CLR -->|"Reset"| ACC
    
    style PE fill:#fff3e0
    style MAC fill:#ffe0b2
```

---

## 4. Data Flow Pipeline

```mermaid
flowchart LR
    subgraph STAGE1["Stage 1: Load"]
        DMA1["DMA<br/>Load Weights"]
        DMA2["DMA<br/>Load Activations"]
    end
    
    subgraph STAGE2["Stage 2: Compute"]
        GEMM["Matrix Multiply<br/>PE Array"]
    end
    
    subgraph STAGE3["Stage 3: Post-Process"]
        QUANT["Quantize<br/>INT8"]
        ACT["Activation<br/>Function"]
        POOL["Pooling<br/>(Optional)"]
    end
    
    subgraph STAGE4["Stage 4: Store"]
        DEQUANT["Dequantize"]
        STORE["DMA<br/>Store Results"]
    end
    
    DMA1 --> GEMM
    DMA2 --> GEMM
    GEMM --> QUANT
    QUANT --> ACT
    ACT --> POOL
    POOL --> DEQUANT
    DEQUANT --> STORE
    
    style STAGE1 fill:#e3f2fd
    style STAGE2 fill:#c8e6c9
    style STAGE3 fill:#fff9c4
    style STAGE4 fill:#f3e5f5
```

---

## 5. Controller State Machine

```mermaid
stateDiagram-v2
    [*] --> IDLE
    
    IDLE --> FETCH: start & enable
    FETCH --> DECODE: inst_valid
    
    DECODE --> LOAD_WEIGHT: CONV/FC
    DECODE --> LOAD_ACT: POOL/ACT/LOAD
    DECODE --> STORE: STORE
    DECODE --> DONE: SYNC
    DECODE --> ERROR: Invalid Op
    DECODE --> FETCH: NOP
    
    LOAD_WEIGHT --> LOAD_ACT: weight_rows >= 16
    LOAD_ACT --> COMPUTE
    
    COMPUTE --> ACCUMULATE: compute_done
    
    ACCUMULATE --> POOL: pool_op
    ACCUMULATE --> ACTIVATE: other_op
    
    POOL --> STORE: pool_done
    ACTIVATE --> STORE
    
    STORE --> FETCH
    
    DONE --> IDLE
    ERROR --> IDLE
    
    note right of COMPUTE
        PE Array executes
        matrix multiplication
    end note
    
    note right of ACCUMULATE
        Results accumulated
        in 32-bit registers
    end note
```

---

## 6. Memory Architecture

```mermaid
flowchart TB
    subgraph EXTERNAL["External Memory (DDR)"]
        DDR["DDR4/LPDDR4<br/>Model Weights + I/O Data"]
    end
    
    subgraph DMA_ENGINE["DMA Engine"]
        CH0["Channel 0<br/>Weight Load"]
        CH1["Channel 1<br/>Activation Load"]
        CH2["Channel 2<br/>Output Store"]
        CH3["Channel 3<br/>Instruction Fetch"]
    end
    
    subgraph ONCHIP["On-Chip Memory (512KB)"]
        subgraph WBUF["Weight Buffer"]
            WB["256KB SRAM<br/>Single Port"]
        end
        subgraph ABUF["Activation Buffer"]
            AB["256KB SRAM<br/>Dual Port"]
        end
        subgraph IBUF["Instruction Buffer"]
            IB["16KB<br/>Instruction Cache"]
        end
    end
    
    subgraph COMPUTE["Compute Units"]
        PE["PE Array"]
        POST["Post-Processing"]
    end
    
    DDR <-->|"AXI4 128-bit"| CH0
    DDR <-->|"AXI4 128-bit"| CH1
    DDR <-->|"AXI4 128-bit"| CH2
    DDR <-->|"AXI4 128-bit"| CH3
    
    CH0 --> WB
    CH1 --> AB
    CH2 <-- AB
    CH3 --> IB
    
    WB --> PE
    AB <--> PE
    PE --> POST
    POST --> AB
    
    style ONCHIP fill:#e8f5e9
    style DMA_ENGINE fill:#e3f2fd
```

---

## 7. Activation Functions Supported

```mermaid
flowchart LR
    INPUT["Input<br/>INT8"] --> MUX
    
    subgraph ACTIVATIONS["Activation Functions"]
        NONE["None<br/>(Pass-through)"]
        RELU["ReLU<br/>max(0,x)"]
        RELU6["ReLU6<br/>min(max(0,x),6)"]
        SIGMOID["Sigmoid<br/>1/(1+e^-x)"]
        TANH["Tanh<br/>(e^x-e^-x)/(e^x+e^-x)"]
        SWISH["Swish<br/>x·sigmoid(x)"]
        GELU["GELU<br/>x·Φ(x)"]
    end
    
    MUX --> NONE
    MUX --> RELU
    MUX --> RELU6
    MUX --> SIGMOID
    MUX --> TANH
    MUX --> SWISH
    MUX --> GELU
    
    NONE --> OUTPUT
    RELU --> OUTPUT
    RELU6 --> OUTPUT
    SIGMOID --> OUTPUT
    TANH --> OUTPUT
    SWISH --> OUTPUT
    GELU --> OUTPUT
    
    OUTPUT["Output<br/>INT8"]
    
    style ACTIVATIONS fill:#fff9c4
```

---

## 8. Quantization Pipeline

```mermaid
flowchart LR
    subgraph FP_DOMAIN["Floating Point Domain"]
        FP32["FP32 Input<br/>(from training)"]
    end
    
    subgraph QUANTIZE["Quantization"]
        SCALE1["Scale<br/>(per-channel)"]
        ZP1["Zero Point"]
        SAT1["Saturate<br/>[-128, 127]"]
    end
    
    subgraph INT_DOMAIN["Integer Domain (NPU)"]
        INT8["INT8<br/>Compute"]
        PE_COMP["PE Array<br/>MAC Operations"]
        ACC32["32-bit<br/>Accumulator"]
    end
    
    subgraph DEQUANTIZE["Dequantization"]
        ZP2["Subtract<br/>Zero Point"]
        SCALE2["Multiply<br/>Scale"]
    end
    
    subgraph OUTPUT_DOMAIN["Output"]
        OUT["Output<br/>Tensor"]
    end
    
    FP32 --> SCALE1
    SCALE1 --> ZP1
    ZP1 --> SAT1
    SAT1 --> INT8
    
    INT8 --> PE_COMP
    PE_COMP --> ACC32
    
    ACC32 --> ZP2
    ZP2 --> SCALE2
    SCALE2 --> OUT
    
    style FP_DOMAIN fill:#ffcdd2
    style INT_DOMAIN fill:#c8e6c9
    style OUTPUT_DOMAIN fill:#bbdefb
```

---

## 9. AXI Interface Architecture

```mermaid
flowchart TB
    subgraph HOST["Host/SoC"]
        CPU["CPU"]
        MEM["Memory Controller"]
    end
    
    subgraph NPU_IF["EdgeNPU Interfaces"]
        subgraph AXI4_MASTER["AXI4 Master (Data Path)"]
            AW["Write Address<br/>awaddr[39:0]"]
            W["Write Data<br/>wdata[127:0]"]
            B["Write Response"]
            AR["Read Address<br/>araddr[39:0]"]
            R["Read Data<br/>rdata[127:0]"]
        end
        
        subgraph AXI4L_SLAVE["AXI4-Lite Slave (Config)"]
            AWL["Write Address<br/>awaddr[31:0]"]
            WL["Write Data<br/>wdata[31:0]"]
            BL["Write Response"]
            ARL["Read Address"]
            RL["Read Data"]
        end
        
        IRQ["Interrupt<br/>irq"]
    end
    
    CPU <-->|"Register Access"| AXI4L_SLAVE
    MEM <-->|"Bulk Data"| AXI4_MASTER
    IRQ --> CPU
    
    style AXI4_MASTER fill:#e3f2fd
    style AXI4L_SLAVE fill:#fff9c4
```

---

## 10. Supported Operations

```mermaid
mindmap
  root((EdgeNPU<br/>Operations))
    Convolution
      1x1 Conv
      3x3 Conv
      5x5 Conv
      7x7 Conv
      Depthwise
      Dilated
    Fully Connected
      Matrix Multiply
      GEMM
    Pooling
      Max Pool
      Avg Pool
      Global Avg
    Activation
      ReLU
      ReLU6
      Sigmoid
      Tanh
      Swish
      GELU
    Element-wise
      Add
      Multiply
      Concat
      Split
    Data Movement
      Load
      Store
      Sync
```

