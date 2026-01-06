/**
 * EdgeNPU Driver API
 * Low-level driver for NPU hardware control
 * 
 * Copyright (c) 2024 EdgeNPU Project
 */

#ifndef NPU_DRIVER_H
#define NPU_DRIVER_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ==========================================================================
 * NPU Register Map (matching RTL npu_pkg.sv)
 * ========================================================================== */

#define NPU_BASE_ADDR           0x40000000

/* Control Registers */
#define NPU_REG_CTRL            0x000   /* Control register */
#define NPU_REG_STATUS          0x004   /* Status register */
#define NPU_REG_IRQ_ENABLE      0x008   /* Interrupt enable */
#define NPU_REG_IRQ_STATUS      0x00C   /* Interrupt status */
#define NPU_REG_VERSION         0x010   /* Hardware version */

/* Instruction Buffer Registers */
#define NPU_REG_INST_BASE       0x100   /* Instruction buffer base address */
#define NPU_REG_INST_SIZE       0x104   /* Number of instructions */
#define NPU_REG_INST_PTR        0x108   /* Current instruction pointer */

/* Weight Buffer Registers */
#define NPU_REG_WEIGHT_BASE     0x200   /* Weight buffer base address */
#define NPU_REG_WEIGHT_SIZE     0x204   /* Weight data size */

/* Activation Buffer Registers */
#define NPU_REG_ACT_IN_BASE     0x300   /* Input activation base */
#define NPU_REG_ACT_IN_SIZE     0x304   /* Input size */
#define NPU_REG_ACT_OUT_BASE    0x308   /* Output activation base */
#define NPU_REG_ACT_OUT_SIZE    0x30C   /* Output size */

/* DMA Registers */
#define NPU_REG_DMA_SRC         0x400   /* DMA source address */
#define NPU_REG_DMA_DST         0x404   /* DMA destination address */
#define NPU_REG_DMA_SIZE        0x408   /* DMA transfer size */
#define NPU_REG_DMA_CTRL        0x40C   /* DMA control */
#define NPU_REG_DMA_STATUS      0x410   /* DMA status */

/* Performance Counters */
#define NPU_REG_PERF_CYCLES     0x500   /* Total cycles */
#define NPU_REG_PERF_INST       0x504   /* Instructions executed */
#define NPU_REG_PERF_MAC        0x508   /* MAC operations */
#define NPU_REG_PERF_STALL      0x50C   /* Stall cycles */

/* Control Register Bits */
#define NPU_CTRL_ENABLE         (1 << 0)
#define NPU_CTRL_START          (1 << 1)
#define NPU_CTRL_RESET          (1 << 2)
#define NPU_CTRL_IRQ_EN         (1 << 3)

/* Status Register Bits */
#define NPU_STATUS_IDLE         (1 << 0)
#define NPU_STATUS_RUNNING      (1 << 1)
#define NPU_STATUS_DONE         (1 << 2)
#define NPU_STATUS_ERROR        (1 << 3)

/* IRQ Bits */
#define NPU_IRQ_DONE            (1 << 0)
#define NPU_IRQ_ERROR           (1 << 1)
#define NPU_IRQ_DMA_DONE        (1 << 2)

/* ==========================================================================
 * Data Types
 * ========================================================================== */

typedef enum {
    NPU_OK = 0,
    NPU_ERROR_INVALID_PARAM = -1,
    NPU_ERROR_NOT_INITIALIZED = -2,
    NPU_ERROR_BUSY = -3,
    NPU_ERROR_TIMEOUT = -4,
    NPU_ERROR_HW_ERROR = -5,
    NPU_ERROR_NO_MEMORY = -6,
    NPU_ERROR_INVALID_MODEL = -7,
} npu_status_t;

typedef enum {
    NPU_STATE_UNINITIALIZED = 0,
    NPU_STATE_IDLE,
    NPU_STATE_RUNNING,
    NPU_STATE_ERROR,
} npu_state_t;

typedef struct {
    uint32_t base_addr;         /* NPU base address */
    uint32_t inst_buf_addr;     /* Instruction buffer address */
    uint32_t inst_buf_size;     /* Instruction buffer size */
    uint32_t weight_buf_addr;   /* Weight buffer address */
    uint32_t weight_buf_size;   /* Weight buffer size */
    uint32_t act_buf_addr;      /* Activation buffer address */
    uint32_t act_buf_size;      /* Activation buffer size */
} npu_config_t;

typedef struct {
    uint32_t hw_version;
    uint32_t pe_array_size;
    uint32_t max_inst_count;
    uint32_t weight_buf_kb;
    uint32_t act_buf_kb;
    bool     has_dma;
    bool     has_debug;
} npu_hw_info_t;

typedef struct {
    uint64_t total_cycles;
    uint64_t instructions_executed;
    uint64_t mac_operations;
    uint64_t stall_cycles;
    float    utilization;       /* PE utilization percentage */
} npu_perf_stats_t;

