/**
 * EdgeNPU Firmware - Layer Execution
 * Layer-specific execution routines
 * 
 * Copyright (c) 2024 EdgeNPU Project
 */

#include "npu_runtime_fw.h"
#include "../include/npu_fw_regs.h"
#include "../include/npu_fw_inst.h"

/* ==========================================================================
 * Private Helpers
 * ========================================================================== */

static void configure_layer_regs(const layer_desc_t *layer)
{
    REG_WRITE(REG_LAYER_TYPE, layer->type);
    REG_WRITE(REG_LAYER_IN_CH, layer->input.c);
    REG_WRITE(REG_LAYER_OUT_CH, layer->output.c);
    REG_WRITE(REG_LAYER_IN_H, layer->input.h);
    REG_WRITE(REG_LAYER_IN_W, layer->input.w);
    REG_WRITE(REG_LAYER_OUT_H, layer->output.h);
    REG_WRITE(REG_LAYER_OUT_W, layer->output.w);
    REG_WRITE(REG_LAYER_KERNEL, (layer->kernel_h << 8) | layer->kernel_w);
    REG_WRITE(REG_LAYER_STRIDE, (layer->stride_h << 8) | layer->stride_w);
    REG_WRITE(REG_LAYER_PADDING, 
        (layer->pad_top << 24) | (layer->pad_bottom << 16) | 
        (layer->pad_left << 8) | layer->pad_right);
    REG_WRITE(REG_LAYER_ACT_TYPE, layer->activation);
    REG_WRITE(REG_LAYER_QUANT_SCALE, layer->output_scale);
    REG_WRITE(REG_LAYER_QUANT_ZERO, layer->output_zero_point);
}

static uint8_t get_activation_flags(activation_type_t act)
{
    switch (act) {
        case ACT_RELU:
        case ACT_RELU6:
            return FLAG_RELU;
        default:
            return 0;
    }
}

/* ==========================================================================
 * Layer Execution
 * ========================================================================== */

fw_status_t npu_rt_exec_layer(const layer_desc_t *layer)
{
    if (!layer) return FW_ERROR_INVALID_PARAM;
    
    switch (layer->type) {
        case LAYER_CONV2D:
        case LAYER_DWCONV2D:
            return npu_rt_exec_conv(layer);
        case LAYER_FC:
            return npu_rt_exec_fc(layer);
        case LAYER_MAXPOOL:
        case LAYER_AVGPOOL:
        case LAYER_GLOBAL_AVGPOOL:
            return npu_rt_exec_pool(layer);
        default:
            return FW_ERROR_INVALID_OP;
    }
}

fw_status_t npu_rt_exec_conv(const layer_desc_t *layer)
{
    if (!layer) return FW_ERROR_INVALID_PARAM;
    
    /* Configure layer registers */
    configure_layer_regs(layer);
    
    /* Calculate tiling parameters */
    uint32_t in_ch = layer->input.c;
    uint32_t out_ch = layer->output.c;
    uint32_t in_h = layer->input.h;
    uint32_t in_w = layer->input.w;
    uint32_t out_h = layer->output.h;
    uint32_t out_w = layer->output.w;
    uint32_t k_h = layer->kernel_h;
    uint32_t k_w = layer->kernel_w;
    
    /* Tile sizes based on PE array */
    uint32_t tile_oc = NPU_PE_COLS;
    uint32_t tile_ic = NPU_PE_ROWS;
    
    /* Build instruction sequence */
    uint64_t inst_buf[256];
    uint32_t inst_idx = 0;
    
    /* Clear accumulators */
    inst_buf[inst_idx++] = INST_CLEAR_ACC();
    
    /* Loop over output channels */
    uint32_t oc_tiles = (out_ch + tile_oc - 1) / tile_oc;
    uint32_t ic_tiles = (in_ch + tile_ic - 1) / tile_ic;
    
    for (uint32_t oc_t = 0; oc_t < oc_tiles; oc_t++) {
        uint32_t oc_start = oc_t * tile_oc;
        uint32_t oc_end = (oc_start + tile_oc > out_ch) ? out_ch : oc_start + tile_oc;
        uint32_t oc_count = oc_end - oc_start;
        
        /* Load weights for this output channel tile */
        uint32_t weight_offset = oc_start * in_ch * k_h * k_w;
        uint32_t weight_size = oc_count * in_ch * k_h * k_w;
        inst_buf[inst_idx++] = INST_DMA_LOAD_W(
            layer->weight.addr + weight_offset,
            0,
            weight_size
        );
        inst_buf[inst_idx++] = INST_WAIT_DMA();
        
        /* Loop over input channels */
        for (uint32_t ic_t = 0; ic_t < ic_tiles; ic_t++) {
            /* Load weights to PE array */
            inst_buf[inst_idx++] = INST_LOAD_WEIGHT(0, oc_count);
            
            /* Compute */
            uint8_t flags = (ic_t == ic_tiles - 1) ? get_activation_flags(layer->activation) : 0;
            inst_buf[inst_idx++] = INST_COMPUTE(flags);
        }
        
        /* Drain results */
        uint32_t out_offset = oc_start * out_h * out_w;
        inst_buf[inst_idx++] = INST_DRAIN(layer->output.addr + out_offset);
        
        /* Clear accumulators for next tile */
        if (oc_t < oc_tiles - 1) {
            inst_buf[inst_idx++] = INST_CLEAR_ACC();
        }
    }
    
    /* Halt */
    inst_buf[inst_idx++] = INST_HALT();
    
    /* Load and execute instructions */
    fw_status_t status = npu_rt_load_instructions(inst_buf, inst_idx);
    if (status != FW_OK) return status;
    
    status = npu_rt_start();
    if (status != FW_OK) return status;
    
    return npu_rt_wait(0);  /* Wait indefinitely */
}

