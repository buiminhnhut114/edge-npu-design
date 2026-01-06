/**
 * EdgeNPU Firmware - Instruction Definitions
 * NPU instruction set architecture
 * 
 * Copyright (c) 2024 EdgeNPU Project
 */

#ifndef NPU_FW_INST_H
#define NPU_FW_INST_H

#include <stdint.h>

/* ==========================================================================
 * Instruction Format (64-bit)
 * 
 * [63:56] - Opcode (8 bits)
 * [55:48] - Flags/Modifiers (8 bits)
 * [47:0]  - Operands (48 bits, format depends on opcode)
 * ========================================================================== */

/* ==========================================================================
 * Opcodes
 * ========================================================================== */

/* Control Instructions (0x00 - 0x0F) */
#define OP_NOP              0x00    /* No operation */
#define OP_HALT             0x01    /* Halt execution */
#define OP_SYNC             0x02    /* Synchronization barrier */
#define OP_WAIT_DMA         0x03    /* Wait for DMA completion */
#define OP_WAIT_PE          0x04    /* Wait for PE completion */
#define OP_IRQ              0x05    /* Generate interrupt */
#define OP_LOOP_START       0x06    /* Start loop */
#define OP_LOOP_END         0x07    /* End loop */
#define OP_BRANCH           0x08    /* Conditional branch */
#define OP_JUMP             0x09    /* Unconditional jump */

/* DMA Instructions (0x10 - 0x1F) */
#define OP_DMA_LOAD_W       0x10    /* Load weights from memory */
#define OP_DMA_LOAD_A       0x11    /* Load activations from memory */
#define OP_DMA_STORE        0x12    /* Store results to memory */
#define OP_DMA_COPY         0x13    /* Memory to memory copy */
#define OP_DMA_FILL         0x14    /* Fill memory with value */
#define OP_DMA_2D_LOAD      0x15    /* 2D strided load */
#define OP_DMA_2D_STORE     0x16    /* 2D strided store */

/* Compute Instructions (0x20 - 0x3F) */
#define OP_CONV             0x20    /* Convolution */
#define OP_DWCONV           0x21    /* Depthwise convolution */
#define OP_GEMM             0x22    /* General matrix multiply */
#define OP_FC               0x23    /* Fully connected */
#define OP_MATMUL           0x24    /* Matrix multiplication */
#define OP_MAC              0x25    /* Multiply-accumulate */
#define OP_CLEAR_ACC        0x26    /* Clear accumulators */
#define OP_LOAD_WEIGHT      0x27    /* Load weights to PE array */
#define OP_COMPUTE          0x28    /* Execute PE computation */
#define OP_DRAIN            0x29    /* Drain PE results */

/* Activation Instructions (0x40 - 0x4F) */
#define OP_RELU             0x40    /* ReLU activation */
#define OP_RELU6            0x41    /* ReLU6 activation */
#define OP_SIGMOID          0x42    /* Sigmoid activation */
#define OP_TANH             0x43    /* Tanh activation */
#define OP_LEAKY_RELU       0x44    /* Leaky ReLU */
#define OP_SWISH            0x45    /* Swish activation */
#define OP_GELU             0x46    /* GELU activation */

/* Pooling Instructions (0x50 - 0x5F) */
#define OP_MAXPOOL          0x50    /* Max pooling */
#define OP_AVGPOOL          0x51    /* Average pooling */
#define OP_GLOBAL_AVGPOOL   0x52    /* Global average pooling */
#define OP_GLOBAL_MAXPOOL   0x53    /* Global max pooling */

/* Element-wise Instructions (0x60 - 0x6F) */
#define OP_ADD              0x60    /* Element-wise add */
#define OP_SUB              0x61    /* Element-wise subtract */
#define OP_MUL              0x62    /* Element-wise multiply */
#define OP_DIV              0x63    /* Element-wise divide */
#define OP_MAX              0x64    /* Element-wise max */
#define OP_MIN              0x65    /* Element-wise min */
#define OP_ABS              0x66    /* Element-wise absolute */

/* Normalization Instructions (0x70 - 0x7F) */
#define OP_BATCHNORM        0x70    /* Batch normalization */
#define OP_LAYERNORM        0x71    /* Layer normalization */
#define OP_SOFTMAX          0x72    /* Softmax */

/* Quantization Instructions (0x80 - 0x8F) */
#define OP_QUANTIZE         0x80    /* Quantize to int8 */
#define OP_DEQUANTIZE       0x81    /* Dequantize from int8 */
#define OP_REQUANTIZE       0x82    /* Requantize with new scale */
#define OP_SCALE            0x83    /* Apply scale factor */
#define OP_BIAS_ADD         0x84    /* Add bias */

/* Reshape Instructions (0x90 - 0x9F) */
#define OP_RESHAPE          0x90    /* Reshape tensor */
#define OP_TRANSPOSE        0x91    /* Transpose tensor */
#define OP_CONCAT           0x92    /* Concatenate tensors */
#define OP_SPLIT            0x93    /* Split tensor */
#define OP_PAD              0x94    /* Pad tensor */

/* ==========================================================================
 * Instruction Flags
 * ========================================================================== */

