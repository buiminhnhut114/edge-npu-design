/**
 * EdgeNPU Driver Implementation
 * Low-level driver for NPU hardware control
 * 
 * Copyright (c) 2024 EdgeNPU Project
 */

#include "npu_driver.h"
#include <string.h>
#include <stdlib.h>

/* ==========================================================================
 * Platform Abstraction (customize for your platform)
 * ========================================================================== */

#ifndef NPU_PLATFORM_CUSTOM

/* Memory-mapped I/O */
static inline void npu_write32(uint32_t addr, uint32_t value) {
    *(volatile uint32_t*)addr = value;
}

static inline uint32_t npu_read32(uint32_t addr) {
    return *(volatile uint32_t*)addr;
}

static inline void npu_write64(uint32_t addr, uint64_t value) {
    *(volatile uint64_t*)addr = value;
}

/* Memory copy */
static inline void npu_memcpy(void* dst, const void* src, size_t size) {
    memcpy(dst, src, size);
}

/* Delay */
static inline void npu_delay_us(uint32_t us) {
    volatile uint32_t count = us * 100;  /* Adjust for your clock */
    while (count--);
}

#endif /* NPU_PLATFORM_CUSTOM */

/* ==========================================================================
 * Driver Context Structure
 * ========================================================================== */

struct npu_context {
    npu_config_t config;
    npu_state_t state;
    npu_hw_info_t hw_info;
    
    /* Callback for async operations */
    npu_callback_t callback;
    void* callback_data;
    
    /* Performance tracking */
    npu_perf_stats_t perf_stats;
    
    /* Debug mode */
    bool debug_enabled;
};

/* ==========================================================================
 * Helper Functions
 * ========================================================================== */

static inline void reg_write(npu_context_t* ctx, uint32_t offset, uint32_t value) {
    npu_write32(ctx->config.base_addr + offset, value);
}

static inline uint32_t reg_read(npu_context_t* ctx, uint32_t offset) {
    return npu_read32(ctx->config.base_addr + offset);
}

static npu_status_t wait_for_idle(npu_context_t* ctx, uint32_t timeout_ms) {
    uint32_t timeout_us = timeout_ms * 1000;
    uint32_t elapsed = 0;
    
    while (elapsed < timeout_us || timeout_ms == 0) {
        uint32_t status = reg_read(ctx, NPU_REG_STATUS);
        
        if (status & NPU_STATUS_ERROR) {
            ctx->state = NPU_STATE_ERROR;
            return NPU_ERROR_HW_ERROR;
        }
        
        if (status & NPU_STATUS_DONE) {
            ctx->state = NPU_STATE_IDLE;
            return NPU_OK;
        }
        
        if (status & NPU_STATUS_IDLE) {
            ctx->state = NPU_STATE_IDLE;
            return NPU_OK;
        }
        
        npu_delay_us(10);
        elapsed += 10;
    }
    
    return NPU_ERROR_TIMEOUT;
}

/* ==========================================================================
 * Initialization & Configuration
 * ========================================================================== */

npu_context_t* npu_init(const npu_config_t* config) {
    if (!config) {
        return NULL;
    }
    
    npu_context_t* ctx = (npu_context_t*)malloc(sizeof(npu_context_t));
    if (!ctx) {
        return NULL;
    }
    
    memset(ctx, 0, sizeof(npu_context_t));
    memcpy(&ctx->config, config, sizeof(npu_config_t));
    
    /* Read hardware version */
    uint32_t version = reg_read(ctx, NPU_REG_VERSION);
    ctx->hw_info.hw_version = version;
    ctx->hw_info.pe_array_size = 16;  /* Default 16x16 PE array */
    ctx->hw_info.max_inst_count = 4096;
    ctx->hw_info.weight_buf_kb = config->weight_buf_size / 1024;
    ctx->hw_info.act_buf_kb = config->act_buf_size / 1024;
    ctx->hw_info.has_dma = true;
    ctx->hw_info.has_debug = true;
    
    /* Reset NPU */
    npu_reset(ctx);
    
    ctx->state = NPU_STATE_IDLE;
    
    return ctx;
}

