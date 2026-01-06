/**
 * EdgeNPU Firmware - Boot Code
 * Hardware initialization and startup sequence
 * 
 * Copyright (c) 2024 EdgeNPU Project
 */

#include "../include/npu_fw_regs.h"
#include "../include/npu_fw_types.h"

/* ==========================================================================
 * Boot Configuration
 * ========================================================================== */

#define BOOT_TIMEOUT_CYCLES     100000
#define RESET_DELAY_CYCLES      1000

/* ==========================================================================
 * Private Functions
 * ========================================================================== */

static void delay_cycles(uint32_t cycles)
{
    volatile uint32_t i;
    for (i = 0; i < cycles; i++) {
        __asm__ volatile("nop");
    }
}

static fw_status_t wait_for_idle(uint32_t timeout)
{
    uint32_t count = 0;
    
    while (count < timeout) {
        uint32_t status = REG_READ(REG_STATUS);
        if (status & STATUS_IDLE) {
            return FW_OK;
        }
        if (status & STATUS_ERROR) {
            return FW_ERROR_HW_FAULT;
        }
        count++;
    }
    
    return FW_ERROR_TIMEOUT;
}

static fw_status_t verify_hardware(void)
{
    uint32_t version = REG_READ(REG_VERSION);
    uint32_t config = REG_READ(REG_CONFIG);
    
    /* Check version register is readable */
    if (version == 0 || version == 0xFFFFFFFF) {
        return FW_ERROR_HW_FAULT;
    }
    
    /* Verify PE array configuration */
    uint16_t pe_rows = (config >> 16) & 0xFFFF;
    uint16_t pe_cols = config & 0xFFFF;
    
    if (pe_rows == 0 || pe_cols == 0) {
        return FW_ERROR_HW_FAULT;
    }
    
    if (pe_rows > 64 || pe_cols > 64) {
        return FW_ERROR_HW_FAULT;
    }
    
    return FW_OK;
}

static void clear_buffers(void)
{
    /* Clear instruction buffer control */
    REG_WRITE(REG_INST_BASE, 0);
    REG_WRITE(REG_INST_SIZE, 0);
    REG_WRITE(REG_INST_PTR, 0);
    
    /* Clear weight buffer control */
    REG_WRITE(REG_WEIGHT_BASE, 0);
    REG_WRITE(REG_WEIGHT_SIZE, 0);
    
    /* Clear activation buffer control */
    REG_WRITE(REG_ACT_IN_BASE, 0);
    REG_WRITE(REG_ACT_IN_SIZE, 0);
    REG_WRITE(REG_ACT_OUT_BASE, 0);
    REG_WRITE(REG_ACT_OUT_SIZE, 0);
}

static void init_dma(void)
{
    /* Reset DMA engine */
    REG_WRITE(REG_DMA_CTRL, DMA_CTRL_ABORT);
    delay_cycles(100);
    REG_WRITE(REG_DMA_CTRL, 0);
    
    /* Clear DMA descriptors */
    REG_WRITE(REG_DMA_SRC, 0);
    REG_WRITE(REG_DMA_DST, 0);
    REG_WRITE(REG_DMA_LEN, 0);
    REG_WRITE(REG_DMA_SRC_STRIDE, 0);
    REG_WRITE(REG_DMA_DST_STRIDE, 0);
}

static void init_pe_array(void)
{
    /* Disable PE array */
    REG_WRITE(REG_PE_CTRL, 0);
    
    /* Clear accumulators */
    REG_SET(REG_PE_CTRL, PE_CTRL_CLEAR_ACC);
    delay_cycles(100);
    REG_CLR(REG_PE_CTRL, PE_CTRL_CLEAR_ACC);
}

static void init_perf_counters(void)
{
    /* Reset and enable performance counters */
    REG_WRITE(REG_PERF_CTRL, PERF_CTRL_RESET);
    delay_cycles(10);
    REG_WRITE(REG_PERF_CTRL, PERF_CTRL_ENABLE);
}

static void clear_interrupts(void)
{
    /* Disable all interrupts */
    REG_WRITE(REG_IRQ_EN, 0);
    
    /* Clear pending interrupts */
    REG_WRITE(REG_IRQ_STATUS, 0xFFFFFFFF);
}

/* ==========================================================================
 * Public API
 * ========================================================================== */

/**
 * Hardware reset sequence
 */
fw_status_t npu_hw_reset(void)
{
    /* Assert reset */
    REG_SET(REG_CTRL, CTRL_RESET);
    delay_cycles(RESET_DELAY_CYCLES);
    
    /* Deassert reset */
    REG_CLR(REG_CTRL, CTRL_RESET);
    delay_cycles(RESET_DELAY_CYCLES);
    
    /* Wait for idle state */
    return wait_for_idle(BOOT_TIMEOUT_CYCLES);
}

