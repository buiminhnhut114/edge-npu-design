/**
 * EdgeNPU Firmware - Startup Code
 * RISC-V startup and initialization
 * 
 * Copyright (c) 2024 EdgeNPU Project
 */

.section .vectors, "ax"
.global _start
.global _reset_handler

/* ==========================================================================
 * Vector Table
 * ========================================================================== */

_start:
_reset_handler:
    j       _init

/* Exception handlers */
.org 0x10
_exception_handler:
    j       _exception_handler

.org 0x20
_irq_handler:
    j       _irq_entry

/* ==========================================================================
 * Initialization
 * ========================================================================== */

.section .init, "ax"
.global _init

_init:
    /* Disable interrupts */
    csrci   mstatus, 0x8
    
    /* Set up stack pointer */
    la      sp, _stack_top
    
    /* Clear BSS section */
    la      t0, _bss_start
    la      t1, _bss_end
1:
    bge     t0, t1, 2f
    sw      zero, 0(t0)
    addi    t0, t0, 4
    j       1b
2:

    /* Copy initialized data from ROM to RAM */
    la      t0, _data_load
    la      t1, _data_start
    la      t2, _data_end
3:
    bge     t1, t2, 4f
    lw      t3, 0(t0)
    sw      t3, 0(t1)
    addi    t0, t0, 4
    addi    t1, t1, 4
    j       3b
4:

    /* Set up trap handler */
    la      t0, _trap_handler
    csrw    mtvec, t0
    
    /* Enable machine external interrupts */
    li      t0, 0x800       /* MIE.MEIE */
    csrs    mie, t0
    
    /* Call boot main */
    call    npu_boot_main
    
    /* Check return value */
    bnez    a0, _boot_error
    
    /* Enable interrupts */
    csrsi   mstatus, 0x8
    
    /* Enter main loop (wait for commands) */
    j       _main_loop

_boot_error:
    /* Boot failed - halt */
    j       _boot_error

/* ==========================================================================
 * Main Loop
 * ========================================================================== */

_main_loop:
    /* Wait for interrupt */
    wfi
    j       _main_loop

/* ==========================================================================
 * Trap Handler
 * ========================================================================== */

.section .text
.global _trap_handler

_trap_handler:
    /* Save context */
    addi    sp, sp, -64
    sw      ra, 0(sp)
    sw      t0, 4(sp)
    sw      t1, 8(sp)
    sw      t2, 12(sp)
    sw      a0, 16(sp)
    sw      a1, 20(sp)
    sw      a2, 24(sp)
    sw      a3, 28(sp)
    sw      a4, 32(sp)
    sw      a5, 36(sp)
    sw      a6, 40(sp)
    sw      a7, 44(sp)
    sw      t3, 48(sp)
    sw      t4, 52(sp)
    sw      t5, 56(sp)
    sw      t6, 60(sp)
    
    /* Check cause */
    csrr    t0, mcause
    bltz    t0, _handle_interrupt
    
    /* Exception - just return for now */
    j       _trap_return

_handle_interrupt:
    /* Clear MSB to get interrupt number */
    li      t1, 0x7FFFFFFF
    and     t0, t0, t1
    
    /* Check for external interrupt (11) */
    li      t1, 11
    bne     t0, t1, _trap_return
    
    /* Call NPU IRQ handler */
    call    npu_rt_irq_handler

_trap_return:
    /* Restore context */
    lw      ra, 0(sp)
    lw      t0, 4(sp)
    lw      t1, 8(sp)
    lw      t2, 12(sp)
    lw      a0, 16(sp)
    lw      a1, 20(sp)
    lw      a2, 24(sp)
    lw      a3, 28(sp)
    lw      a4, 32(sp)
    lw      a5, 36(sp)
    lw      a6, 40(sp)
    lw      a7, 44(sp)
    lw      t3, 48(sp)
    lw      t4, 52(sp)
    lw      t5, 56(sp)
    lw      t6, 60(sp)
    addi    sp, sp, 64
    
    mret

/* ==========================================================================
 * IRQ Entry (from vector table)
 * ========================================================================== */

_irq_entry:
    j       _trap_handler

.end
