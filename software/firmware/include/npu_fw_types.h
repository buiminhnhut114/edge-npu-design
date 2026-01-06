/**
 * EdgeNPU Firmware - Type Definitions
 * Common types and structures for firmware
 * 
 * Copyright (c) 2024 EdgeNPU Project
 */

#ifndef NPU_FW_TYPES_H
#define NPU_FW_TYPES_H

#include <stdint.h>
#include <stdbool.h>

/* ==========================================================================
 * Status Codes
 * ========================================================================== */

typedef enum {
    FW_OK                   = 0,
    FW_ERROR                = -1,
    FW_ERROR_INVALID_PARAM  = -2,
    FW_ERROR_TIMEOUT        = -3,
    FW_ERROR_BUSY           = -4,
    FW_ERROR_HW_FAULT       = -5,
    FW_ERROR_DMA            = -6,
    FW_ERROR_OVERFLOW       = -7,
    FW_ERROR_INVALID_OP     = -8,
    FW_ERROR_NOT_READY      = -9,
} fw_status_t;

/* ==========================================================================
 * NPU States
 * ========================================================================== */

typedef enum {
    NPU_STATE_RESET         = 0,
    NPU_STATE_INIT          = 1,
    NPU_STATE_IDLE          = 2,
    NPU_STATE_LOADING       = 3,
    NPU_STATE_RUNNING       = 4,
    NPU_STATE_DRAINING      = 5,
    NPU_STATE_DONE          = 6,
    NPU_STATE_ERROR         = 7,
} npu_state_t;

/* ==========================================================================
 * Layer Types
 * ========================================================================== */

typedef enum {
    LAYER_CONV2D            = 0,
    LAYER_DWCONV2D          = 1,
    LAYER_FC                = 2,
    LAYER_MAXPOOL           = 3,
    LAYER_AVGPOOL           = 4,
    LAYER_GLOBAL_AVGPOOL    = 5,
    LAYER_ADD               = 6,
    LAYER_CONCAT            = 7,
    LAYER_SOFTMAX           = 8,
    LAYER_BATCHNORM         = 9,
    LAYER_RESHAPE           = 10,
} layer_type_t;

/* ==========================================================================
 * Activation Types
 * ========================================================================== */

typedef enum {
    ACT_NONE                = 0,
    ACT_RELU                = 1,
    ACT_RELU6               = 2,
    ACT_SIGMOID             = 3,
    ACT_TANH                = 4,
    ACT_LEAKY_RELU          = 5,
    ACT_SWISH               = 6,
    ACT_GELU                = 7,
} activation_type_t;

/* ==========================================================================
 * Tensor Descriptor
 * ========================================================================== */

typedef struct {
    uint32_t addr;          /* Base address in buffer */
    uint16_t n;             /* Batch size */
    uint16_t c;             /* Channels */
    uint16_t h;             /* Height */
    uint16_t w;             /* Width */
    uint8_t  dtype;         /* Data type (0=int8, 1=int16, 2=fp16) */
    uint8_t  layout;        /* Memory layout (0=NCHW, 1=NHWC) */
    int8_t   zero_point;    /* Quantization zero point */
    uint8_t  reserved;
    int32_t  scale;         /* Quantization scale (fixed point) */
} tensor_desc_t;

/* ==========================================================================
 * Layer Descriptor
 * ========================================================================== */

typedef struct {
    layer_type_t type;
    activation_type_t activation;
    
    /* Input/Output tensors */
    tensor_desc_t input;
    tensor_desc_t output;
    tensor_desc_t weight;
    tensor_desc_t bias;
    
    /* Convolution parameters */
    uint8_t kernel_h;
    uint8_t kernel_w;
    uint8_t stride_h;
    uint8_t stride_w;
    uint8_t pad_top;
    uint8_t pad_bottom;
    uint8_t pad_left;
    uint8_t pad_right;
    uint8_t dilation_h;
    uint8_t dilation_w;
    uint8_t groups;
    uint8_t reserved;
    
    /* Pooling parameters */
    uint8_t pool_h;
    uint8_t pool_w;
    uint8_t pool_stride_h;
    uint8_t pool_stride_w;
    
    /* Quantization parameters */
    int32_t output_scale;
    int8_t  output_zero_point;
    int8_t  weight_zero_point;
    uint8_t shift_bits;
    uint8_t round_mode;
} layer_desc_t;