typedef void (*npu_callback_t)(npu_status_t status, void* user_data);

/* ==========================================================================
 * Driver Context
 * ========================================================================== */

typedef struct npu_context npu_context_t;

/* ==========================================================================
 * Initialization & Configuration
 * ========================================================================== */

/**
 * Initialize NPU driver
 * @param config Configuration parameters
 * @return NPU context or NULL on error
 */
npu_context_t* npu_init(const npu_config_t* config);

/**
 * Deinitialize NPU driver
 * @param ctx NPU context
 */
void npu_deinit(npu_context_t* ctx);

/**
 * Reset NPU hardware
 * @param ctx NPU context
 * @return Status code
 */
npu_status_t npu_reset(npu_context_t* ctx);

/**
 * Get hardware information
 * @param ctx NPU context
 * @param info Output hardware info
 * @return Status code
 */
npu_status_t npu_get_hw_info(npu_context_t* ctx, npu_hw_info_t* info);

/**
 * Get current NPU state
 * @param ctx NPU context
 * @return Current state
 */
npu_state_t npu_get_state(npu_context_t* ctx);

/* ==========================================================================
 * Memory Operations
 * ========================================================================== */

/**
 * Load instructions to instruction buffer
 * @param ctx NPU context
 * @param instructions Instruction data
 * @param num_instructions Number of 64-bit instructions
 * @return Status code
 */
npu_status_t npu_load_instructions(npu_context_t* ctx, 
                                    const uint64_t* instructions,
                                    uint32_t num_instructions);

/**
 * Load weights to weight buffer
 * @param ctx NPU context
 * @param weights Weight data (int8)
 * @param size Size in bytes
 * @return Status code
 */
npu_status_t npu_load_weights(npu_context_t* ctx,
                               const int8_t* weights,
                               uint32_t size);

/**
 * Load input activations
 * @param ctx NPU context
 * @param input Input data (int8)
 * @param size Size in bytes
 * @return Status code
 */
npu_status_t npu_load_input(npu_context_t* ctx,
                             const int8_t* input,
                             uint32_t size);

/**
 * Read output activations
 * @param ctx NPU context
 * @param output Output buffer
 * @param size Size in bytes
 * @return Status code
 */
npu_status_t npu_read_output(npu_context_t* ctx,
                              int8_t* output,
                              uint32_t size);

/**
 * DMA transfer (if supported)
 * @param ctx NPU context
 * @param src Source address
 * @param dst Destination address
 * @param size Transfer size
 * @return Status code
 */
npu_status_t npu_dma_transfer(npu_context_t* ctx,
                               uint32_t src,
                               uint32_t dst,
                               uint32_t size);

/* ==========================================================================
 * Execution Control
 * ========================================================================== */

/**
 * Start NPU execution (blocking)
 * @param ctx NPU context
 * @param timeout_ms Timeout in milliseconds (0 = infinite)
 * @return Status code
 */
npu_status_t npu_run(npu_context_t* ctx, uint32_t timeout_ms);

/**
 * Start NPU execution (non-blocking)
 * @param ctx NPU context
 * @param callback Completion callback
 * @param user_data User data for callback
 * @return Status code
 */
npu_status_t npu_run_async(npu_context_t* ctx,
                            npu_callback_t callback,
                            void* user_data);

/**
 * Wait for NPU completion
 * @param ctx NPU context
 * @param timeout_ms Timeout in milliseconds
 * @return Status code
 */
npu_status_t npu_wait(npu_context_t* ctx, uint32_t timeout_ms);

/**
 * Abort current execution
 * @param ctx NPU context
 * @return Status code
 */
npu_status_t npu_abort(npu_context_t* ctx);

/* ==========================================================================
 * Performance & Debug
 * ========================================================================== */

/**
 * Get performance statistics
 * @param ctx NPU context
 * @param stats Output statistics
 * @return Status code
 */
npu_status_t npu_get_perf_stats(npu_context_t* ctx, npu_perf_stats_t* stats);

/**
 * Reset performance counters
 * @param ctx NPU context
 * @return Status code
 */
npu_status_t npu_reset_perf_counters(npu_context_t* ctx);

/**
 * Enable/disable debug mode
 * @param ctx NPU context
 * @param enable Enable flag
 * @return Status code
 */
npu_status_t npu_set_debug_mode(npu_context_t* ctx, bool enable);

/* ==========================================================================
 * Interrupt Handling
 * ========================================================================== */

/**
 * NPU interrupt handler (call from ISR)
 * @param ctx NPU context
 */
void npu_irq_handler(npu_context_t* ctx);

/**
 * Enable/disable interrupts
 * @param ctx NPU context
 * @param mask Interrupt mask
 * @return Status code
 */
npu_status_t npu_set_irq_mask(npu_context_t* ctx, uint32_t mask);

#ifdef __cplusplus
}
#endif

#endif /* NPU_DRIVER_H */
