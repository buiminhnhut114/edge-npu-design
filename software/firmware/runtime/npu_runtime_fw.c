/**
 * EdgeNPU Firmware - Runtime Implementation
 * Core runtime execution engine
 * 
 * Copyright (c) 2024 EdgeNPU Project
 */

#include "npu_runtime_fw.h"
#include "../include/npu_fw_regs.h"
#include <string.h>

/* ==========================================================================
 * Private Data
 * ========================================================================== */

static fw_context_t g_ctx;
static runtime_config_t g_config;
static bool g_initialized = false;

/* ==========================================================================
 * Private Functions
 * ========================================================================== */

static void delay_us(uint32_t us)
{
    /* Approximate delay - adjust based on clock frequency */
    volatile uint32_t cycles = us * 100;
    while (cycles--) {
        __asm__ volatile("nop");
    }
}

static fw_status_t wait_status(uint32_t mask, uint32_t expected, uint32_t timeout_us)
{
    uint32_t elapsed = 0;
    const uint32_t poll_interval = 10;
    
    while (elapsed < timeout_us || timeout_us == 0) {
        uint32_t status = REG_READ(REG_STATUS);
        
        if ((status & mask) == expected) {
            return FW_OK;
        }
        
        if (status & STATUS_ERROR) {
            g_ctx.last_error = FW_ERROR_HW_FAULT;
            g_ctx.state = NPU_STATE_ERROR;
            return FW_ERROR_HW_FAULT;
        }
        
        delay_us(poll_interval);
        elapsed += poll_interval;
    }
    
    return FW_ERROR_TIMEOUT;
}

static void update_perf_stats(void)
{
    g_ctx.perf.total_cycles = 
        ((uint64_t)REG_READ(REG_PERF_CYCLES_HI) << 32) | 
        REG_READ(REG_PERF_CYCLES_LO);
    
    g_ctx.perf.mac_ops = 
        ((uint64_t)REG_READ(REG_PERF_MAC_HI) << 32) | 
        REG_READ(REG_PERF_MAC_LO);
    
    g_ctx.perf.stall_cycles = REG_READ(REG_PERF_STALL_CNT);
    g_ctx.perf.layers_executed = REG_READ(REG_PERF_INST_CNT);
    
    /* Calculate utilization */
    if (g_ctx.perf.total_cycles > 0) {
        g_ctx.perf.compute_cycles = g_ctx.perf.total_cycles - g_ctx.perf.stall_cycles;
        g_ctx.perf.pe_utilization = 
            (float)g_ctx.perf.compute_cycles / (float)g_ctx.perf.total_cycles * 100.0f;
    }
}

/* ==========================================================================
 * Initialization
 * ========================================================================== */

fw_status_t npu_rt_init(const runtime_config_t *config)
{
    if (!config) {
        return FW_ERROR_INVALID_PARAM;
    }
    
    /* Store configuration */
    memcpy(&g_config, config, sizeof(runtime_config_t));
    
    /* Initialize context */
    memset(&g_ctx, 0, sizeof(fw_context_t));
    g_ctx.state = NPU_STATE_INIT;
    
    /* Configure buffers */
    REG_WRITE(REG_INST_BASE, config->inst_buf_addr);
    REG_WRITE(REG_WEIGHT_BASE, config->weight_buf_addr);
    REG_WRITE(REG_ACT_IN_BASE, config->act_buf_addr);
    REG_WRITE(REG_ACT_OUT_BASE, config->act_buf_addr + config->act_buf_size / 2);
    
    /* Configure interrupts */
    if (config->enable_irq) {
        REG_WRITE(REG_IRQ_EN, IRQ_DONE | IRQ_ERROR | IRQ_DMA_DONE);
    } else {
        REG_WRITE(REG_IRQ_EN, 0);
    }
    
    /* Configure performance counters */
    if (config->enable_perf) {
        REG_WRITE(REG_PERF_CTRL, PERF_CTRL_ENABLE | PERF_CTRL_RESET);
    }
    
    g_ctx.state = NPU_STATE_IDLE;
    g_initialized = true;
    
    return FW_OK;
}