/* ==========================================================================
 * Model Descriptor
 * ========================================================================== */

#define MODEL_MAGIC         0x4E505545  /* "NPUE" */
#define MODEL_VERSION       0x0100

typedef struct {
    uint32_t magic;         /* Magic number */
    uint16_t version;       /* Model format version */
    uint16_t num_layers;    /* Number of layers */
    uint32_t weight_size;   /* Total weight size in bytes */
    uint32_t inst_count;    /* Number of instructions */
    uint32_t input_size;    /* Input tensor size */
    uint32_t output_size;   /* Output tensor size */
    uint32_t workspace_size;/* Required workspace size */
    uint32_t checksum;      /* Model checksum */
} model_header_t;

/* ==========================================================================
 * DMA Descriptor
 * ========================================================================== */

typedef struct {
    uint32_t src_addr;      /* Source address */
    uint32_t dst_addr;      /* Destination address */
    uint32_t length;        /* Transfer length in bytes */
    uint16_t src_stride;    /* Source stride for 2D */
    uint16_t dst_stride;    /* Destination stride for 2D */
    uint16_t width;         /* Width for 2D transfer */
    uint16_t height;        /* Height for 2D transfer */
    uint8_t  channel;       /* DMA channel */
    uint8_t  flags;         /* Transfer flags */
    uint16_t reserved;
} dma_desc_t;

/* DMA flags */
#define DMA_FLAG_2D         (1 << 0)
#define DMA_FLAG_IRQ        (1 << 1)
#define DMA_FLAG_CHAIN      (1 << 2)

/* ==========================================================================
 * Performance Statistics
 * ========================================================================== */

typedef struct {
    uint64_t total_cycles;
    uint64_t compute_cycles;
    uint64_t dma_cycles;
    uint64_t stall_cycles;
    uint64_t mac_ops;
    uint32_t layers_executed;
    uint32_t dma_transfers;
    float    pe_utilization;
    float    memory_bandwidth;
} perf_stats_t;

/* ==========================================================================
 * Firmware Context
 * ========================================================================== */

typedef struct {
    /* State */
    npu_state_t state;
    fw_status_t last_error;
    
    /* Current execution */
    uint32_t inst_ptr;
    uint32_t inst_count;
    uint32_t loop_count;
    uint32_t loop_start;
    
    /* Buffer pointers */
    uint32_t weight_ptr;
    uint32_t act_in_ptr;
    uint32_t act_out_ptr;
    
    /* Current layer */
    uint16_t current_layer;
    uint16_t total_layers;
    
    /* Performance tracking */
    perf_stats_t perf;
    
    /* Callbacks */
    void (*done_callback)(fw_status_t status);
    void (*error_callback)(fw_status_t status, uint32_t error_code);
} fw_context_t;

/* ==========================================================================
 * Utility Macros
 * ========================================================================== */

#define ALIGN_UP(x, align)      (((x) + (align) - 1) & ~((align) - 1))
#define ALIGN_DOWN(x, align)    ((x) & ~((align) - 1))
#define MIN(a, b)               ((a) < (b) ? (a) : (b))
#define MAX(a, b)               ((a) > (b) ? (a) : (b))
#define ARRAY_SIZE(arr)         (sizeof(arr) / sizeof((arr)[0]))

/* Tensor size calculation */
#define TENSOR_SIZE(t)          ((uint32_t)(t).n * (t).c * (t).h * (t).w)
#define TENSOR_BYTES(t)         (TENSOR_SIZE(t) * ((t).dtype == 0 ? 1 : 2))

#endif /* NPU_FW_TYPES_H */
