/**
 * EdgeNPU Firmware Linker Script
 * Memory layout for NPU firmware
 */

/* Memory regions */
MEMORY
{
    /* Firmware ROM - 64KB */
    ROM (rx)  : ORIGIN = 0x00000000, LENGTH = 64K
    
    /* Firmware RAM - 32KB */
    RAM (rwx) : ORIGIN = 0x00010000, LENGTH = 32K
    
    /* NPU Register Space */
    NPU_REGS (rw) : ORIGIN = 0x40000000, LENGTH = 4K
    
    /* NPU Instruction Buffer - 64KB */
    NPU_INST (rw) : ORIGIN = 0x40100000, LENGTH = 64K
    
    /* NPU Weight Buffer - 256KB */
    NPU_WEIGHT (rw) : ORIGIN = 0x40200000, LENGTH = 256K
    
    /* NPU Activation Buffer - 256KB */
    NPU_ACT (rw) : ORIGIN = 0x40300000, LENGTH = 256K
}

/* Entry point */
ENTRY(_start)

/* Stack size */
_stack_size = 4K;

SECTIONS
{
    /* Code section */
    .text :
    {
        _text_start = .;
        KEEP(*(.vectors))
        KEEP(*(.init))
        *(.text)
        *(.text.*)
        *(.rodata)
        *(.rodata.*)
        . = ALIGN(4);
        _text_end = .;
    } > ROM

    /* Initialized data */
    .data :
    {
        _data_start = .;
        *(.data)
        *(.data.*)
        . = ALIGN(4);
        _data_end = .;
    } > RAM AT > ROM

    _data_load = LOADADDR(.data);

    /* Uninitialized data */
    .bss (NOLOAD) :
    {
        _bss_start = .;
        *(.bss)
        *(.bss.*)
        *(COMMON)
        . = ALIGN(4);
        _bss_end = .;
    } > RAM

    /* Stack */
    .stack (NOLOAD) :
    {
        . = ALIGN(16);
        _stack_bottom = .;
        . = . + _stack_size;
        _stack_top = .;
    } > RAM

    /* NPU memory regions (for reference) */
    .npu_regs (NOLOAD) :
    {
        _npu_regs_start = .;
    } > NPU_REGS

    .npu_inst (NOLOAD) :
    {
        _npu_inst_start = .;
    } > NPU_INST

    .npu_weight (NOLOAD) :
    {
        _npu_weight_start = .;
    } > NPU_WEIGHT

    .npu_act (NOLOAD) :
    {
        _npu_act_start = .;
    } > NPU_ACT

    /* Discard unwanted sections */
    /DISCARD/ :
    {
        *(.comment)
        *(.note.*)
        *(.eh_frame*)
    }
}

/* Provide symbols for startup code */
PROVIDE(_heap_start = _bss_end);
PROVIDE(_heap_end = _stack_bottom);