void npu_rt_deinit(void)
{
    if (!g_initialized) return;
    
    /* Stop any running execution */
    npu_rt_stop();
    
    /* Disable interrupts */
    REG_WRITE(REG_IRQ_EN, 0);
    
    /* Clear context */
    memset(&g_ctx, 0, sizeof(fw_context_t));
    g_initialized = false;
}

fw_context_t* npu_rt_get_context(void)
{
    return &g_ctx;
}

/* ==========================================================================
 * Model Loading
 * ========================================================================== */

fw_status_t npu_rt_load_model(const void *model_data, uint32_t model_size)
{
    if (!g_initialized) return FW_ERROR_NOT_READY;
    if (!model_data || model_size < sizeof(model_header_t)) {
        return FW_ERROR_INVALID_PARAM;
    }
    
    const model_header_t *header = (const model_header_t *)model_data;
    
    /* Verify magic number */
    if (header->magic != MODEL_MAGIC) {
        return FW_ERROR_INVALID_PARAM;
    }
    
    /* Verify version */
    if (header->version > MODEL_VERSION) {
        return FW_ERROR_INVALID_PARAM;
    }
    
    /* Store model info */
    g_ctx.total_layers = header->num_layers;
    g_ctx.inst_count = header->inst_count;
    
    /* Load instructions */
    const uint8_t *data = (const uint8_t *)model_data + sizeof(model_header_t);
    fw_status_t status = npu_rt_load_instructions(
        (const uint64_t *)data, 
        header->inst_count
    );
    if (status != FW_OK) return status;
    
    /* Load weights */
    data += header->inst_count * sizeof(uint64_t);
    status = npu_rt_load_weights(data, header->weight_size, 0);
    
    return status;
}

fw_status_t npu_rt_load_instructions(const uint64_t *instructions, uint32_t count)
{
    if (!g_initialized) return FW_ERROR_NOT_READY;
    if (!instructions || count == 0) return FW_ERROR_INVALID_PARAM;
    if (count > NPU_INST_BUF_ENTRIES) return FW_ERROR_OVERFLOW;
    
    /* Copy instructions to buffer */
    volatile uint64_t *inst_buf = (volatile uint64_t *)NPU_INST_BUF_BASE;
    for (uint32_t i = 0; i < count; i++) {
        inst_buf[i] = instructions[i];
    }
    
    /* Update registers */
    REG_WRITE(REG_INST_SIZE, count);
    REG_WRITE(REG_INST_PTR, 0);
    
    g_ctx.inst_count = count;
    g_ctx.inst_ptr = 0;
    
    return FW_OK;
}

fw_status_t npu_rt_load_weights(const void *weights, uint32_t size, uint32_t offset)
{
    if (!g_initialized) return FW_ERROR_NOT_READY;
    if (!weights || size == 0) return FW_ERROR_INVALID_PARAM;
    if (offset + size > g_config.weight_buf_size) return FW_ERROR_OVERFLOW;
    
    /* Use DMA for large transfers */
    if (size > 1024) {
        dma_desc_t desc = {
            .src_addr = (uint32_t)(uintptr_t)weights,
            .dst_addr = NPU_WEIGHT_BUF_BASE + offset,
            .length = size,
            .channel = DMA_CH_WEIGHT,
            .flags = 0
        };
        
        fw_status_t status = npu_rt_dma_start(&desc);
        if (status != FW_OK) return status;
        
        return npu_rt_dma_wait(1000000);  /* 1 second timeout */
    }
    
    /* Direct copy for small transfers */
    volatile uint8_t *dst = (volatile uint8_t *)(NPU_WEIGHT_BUF_BASE + offset);
    const uint8_t *src = (const uint8_t *)weights;
    for (uint32_t i = 0; i < size; i++) {
        dst[i] = src[i];
    }
    
    REG_WRITE(REG_WEIGHT_SIZE, size);
    
    return FW_OK;
}

