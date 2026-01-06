/**
 * EdgeNPU Firmware - Register Definitions
 * Hardware register map for firmware access
 * 
 * Copyright (c) 2024 EdgeNPU Project
 */

#ifndef NPU_FW_REGS_H
#define NPU_FW_REGS_H

#include <stdint.h>

/* ==========================================================================
 * Base Addresses
 * ========================================================================== */

#define NPU_BASE                0x40000000
#define NPU_INST_BUF_BASE       0x40100000
#define NPU_WEIGHT_BUF_BASE     0x40200000
#define NPU_ACT_BUF_BASE        0x40300000

/* ==========================================================================
 * Control Registers (0x000 - 0x0FF)
 * ========================================================================== */

#define REG_CTRL                (NPU_BASE + 0x000)
#define REG_STATUS              (NPU_BASE + 0x004)
#define REG_IRQ_EN              (NPU_BASE + 0x008)
#define REG_IRQ_STATUS          (NPU_BASE + 0x00C)
#define REG_VERSION             (NPU_BASE + 0x010)
#define REG_CONFIG              (NPU_BASE + 0x014)
#define REG_ERROR_CODE          (NPU_BASE + 0x018)
#define REG_DEBUG_CTRL          (NPU_BASE + 0x01C)

/* Control Register Bits */
#define CTRL_ENABLE             (1 << 0)
#define CTRL_START              (1 << 1)
#define CTRL_RESET              (1 << 2)
#define CTRL_ABORT              (1 << 3)
#define CTRL_SINGLE_STEP        (1 << 4)
#define CTRL_DEBUG_EN           (1 << 5)

/* Status Register Bits */
#define STATUS_BUSY             (1 << 0)
#define STATUS_DONE             (1 << 1)
#define STATUS_ERROR            (1 << 2)
#define STATUS_IDLE             (1 << 3)
#define STATUS_STATE_MASK       (0xF << 4)
#define STATUS_STATE_SHIFT      4

/* IRQ Bits */
#define IRQ_DONE                (1 << 0)
#define IRQ_ERROR               (1 << 1)
#define IRQ_DMA_DONE            (1 << 2)
#define IRQ_DMA_ERROR           (1 << 3)
#define IRQ_WATCHDOG            (1 << 4)

/* ==========================================================================
 * Instruction Buffer Registers (0x100 - 0x1FF)
 * ========================================================================== */

#define REG_INST_BASE           (NPU_BASE + 0x100)
#define REG_INST_SIZE           (NPU_BASE + 0x104)
#define REG_INST_PTR            (NPU_BASE + 0x108)
#define REG_INST_CTRL           (NPU_BASE + 0x10C)

/* ==========================================================================
 * Weight Buffer Registers (0x200 - 0x2FF)
 * ========================================================================== */

#define REG_WEIGHT_BASE         (NPU_BASE + 0x200)
#define REG_WEIGHT_SIZE         (NPU_BASE + 0x204)
#define REG_WEIGHT_CTRL         (NPU_BASE + 0x208)

/* ==========================================================================
 * Activation Buffer Registers (0x300 - 0x3FF)
 * ========================================================================== */

#define REG_ACT_IN_BASE         (NPU_BASE + 0x300)
#define REG_ACT_IN_SIZE         (NPU_BASE + 0x304)
#define REG_ACT_OUT_BASE        (NPU_BASE + 0x308)
#define REG_ACT_OUT_SIZE        (NPU_BASE + 0x30C)
#define REG_ACT_CTRL            (NPU_BASE + 0x310)

/* ==========================================================================
 * DMA Registers (0x400 - 0x4FF)
 * ========================================================================== */

#define REG_DMA_CTRL            (NPU_BASE + 0x400)
#define REG_DMA_STATUS          (NPU_BASE + 0x404)
#define REG_DMA_SRC             (NPU_BASE + 0x408)
#define REG_DMA_DST             (NPU_BASE + 0x40C)
#define REG_DMA_LEN             (NPU_BASE + 0x410)
#define REG_DMA_SRC_STRIDE      (NPU_BASE + 0x414)
#define REG_DMA_DST_STRIDE      (NPU_BASE + 0x418)

/* DMA Control Bits */
#define DMA_CTRL_START          (1 << 0)
#define DMA_CTRL_ABORT          (1 << 1)
#define DMA_CTRL_IRQ_EN         (1 << 2)
#define DMA_CTRL_2D_MODE        (1 << 3)
#define DMA_CTRL_CH_SEL_MASK    (0x3 << 4)
#define DMA_CTRL_CH_SEL_SHIFT   4

/* DMA Status Bits */
#define DMA_STATUS_BUSY         (1 << 0)
#define DMA_STATUS_DONE         (1 << 1)
#define DMA_STATUS_ERROR        (1 << 2)