void npu_deinit(npu_context_t* ctx) {
    if (ctx) {
        /* Disable NPU */
        reg_write(ctx, NPU_REG_CTRL, 0);
        free(ctx);
    }
}

npu_status_t npu_reset(npu_context_t* ctx) {
    if (!ctx) {
        return NPU_ERROR_INVALID_PARAM;
    }
    
    /* Assert reset */
    reg_write(ctx, NPU_REG_CTRL, NPU_CTRL_RESET);
    npu_delay_us(100);
    
    /* Deassert reset and enable */
    reg_write(ctx, NPU_REG_CTRL, NPU_CTRL_ENABLE);
    npu_delay_us(100);
    
    /* Clear interrupts */
    reg_write(ctx, NPU_REG_IRQ_STATUS, 0xFFFFFFFF);
    
    /* Reset performance counters */
    memset(&ctx->perf_stats, 0, sizeof(npu_perf_stats_t));
    
    ctx->state = NPU_STATE_IDLE;
    
    return NPU_OK;
}

npu_status_t npu_get_hw_info(npu_context_t* ctx, npu_hw_info_t* info) {
    if (!ctx || !info) {
        return NPU_ERROR_INVALID_PARAM;
    }
    
    memcpy(info, &ctx->hw_info, sizeof(npu_hw_info_t));
    return NPU_OK;
}

npu_state_t npu_get_state(npu_context_t* ctx) {
    if (!ctx) {
        return NPU_STATE_UNINITIALIZED;
    }
    return ctx->state;
}

/* ==========================================================================
 * Memory Operations
 * ========================================================================== */

npu_status_t npu_load_instructions(npu_context_t* ctx,
                                    const uint64_t* instructions,
                                    uint32_t num_instructions) {
    if (!ctx || !instructions || num_instructions == 0) {
        return NPU_ERROR_INVALID_PARAM;
    }
    
    if (ctx->state == NPU_STATE_RUNNING) {
        return NPU_ERROR_BUSY;
    }
    
    uint32_t size = num_instructions * sizeof(uint64_t);
    if (size > ctx->config.inst_buf_size) {
        return NPU_ERROR_NO_MEMORY;
    }
    
    /* Copy instructions to buffer */
    uint64_t* inst_buf = (uint64_t*)ctx->config.inst_buf_addr;
    for (uint32_t i = 0; i < num_instructions; i++) {
        inst_buf[i] = instructions[i];
    }
    
    /* Configure instruction buffer registers */
    reg_write(ctx, NPU_REG_INST_BASE, ctx->config.inst_buf_addr);
    reg_write(ctx, NPU_REG_INST_SIZE, num_instructions);
    reg_write(ctx, NPU_REG_INST_PTR, 0);
    
    return NPU_OK;
}

npu_status_t npu_load_weights(npu_context_t* ctx,
                               const int8_t* weights,
                               uint32_t size) {
    if (!ctx || !weights || size == 0) {
        return NPU_ERROR_INVALID_PARAM;
    }
    
    if (ctx->state == NPU_STATE_RUNNING) {
        return NPU_ERROR_BUSY;
    }
    
    if (size > ctx->config.weight_buf_size) {
        return NPU_ERROR_NO_MEMORY;
    }
    
    /* Copy weights to buffer */
    npu_memcpy((void*)ctx->config.weight_buf_addr, weights, size);
    
    /* Configure weight buffer registers */
    reg_write(ctx, NPU_REG_WEIGHT_BASE, ctx->config.weight_buf_addr);
    reg_write(ctx, NPU_REG_WEIGHT_SIZE, size);
    
    return NPU_OK;
}

npu_status_t npu_load_input(npu_context_t* ctx,
                             const int8_t* input,
                             uint32_t size) {
    if (!ctx || !input || size == 0) {
        return NPU_ERROR_INVALID_PARAM;
    }
    
    if (ctx->state == NPU_STATE_RUNNING) {
        return NPU_ERROR_BUSY;
    }
    
    if (size > ctx->config.act_buf_size) {
        return NPU_ERROR_NO_MEMORY;
    }
    
    /* Copy input to activation buffer */
    npu_memcpy((void*)ctx->config.act_buf_addr, input, size);
    
    /* Configure activation buffer registers */
    reg_write(ctx, NPU_REG_ACT_IN_BASE, ctx->config.act_buf_addr);
    reg_write(ctx, NPU_REG_ACT_IN_SIZE, size);
    
    return NPU_OK;
}