#define FLAG_LAST           (1 << 0)    /* Last instruction in sequence */
#define FLAG_IRQ            (1 << 1)    /* Generate IRQ on completion */
#define FLAG_CHAIN          (1 << 2)    /* Chain with next instruction */
#define FLAG_ASYNC          (1 << 3)    /* Asynchronous execution */
#define FLAG_RELU           (1 << 4)    /* Apply ReLU after operation */
#define FLAG_BIAS           (1 << 5)    /* Add bias after operation */
#define FLAG_QUANT          (1 << 6)    /* Apply quantization */
#define FLAG_ACCUM          (1 << 7)    /* Accumulate result */

/* ==========================================================================
 * Instruction Structures
 * ========================================================================== */

/* Generic instruction */
typedef union {
    uint64_t raw;
    struct {
        uint64_t operands : 48;
        uint64_t flags    : 8;
        uint64_t opcode   : 8;
    } __attribute__((packed));
} npu_inst_t;

/* DMA instruction operands */
typedef struct {
    uint32_t src_addr;      /* Source address (24 bits) */
    uint32_t dst_addr;      /* Destination address (24 bits) */
    uint32_t length;        /* Transfer length */
} dma_operands_t;

/* Convolution instruction operands */
typedef struct {
    uint16_t in_channels;
    uint16_t out_channels;
    uint8_t  kernel_h;
    uint8_t  kernel_w;
    uint8_t  stride_h;
    uint8_t  stride_w;
    uint8_t  pad_h;
    uint8_t  pad_w;
    uint8_t  dilation_h;
    uint8_t  dilation_w;
} conv_operands_t;

/* Pooling instruction operands */
typedef struct {
    uint8_t  kernel_h;
    uint8_t  kernel_w;
    uint8_t  stride_h;
    uint8_t  stride_w;
    uint16_t in_h;
    uint16_t in_w;
} pool_operands_t;

/* Loop instruction operands */
typedef struct {
    uint16_t count;         /* Loop iteration count */
    uint16_t target;        /* Target instruction index */
} loop_operands_t;

/* ==========================================================================
 * Instruction Builder Macros
 * ========================================================================== */

#define MAKE_INST(op, fl, ops) \
    ((uint64_t)(op) << 56 | (uint64_t)(fl) << 48 | ((uint64_t)(ops) & 0xFFFFFFFFFFFFULL))

#define INST_NOP() \
    MAKE_INST(OP_NOP, 0, 0)

#define INST_HALT() \
    MAKE_INST(OP_HALT, FLAG_LAST, 0)

#define INST_SYNC() \
    MAKE_INST(OP_SYNC, 0, 0)

#define INST_WAIT_DMA() \
    MAKE_INST(OP_WAIT_DMA, 0, 0)

#define INST_DMA_LOAD_W(src, dst, len) \
    MAKE_INST(OP_DMA_LOAD_W, 0, ((uint64_t)(src) | ((uint64_t)(dst) << 24) | ((uint64_t)(len) << 40)))

#define INST_DMA_LOAD_A(src, dst, len) \
    MAKE_INST(OP_DMA_LOAD_A, 0, ((uint64_t)(src) | ((uint64_t)(dst) << 24) | ((uint64_t)(len) << 40)))

#define INST_DMA_STORE(src, dst, len) \
    MAKE_INST(OP_DMA_STORE, 0, ((uint64_t)(src) | ((uint64_t)(dst) << 24) | ((uint64_t)(len) << 40)))

#define INST_CLEAR_ACC() \
    MAKE_INST(OP_CLEAR_ACC, 0, 0)

#define INST_LOAD_WEIGHT(addr, count) \
    MAKE_INST(OP_LOAD_WEIGHT, 0, ((uint64_t)(addr) | ((uint64_t)(count) << 24)))

#define INST_COMPUTE(flags) \
    MAKE_INST(OP_COMPUTE, flags, 0)

#define INST_DRAIN(addr) \
    MAKE_INST(OP_DRAIN, 0, (uint64_t)(addr))

#define INST_RELU() \
    MAKE_INST(OP_RELU, 0, 0)

#define INST_MAXPOOL(kh, kw, sh, sw) \
    MAKE_INST(OP_MAXPOOL, 0, ((uint64_t)(kh) | ((uint64_t)(kw) << 8) | ((uint64_t)(sh) << 16) | ((uint64_t)(sw) << 24)))

#define INST_LOOP_START(count) \
    MAKE_INST(OP_LOOP_START, 0, (uint64_t)(count))

#define INST_LOOP_END(target) \
    MAKE_INST(OP_LOOP_END, 0, (uint64_t)(target))

/* ==========================================================================
 * Instruction Decoder Helpers
 * ========================================================================== */

static inline uint8_t inst_get_opcode(npu_inst_t inst) {
    return inst.opcode;
}

static inline uint8_t inst_get_flags(npu_inst_t inst) {
    return inst.flags;
}

static inline uint64_t inst_get_operands(npu_inst_t inst) {
    return inst.operands;
}

static inline int inst_is_last(npu_inst_t inst) {
    return (inst.flags & FLAG_LAST) != 0;
}

static inline int inst_needs_irq(npu_inst_t inst) {
    return (inst.flags & FLAG_IRQ) != 0;
}

#endif /* NPU_FW_INST_H */