fw_status_t npu_rt_load_input(const void *input, uint32_t size)
{
    if (!g_initialized) return FW_ERROR_NOT_READY;
    if (!input || size == 0) return FW_ERROR_INVALID_PARAM;
    if (size > g_config.act_buf_size / 2) return FW_ERROR_OVERFLOW;
    
    /* Use DMA for transfer */
    dma_desc_t desc = {
        .src_addr = (uint32_t)(uintptr_t)input,
        .dst_addr = NPU_ACT_BUF_BASE,
        .length = size,
        .channel = DMA_CH_ACT_IN,
        .flags = 0
    };
    
    fw_status_t status = npu_rt_dma_start(&desc);
    if (status != FW_OK) return status;
    
    status = npu_rt_dma_wait(1000000);
    if (status != FW_OK) return status;
    
    REG_WRITE(REG_ACT_IN_SIZE, size);
    
    return FW_OK;
}

/* ==========================================================================
 * Execution Control
 * ========================================================================== */

fw_status_t npu_rt_start(void)
{
    if (!g_initialized) return FW_ERROR_NOT_READY;
    if (g_ctx.state == NPU_STATE_RUNNING) return FW_ERROR_BUSY;
    
    /* Reset instruction pointer */
    REG_WRITE(REG_INST_PTR, 0);
    g_ctx.inst_ptr = 0;
    g_ctx.current_layer = 0;
    
    /* Clear any pending status */
    REG_WRITE(REG_IRQ_STATUS, 0xFFFFFFFF);
    
    /* Start execution */
    g_ctx.state = NPU_STATE_RUNNING;
    REG_SET(REG_CTRL, CTRL_START);
    
    return FW_OK;
}

fw_status_t npu_rt_stop(void)
{
    if (!g_initialized) return FW_ERROR_NOT_READY;
    
    /* Abort execution */
    REG_SET(REG_CTRL, CTRL_ABORT);
    
    /* Wait for idle */
    fw_status_t status = wait_status(STATUS_IDLE, STATUS_IDLE, 10000);
    
    REG_CLR(REG_CTRL, CTRL_ABORT);
    g_ctx.state = NPU_STATE_IDLE;
    
    return status;
}

fw_status_t npu_rt_wait(uint32_t timeout_us)
{
    if (!g_initialized) return FW_ERROR_NOT_READY;
    
    fw_status_t status = wait_status(STATUS_DONE | STATUS_ERROR, STATUS_DONE, timeout_us);
    
    if (status == FW_OK) {
        g_ctx.state = NPU_STATE_DONE;
        update_perf_stats();
    }
    
    return status;
}

bool npu_rt_is_done(void)
{
    if (!g_initialized) return false;
    return (REG_READ(REG_STATUS) & STATUS_DONE) != 0;
}

npu_state_t npu_rt_get_state(void)
{
    return g_ctx.state;
}

fw_status_t npu_rt_get_error(void)
{
    return g_ctx.last_error;
}

/* ==========================================================================
 * Output Handling
 * ========================================================================== */

fw_status_t npu_rt_read_output(void *output, uint32_t size)
{
    if (!g_initialized) return FW_ERROR_NOT_READY;
    if (!output || size == 0) return FW_ERROR_INVALID_PARAM;
    
    uint32_t out_size = REG_READ(REG_ACT_OUT_SIZE);
    if (size > out_size) size = out_size;
    
    /* Use DMA for transfer */
    dma_desc_t desc = {
        .src_addr = REG_READ(REG_ACT_OUT_BASE),
        .dst_addr = (uint32_t)(uintptr_t)output,
        .length = size,
        .channel = DMA_CH_ACT_OUT,
        .flags = 0
    };
    
    fw_status_t status = npu_rt_dma_start(&desc);
    if (status != FW_OK) return status;
    
    return npu_rt_dma_wait(1000000);
}

uint32_t npu_rt_get_output_size(void)
{
    return REG_READ(REG_ACT_OUT_SIZE);
}

/* ==========================================================================
 * DMA Operations
 * ========================================================================== */

