/**
 * EdgeNPU Firmware - Runtime API
 * Runtime execution and control functions
 * 
 * Copyright (c) 2024 EdgeNPU Project
 */

#ifndef NPU_RUNTIME_FW_H
#define NPU_RUNTIME_FW_H

#include "../include/npu_fw_types.h"
#include "../include/npu_fw_inst.h"

#ifdef __cplusplus
extern "C" {
#endif

/* ==========================================================================
 * Runtime Configuration
 * ========================================================================== */

typedef struct {
    uint32_t inst_buf_addr;     /* Instruction buffer address */
    uint32_t inst_buf_size;     /* Instruction buffer size */
    uint32_t weight_buf_addr;   /* Weight buffer address */
    uint32_t weight_buf_size;   /* Weight buffer size */
    uint32_t act_buf_addr;      /* Activation buffer address */
    uint32_t act_buf_size;      /* Activation buffer size */
    bool     enable_irq;        /* Enable interrupts */
    bool     enable_perf;       /* Enable performance counters */
} runtime_config_t;

/* ==========================================================================
 * Initialization
 * ========================================================================== */

/**
 * Initialize runtime
 * @param config Runtime configuration
 * @return Status code
 */
fw_status_t npu_rt_init(const runtime_config_t *config);

/**
 * Deinitialize runtime
 */
void npu_rt_deinit(void);

/**
 * Get runtime context
 * @return Pointer to firmware context
 */
fw_context_t* npu_rt_get_context(void);

/* ==========================================================================
 * Model Loading
 * ========================================================================== */

/**
 * Load model from memory
 * @param model_data Pointer to model data
 * @param model_size Size of model data
 * @return Status code
 */
fw_status_t npu_rt_load_model(const void *model_data, uint32_t model_size);

/**
 * Load instructions
 * @param instructions Instruction array
 * @param count Number of instructions
 * @return Status code
 */
fw_status_t npu_rt_load_instructions(const uint64_t *instructions, uint32_t count);

/**
 * Load weights
 * @param weights Weight data
 * @param size Size in bytes
 * @param offset Offset in weight buffer
 * @return Status code
 */
fw_status_t npu_rt_load_weights(const void *weights, uint32_t size, uint32_t offset);

/**
 * Load input data
 * @param input Input data
 * @param size Size in bytes
 * @return Status code
 */
fw_status_t npu_rt_load_input(const void *input, uint32_t size);

/* ==========================================================================
 * Execution Control
 * ========================================================================== */

/**
 * Start execution
 * @return Status code
 */
fw_status_t npu_rt_start(void);

/**
 * Stop execution
 * @return Status code
 */
fw_status_t npu_rt_stop(void);

/**
 * Wait for completion
 * @param timeout_us Timeout in microseconds (0 = infinite)
 * @return Status code
 */
fw_status_t npu_rt_wait(uint32_t timeout_us);

/**
 * Check if execution is complete
 * @return true if complete
 */
bool npu_rt_is_done(void);

/**
 * Get current state
 * @return NPU state
 */
npu_state_t npu_rt_get_state(void);

/**
 * Get last error
 * @return Error code
 */
fw_status_t npu_rt_get_error(void);

/* ==========================================================================
 * Output Handling
 * ========================================================================== */

/**
 * Read output data
 * @param output Output buffer
 * @param size Size in bytes
 * @return Status code
 */
fw_status_t npu_rt_read_output(void *output, uint32_t size);

/**
 * Get output size
 * @return Output size in bytes
 */
uint32_t npu_rt_get_output_size(void);

/* ==========================================================================
 * DMA Operations
 * ========================================================================== */

/**
 * Start DMA transfer
 * @param desc DMA descriptor
 * @return Status code
 */
fw_status_t npu_rt_dma_start(const dma_desc_t *desc);

/**
 * Wait for DMA completion
 * @param timeout_us Timeout in microseconds
 * @return Status code
 */
fw_status_t npu_rt_dma_wait(uint32_t timeout_us);

/**
 * Check if DMA is busy
 * @return true if busy
 */
bool npu_rt_dma_is_busy(void);

/* ==========================================================================
 * Layer Execution
 * ========================================================================== */

/**
 * Execute single layer
 * @param layer Layer descriptor
 * @return Status code
 */
fw_status_t npu_rt_exec_layer(const layer_desc_t *layer);

/**
 * Execute convolution
 * @param layer Layer descriptor
 * @return Status code
 */
fw_status_t npu_rt_exec_conv(const layer_desc_t *layer);

/**
 * Execute fully connected
 * @param layer Layer descriptor
 * @return Status code
 */
fw_status_t npu_rt_exec_fc(const layer_desc_t *layer);

/**
 * Execute pooling
 * @param layer Layer descriptor
 * @return Status code
 */
fw_status_t npu_rt_exec_pool(const layer_desc_t *layer);

/**
 * Execute element-wise operation
 * @param layer Layer descriptor
 * @param input2 Second input tensor
 * @return Status code
 */
fw_status_t npu_rt_exec_eltwise(const layer_desc_t *layer, const tensor_desc_t *input2);

/* ==========================================================================
 * Performance
 * ========================================================================== */

/**
 * Get performance statistics
 * @param stats Output statistics
 * @return Status code
 */
fw_status_t npu_rt_get_perf(perf_stats_t *stats);

/**
 * Reset performance counters
 */
void npu_rt_reset_perf(void);

/* ==========================================================================
 * Interrupt Handling
 * ========================================================================== */

/**
 * Interrupt handler (call from ISR)
 */
void npu_rt_irq_handler(void);

/**
 * Set completion callback
 * @param callback Callback function
 */
void npu_rt_set_done_callback(void (*callback)(fw_status_t));

/**
 * Set error callback
 * @param callback Callback function
 */
void npu_rt_set_error_callback(void (*callback)(fw_status_t, uint32_t));

#ifdef __cplusplus
}
#endif

#endif /* NPU_RUNTIME_FW_H */