/* DMA Channels */
#define DMA_CH_WEIGHT           0
#define DMA_CH_ACT_IN           1
#define DMA_CH_ACT_OUT          2

/* ==========================================================================
 * PE Array Registers (0x500 - 0x5FF)
 * ========================================================================== */

#define REG_PE_CTRL             (NPU_BASE + 0x500)
#define REG_PE_STATUS           (NPU_BASE + 0x504)
#define REG_PE_CONFIG           (NPU_BASE + 0x508)

/* PE Control Bits */
#define PE_CTRL_ENABLE          (1 << 0)
#define PE_CTRL_CLEAR_ACC       (1 << 1)
#define PE_CTRL_LOAD_WEIGHT     (1 << 2)

/* ==========================================================================
 * Performance Counters (0x600 - 0x6FF)
 * ========================================================================== */

#define REG_PERF_CTRL           (NPU_BASE + 0x600)
#define REG_PERF_CYCLES_LO      (NPU_BASE + 0x604)
#define REG_PERF_CYCLES_HI      (NPU_BASE + 0x608)
#define REG_PERF_INST_CNT       (NPU_BASE + 0x60C)
#define REG_PERF_MAC_LO         (NPU_BASE + 0x610)
#define REG_PERF_MAC_HI         (NPU_BASE + 0x614)
#define REG_PERF_STALL_CNT      (NPU_BASE + 0x618)
#define REG_PERF_DMA_CNT        (NPU_BASE + 0x61C)

/* Performance Control Bits */
#define PERF_CTRL_ENABLE        (1 << 0)
#define PERF_CTRL_RESET         (1 << 1)

/* ==========================================================================
 * Layer Configuration Registers (0x700 - 0x7FF)
 * ========================================================================== */

#define REG_LAYER_TYPE          (NPU_BASE + 0x700)
#define REG_LAYER_IN_CH         (NPU_BASE + 0x704)
#define REG_LAYER_OUT_CH        (NPU_BASE + 0x708)
#define REG_LAYER_IN_H          (NPU_BASE + 0x70C)
#define REG_LAYER_IN_W          (NPU_BASE + 0x710)
#define REG_LAYER_OUT_H         (NPU_BASE + 0x714)
#define REG_LAYER_OUT_W         (NPU_BASE + 0x718)
#define REG_LAYER_KERNEL        (NPU_BASE + 0x71C)
#define REG_LAYER_STRIDE        (NPU_BASE + 0x720)
#define REG_LAYER_PADDING       (NPU_BASE + 0x724)
#define REG_LAYER_ACT_TYPE      (NPU_BASE + 0x728)
#define REG_LAYER_POOL_TYPE     (NPU_BASE + 0x72C)
#define REG_LAYER_QUANT_SCALE   (NPU_BASE + 0x730)
#define REG_LAYER_QUANT_ZERO    (NPU_BASE + 0x734)

/* Layer Types */
#define LAYER_TYPE_CONV         0
#define LAYER_TYPE_DWCONV       1
#define LAYER_TYPE_FC           2
#define LAYER_TYPE_POOL         3
#define LAYER_TYPE_ELTWISE      4
#define LAYER_TYPE_SOFTMAX      5

/* Activation Types */
#define ACT_TYPE_NONE           0
#define ACT_TYPE_RELU           1
#define ACT_TYPE_RELU6          2
#define ACT_TYPE_SIGMOID        3
#define ACT_TYPE_TANH           4
#define ACT_TYPE_LEAKY_RELU     5

/* Pooling Types */
#define POOL_TYPE_NONE          0
#define POOL_TYPE_MAX           1
#define POOL_TYPE_AVG           2
#define POOL_TYPE_GLOBAL_AVG    3

/* ==========================================================================
 * Register Access Macros
 * ========================================================================== */

#define REG32(addr)             (*(volatile uint32_t*)(addr))
#define REG_READ(addr)          REG32(addr)
#define REG_WRITE(addr, val)    (REG32(addr) = (val))
#define REG_SET(addr, mask)     (REG32(addr) |= (mask))
#define REG_CLR(addr, mask)     (REG32(addr) &= ~(mask))

/* ==========================================================================
 * Hardware Configuration (from RTL parameters)
 * ========================================================================== */

#define NPU_PE_ROWS             16
#define NPU_PE_COLS             16
#define NPU_DATA_WIDTH          8
#define NPU_ACC_WIDTH           32
#define NPU_WEIGHT_BUF_KB       256
#define NPU_ACT_BUF_KB          256
#define NPU_INST_BUF_ENTRIES    1024
#define NPU_MAX_BATCH_SIZE      16

#endif /* NPU_FW_REGS_H */