fw_status_t npu_rt_dma_start(const dma_desc_t *desc)
{
    if (!desc) return FW_ERROR_INVALID_PARAM;
    
    /* Wait if DMA is busy */
    if (npu_rt_dma_is_busy()) {
        fw_status_t status = npu_rt_dma_wait(100000);
        if (status != FW_OK) return status;
    }
    
    /* Configure DMA */
    REG_WRITE(REG_DMA_SRC, desc->src_addr);
    REG_WRITE(REG_DMA_DST, desc->dst_addr);
    REG_WRITE(REG_DMA_LEN, desc->length);
    
    if (desc->flags & DMA_FLAG_2D) {
        REG_WRITE(REG_DMA_SRC_STRIDE, desc->src_stride);
        REG_WRITE(REG_DMA_DST_STRIDE, desc->dst_stride);
    }
    
    /* Set channel and start */
    uint32_t ctrl = DMA_CTRL_START;
    ctrl |= (desc->channel << DMA_CTRL_CH_SEL_SHIFT);
    if (desc->flags & DMA_FLAG_2D) ctrl |= DMA_CTRL_2D_MODE;
    if (desc->flags & DMA_FLAG_IRQ) ctrl |= DMA_CTRL_IRQ_EN;
    
    REG_WRITE(REG_DMA_CTRL, ctrl);
    g_ctx.perf.dma_transfers++;
    
    return FW_OK;
}

fw_status_t npu_rt_dma_wait(uint32_t timeout_us)
{
    uint32_t elapsed = 0;
    const uint32_t poll_interval = 10;
    
    while (elapsed < timeout_us || timeout_us == 0) {
        uint32_t status = REG_READ(REG_DMA_STATUS);
        
        if (status & DMA_STATUS_DONE) {
            return FW_OK;
        }
        
        if (status & DMA_STATUS_ERROR) {
            return FW_ERROR_DMA;
        }
        
        delay_us(poll_interval);
        elapsed += poll_interval;
    }
    
    return FW_ERROR_TIMEOUT;
}

bool npu_rt_dma_is_busy(void)
{
    return (REG_READ(REG_DMA_STATUS) & DMA_STATUS_BUSY) != 0;
}

/* ==========================================================================
 * Performance
 * ========================================================================== */

fw_status_t npu_rt_get_perf(perf_stats_t *stats)
{
    if (!stats) return FW_ERROR_INVALID_PARAM;
    
    update_perf_stats();
    memcpy(stats, &g_ctx.perf, sizeof(perf_stats_t));
    
    return FW_OK;
}

void npu_rt_reset_perf(void)
{
    REG_WRITE(REG_PERF_CTRL, PERF_CTRL_RESET);
    delay_us(10);
    REG_WRITE(REG_PERF_CTRL, PERF_CTRL_ENABLE);
    
    memset(&g_ctx.perf, 0, sizeof(perf_stats_t));
}

/* ==========================================================================
 * Interrupt Handling
 * ========================================================================== */

void npu_rt_irq_handler(void)
{
    uint32_t irq_status = REG_READ(REG_IRQ_STATUS);
    
    if (irq_status & IRQ_DONE) {
        g_ctx.state = NPU_STATE_DONE;
        update_perf_stats();
        
        if (g_ctx.done_callback) {
            g_ctx.done_callback(FW_OK);
        }
    }
    
    if (irq_status & IRQ_ERROR) {
        g_ctx.state = NPU_STATE_ERROR;
        g_ctx.last_error = FW_ERROR_HW_FAULT;
        
        if (g_ctx.error_callback) {
            g_ctx.error_callback(FW_ERROR_HW_FAULT, REG_READ(REG_ERROR_CODE));
        }
    }
    
    /* Clear handled interrupts */
    REG_WRITE(REG_IRQ_STATUS, irq_status);
}

void npu_rt_set_done_callback(void (*callback)(fw_status_t))
{
    g_ctx.done_callback = callback;
}

void npu_rt_set_error_callback(void (*callback)(fw_status_t, uint32_t))
{
    g_ctx.error_callback = callback;
}