fw_status_t npu_rt_exec_fc(const layer_desc_t *layer)
{
    if (!layer) return FW_ERROR_INVALID_PARAM;
    
    /* FC is essentially a 1x1 convolution */
    layer_desc_t fc_as_conv = *layer;
    fc_as_conv.type = LAYER_CONV2D;
    fc_as_conv.kernel_h = 1;
    fc_as_conv.kernel_w = 1;
    fc_as_conv.stride_h = 1;
    fc_as_conv.stride_w = 1;
    fc_as_conv.pad_top = 0;
    fc_as_conv.pad_bottom = 0;
    fc_as_conv.pad_left = 0;
    fc_as_conv.pad_right = 0;
    
    /* Reshape input to 1x1xC */
    fc_as_conv.input.h = 1;
    fc_as_conv.input.w = 1;
    fc_as_conv.input.c = layer->input.c * layer->input.h * layer->input.w;
    fc_as_conv.output.h = 1;
    fc_as_conv.output.w = 1;
    
    return npu_rt_exec_conv(&fc_as_conv);
}

fw_status_t npu_rt_exec_pool(const layer_desc_t *layer)
{
    if (!layer) return FW_ERROR_INVALID_PARAM;
    
    /* Configure layer registers */
    configure_layer_regs(layer);
    REG_WRITE(REG_LAYER_POOL_TYPE, 
        layer->type == LAYER_MAXPOOL ? POOL_TYPE_MAX : 
        layer->type == LAYER_GLOBAL_AVGPOOL ? POOL_TYPE_GLOBAL_AVG : POOL_TYPE_AVG);
    
    /* Build instruction sequence */
    uint64_t inst_buf[32];
    uint32_t inst_idx = 0;
    
    /* Load input */
    uint32_t in_size = TENSOR_BYTES(layer->input);
    inst_buf[inst_idx++] = INST_DMA_LOAD_A(layer->input.addr, 0, in_size);
    inst_buf[inst_idx++] = INST_WAIT_DMA();
    
    /* Execute pooling */
    uint8_t pool_op = (layer->type == LAYER_MAXPOOL) ? OP_MAXPOOL : OP_AVGPOOL;
    if (layer->type == LAYER_GLOBAL_AVGPOOL) {
        pool_op = OP_GLOBAL_AVGPOOL;
    }
    
    inst_buf[inst_idx++] = MAKE_INST(pool_op, 0,
        ((uint64_t)layer->pool_h) | 
        ((uint64_t)layer->pool_w << 8) |
        ((uint64_t)layer->pool_stride_h << 16) |
        ((uint64_t)layer->pool_stride_w << 24));
    
    /* Store output */
    uint32_t out_size = TENSOR_BYTES(layer->output);
    inst_buf[inst_idx++] = INST_DMA_STORE(0, layer->output.addr, out_size);
    inst_buf[inst_idx++] = INST_WAIT_DMA();
    
    /* Halt */
    inst_buf[inst_idx++] = INST_HALT();
    
    /* Load and execute */
    fw_status_t status = npu_rt_load_instructions(inst_buf, inst_idx);
    if (status != FW_OK) return status;
    
    status = npu_rt_start();
    if (status != FW_OK) return status;
    
    return npu_rt_wait(0);
}

fw_status_t npu_rt_exec_eltwise(const layer_desc_t *layer, const tensor_desc_t *input2)
{
    if (!layer || !input2) return FW_ERROR_INVALID_PARAM;
    
    /* Configure layer registers */
    configure_layer_regs(layer);
    
    /* Build instruction sequence */
    uint64_t inst_buf[32];
    uint32_t inst_idx = 0;
    
    /* Load first input */
    uint32_t in_size = TENSOR_BYTES(layer->input);
    inst_buf[inst_idx++] = INST_DMA_LOAD_A(layer->input.addr, 0, in_size);
    inst_buf[inst_idx++] = INST_WAIT_DMA();
    
    /* Load second input to different offset */
    inst_buf[inst_idx++] = INST_DMA_LOAD_A(input2->addr, in_size, in_size);
    inst_buf[inst_idx++] = INST_WAIT_DMA();
    
    /* Execute element-wise add */
    inst_buf[inst_idx++] = MAKE_INST(OP_ADD, get_activation_flags(layer->activation), 0);
    
    /* Store output */
    uint32_t out_size = TENSOR_BYTES(layer->output);
    inst_buf[inst_idx++] = INST_DMA_STORE(0, layer->output.addr, out_size);
    inst_buf[inst_idx++] = INST_WAIT_DMA();
    
    /* Halt */
    inst_buf[inst_idx++] = INST_HALT();
    
    /* Load and execute */
    fw_status_t status = npu_rt_load_instructions(inst_buf, inst_idx);
    if (status != FW_OK) return status;
    
    status = npu_rt_start();
    if (status != FW_OK) return status;
    
    return npu_rt_wait(0);
}