npu_status_t npu_read_output(npu_context_t* ctx,
                              int8_t* output,
                              uint32_t size) {
    if (!ctx || !output || size == 0) {
        return NPU_ERROR_INVALID_PARAM;
    }
    
    if (ctx->state == NPU_STATE_RUNNING) {
        return NPU_ERROR_BUSY;
    }
    
    /* Read output from activation buffer */
    uint32_t out_base = reg_read(ctx, NPU_REG_ACT_OUT_BASE);
    uint32_t out_size = reg_read(ctx, NPU_REG_ACT_OUT_SIZE);
    
    if (size > out_size) {
        size = out_size;
    }
    
    npu_memcpy(output, (void*)out_base, size);
    
    return NPU_OK;
}

npu_status_t npu_dma_transfer(npu_context_t* ctx,
                               uint32_t src,
                               uint32_t dst,
                               uint32_t size) {
    if (!ctx || size == 0) {
        return NPU_ERROR_INVALID_PARAM;
    }
    
    if (!ctx->hw_info.has_dma) {
        return NPU_ERROR_INVALID_PARAM;
    }
    
    /* Configure DMA */
    reg_write(ctx, NPU_REG_DMA_SRC, src);
    reg_write(ctx, NPU_REG_DMA_DST, dst);
    reg_write(ctx, NPU_REG_DMA_SIZE, size);
    
    /* Start DMA */
    reg_write(ctx, NPU_REG_DMA_CTRL, 1);
    
    /* Wait for completion */
    uint32_t timeout = 10000;
    while (timeout--) {
        uint32_t status = reg_read(ctx, NPU_REG_DMA_STATUS);
        if (status & 0x1) {  /* Done bit */
            return NPU_OK;
        }
        npu_delay_us(1);
    }
    
    return NPU_ERROR_TIMEOUT;
}

/* ==========================================================================
 * Execution Control
 * ========================================================================== */

npu_status_t npu_run(npu_context_t* ctx, uint32_t timeout_ms) {
    if (!ctx) {
        return NPU_ERROR_INVALID_PARAM;
    }
    
    if (ctx->state == NPU_STATE_RUNNING) {
        return NPU_ERROR_BUSY;
    }
    
    /* Reset performance counters */
    npu_reset_perf_counters(ctx);
    
    /* Start execution */
    ctx->state = NPU_STATE_RUNNING;
    reg_write(ctx, NPU_REG_CTRL, NPU_CTRL_ENABLE | NPU_CTRL_START);
    
    /* Wait for completion */
    npu_status_t status = wait_for_idle(ctx, timeout_ms);
    
    /* Read performance counters */
    ctx->perf_stats.total_cycles = reg_read(ctx, NPU_REG_PERF_CYCLES);
    ctx->perf_stats.instructions_executed = reg_read(ctx, NPU_REG_PERF_INST);
    ctx->perf_stats.mac_operations = reg_read(ctx, NPU_REG_PERF_MAC);
    ctx->perf_stats.stall_cycles = reg_read(ctx, NPU_REG_PERF_STALL);
    
    if (ctx->perf_stats.total_cycles > 0) {
        ctx->perf_stats.utilization = 
            (float)(ctx->perf_stats.total_cycles - ctx->perf_stats.stall_cycles) /
            (float)ctx->perf_stats.total_cycles * 100.0f;
    }
    
    return status;
}