/**
 * Full boot initialization
 */
fw_status_t npu_boot_init(void)
{
    fw_status_t status;
    
    /* Step 1: Hardware reset */
    status = npu_hw_reset();
    if (status != FW_OK) {
        return status;
    }
    
    /* Step 2: Verify hardware */
    status = verify_hardware();
    if (status != FW_OK) {
        return status;
    }
    
    /* Step 3: Clear interrupts */
    clear_interrupts();
    
    /* Step 4: Initialize DMA */
    init_dma();
    
    /* Step 5: Initialize PE array */
    init_pe_array();
    
    /* Step 6: Clear buffers */
    clear_buffers();
    
    /* Step 7: Initialize performance counters */
    init_perf_counters();
    
    /* Step 8: Enable NPU */
    REG_SET(REG_CTRL, CTRL_ENABLE);
    
    return FW_OK;
}

/**
 * Get hardware information
 */
fw_status_t npu_boot_get_info(uint32_t *version, uint32_t *pe_rows, uint32_t *pe_cols)
{
    if (!version || !pe_rows || !pe_cols) {
        return FW_ERROR_INVALID_PARAM;
    }
    
    *version = REG_READ(REG_VERSION);
    
    uint32_t config = REG_READ(REG_CONFIG);
    *pe_rows = (config >> 16) & 0xFFFF;
    *pe_cols = config & 0xFFFF;
    
    return FW_OK;
}

/**
 * Self-test routine
 */
fw_status_t npu_boot_selftest(void)
{
    fw_status_t status;
    
    /* Test 1: Register read/write */
    uint32_t test_val = 0xA5A5A5A5;
    REG_WRITE(REG_INST_BASE, test_val);
    if (REG_READ(REG_INST_BASE) != test_val) {
        return FW_ERROR_HW_FAULT;
    }
    REG_WRITE(REG_INST_BASE, 0);
    
    /* Test 2: DMA engine */
    REG_WRITE(REG_DMA_SRC, 0x1000);
    REG_WRITE(REG_DMA_DST, 0x2000);
    REG_WRITE(REG_DMA_LEN, 256);
    
    if (REG_READ(REG_DMA_SRC) != 0x1000 ||
        REG_READ(REG_DMA_DST) != 0x2000 ||
        REG_READ(REG_DMA_LEN) != 256) {
        return FW_ERROR_HW_FAULT;
    }
    
    /* Clear test values */
    REG_WRITE(REG_DMA_SRC, 0);
    REG_WRITE(REG_DMA_DST, 0);
    REG_WRITE(REG_DMA_LEN, 0);
    
    /* Test 3: PE array clear */
    REG_SET(REG_PE_CTRL, PE_CTRL_CLEAR_ACC);
    delay_cycles(100);
    REG_CLR(REG_PE_CTRL, PE_CTRL_CLEAR_ACC);
    
    /* Test 4: Interrupt system */
    REG_WRITE(REG_IRQ_EN, IRQ_DONE);
    if ((REG_READ(REG_IRQ_EN) & IRQ_DONE) == 0) {
        return FW_ERROR_HW_FAULT;
    }
    REG_WRITE(REG_IRQ_EN, 0);
    
    return FW_OK;
}

/**
 * Enter low power mode
 */
fw_status_t npu_boot_sleep(void)
{
    /* Disable NPU */
    REG_CLR(REG_CTRL, CTRL_ENABLE);
    
    /* Disable performance counters */
    REG_WRITE(REG_PERF_CTRL, 0);
    
    /* Disable interrupts */
    REG_WRITE(REG_IRQ_EN, 0);
    
    return FW_OK;
}

/**
 * Wake from low power mode
 */
fw_status_t npu_boot_wake(void)
{
    /* Re-enable NPU */
    REG_SET(REG_CTRL, CTRL_ENABLE);
    
    /* Re-enable performance counters */
    REG_WRITE(REG_PERF_CTRL, PERF_CTRL_ENABLE);
    
    /* Wait for idle */
    return wait_for_idle(BOOT_TIMEOUT_CYCLES);
}

/* ==========================================================================
 * Boot Entry Point
 * ========================================================================== */

/**
 * Main boot entry point
 * Called by startup code after basic initialization
 */
int npu_boot_main(void)
{
    fw_status_t status;
    
    /* Initialize hardware */
    status = npu_boot_init();
    if (status != FW_OK) {
        return (int)status;
    }
    
    /* Run self-test */
    status = npu_boot_selftest();
    if (status != FW_OK) {
        return (int)status;
    }
    
    return 0;
}