npu_status_t npu_run_async(npu_context_t* ctx,
                            npu_callback_t callback,
                            void* user_data) {
    if (!ctx) {
        return NPU_ERROR_INVALID_PARAM;
    }
    
    if (ctx->state == NPU_STATE_RUNNING) {
        return NPU_ERROR_BUSY;
    }
    
    /* Store callback */
    ctx->callback = callback;
    ctx->callback_data = user_data;
    
    /* Enable interrupt */
    reg_write(ctx, NPU_REG_IRQ_ENABLE, NPU_IRQ_DONE | NPU_IRQ_ERROR);
    
    /* Start execution */
    ctx->state = NPU_STATE_RUNNING;
    reg_write(ctx, NPU_REG_CTRL, NPU_CTRL_ENABLE | NPU_CTRL_START | NPU_CTRL_IRQ_EN);
    
    return NPU_OK;
}

npu_status_t npu_wait(npu_context_t* ctx, uint32_t timeout_ms) {
    if (!ctx) {
        return NPU_ERROR_INVALID_PARAM;
    }
    
    return wait_for_idle(ctx, timeout_ms);
}

npu_status_t npu_abort(npu_context_t* ctx) {
    if (!ctx) {
        return NPU_ERROR_INVALID_PARAM;
    }
    
    /* Reset NPU to abort */
    return npu_reset(ctx);
}

/* ==========================================================================
 * Performance & Debug
 * ========================================================================== */

npu_status_t npu_get_perf_stats(npu_context_t* ctx, npu_perf_stats_t* stats) {
    if (!ctx || !stats) {
        return NPU_ERROR_INVALID_PARAM;
    }
    
    /* Read current counters */
    ctx->perf_stats.total_cycles = reg_read(ctx, NPU_REG_PERF_CYCLES);
    ctx->perf_stats.instructions_executed = reg_read(ctx, NPU_REG_PERF_INST);
    ctx->perf_stats.mac_operations = reg_read(ctx, NPU_REG_PERF_MAC);
    ctx->perf_stats.stall_cycles = reg_read(ctx, NPU_REG_PERF_STALL);
    
    memcpy(stats, &ctx->perf_stats, sizeof(npu_perf_stats_t));
    return NPU_OK;
}

npu_status_t npu_reset_perf_counters(npu_context_t* ctx) {
    if (!ctx) {
        return NPU_ERROR_INVALID_PARAM;
    }
    
    /* Write to reset counters (implementation specific) */
    reg_write(ctx, NPU_REG_PERF_CYCLES, 0);
    reg_write(ctx, NPU_REG_PERF_INST, 0);
    reg_write(ctx, NPU_REG_PERF_MAC, 0);
    reg_write(ctx, NPU_REG_PERF_STALL, 0);
    
    memset(&ctx->perf_stats, 0, sizeof(npu_perf_stats_t));
    
    return NPU_OK;
}

npu_status_t npu_set_debug_mode(npu_context_t* ctx, bool enable) {
    if (!ctx) {
        return NPU_ERROR_INVALID_PARAM;
    }
    
    ctx->debug_enabled = enable;
    return NPU_OK;
}

/* ==========================================================================
 * Interrupt Handling
 * ========================================================================== */

void npu_irq_handler(npu_context_t* ctx) {
    if (!ctx) {
        return;
    }
    
    uint32_t irq_status = reg_read(ctx, NPU_REG_IRQ_STATUS);
    
    /* Clear interrupts */
    reg_write(ctx, NPU_REG_IRQ_STATUS, irq_status);
    
    npu_status_t status = NPU_OK;
    
    if (irq_status & NPU_IRQ_ERROR) {
        ctx->state = NPU_STATE_ERROR;
        status = NPU_ERROR_HW_ERROR;
    } else if (irq_status & NPU_IRQ_DONE) {
        ctx->state = NPU_STATE_IDLE;
        
        /* Read performance counters */
        ctx->perf_stats.total_cycles = reg_read(ctx, NPU_REG_PERF_CYCLES);
        ctx->perf_stats.instructions_executed = reg_read(ctx, NPU_REG_PERF_INST);
    }
    
    /* Call user callback */
    if (ctx->callback) {
        ctx->callback(status, ctx->callback_data);
    }
}

npu_status_t npu_set_irq_mask(npu_context_t* ctx, uint32_t mask) {
    if (!ctx) {
        return NPU_ERROR_INVALID_PARAM;
    }
    
    reg_write(ctx, NPU_REG_IRQ_ENABLE, mask);
    return NPU_OK;
}
