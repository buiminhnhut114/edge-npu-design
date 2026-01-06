/**
 * EdgeNPU Runtime Implementation
 * High-level runtime for model execution
 * 
 * Copyright (c) 2024 EdgeNPU Project
 */

#include "npu_runtime.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

/* ==========================================================================
 * Internal Structures
 * ========================================================================== */

struct npu_model {
    npu_runtime_t* runtime;
    npu_model_info_t info;
    
    /* Model data */
    uint64_t* instructions;
    int8_t* weights;
    int8_t* bias;
    
    /* Profiling */
    npu_profile_t profile;
    bool loaded;
};

struct npu_runtime {
    npu_context_t* npu_ctx;
    npu_runtime_config_t config;
    
    /* Model slots */
    npu_model_t** models;
    uint32_t num_models;
    
    /* Workspace */
    void* workspace;
    uint32_t workspace_size;
    
    /* State */
    bool initialized;
};

/* ==========================================================================
 * Platform Timer (customize for your platform)
 * ========================================================================== */

#ifndef NPU_PLATFORM_CUSTOM

static uint64_t get_time_us(void) {
    /* Simple cycle counter - replace with actual timer */
    static uint64_t counter = 0;
    return counter++;
}

#endif

/* ==========================================================================
 * Runtime Initialization
 * ========================================================================== */

npu_runtime_t* npu_runtime_create(npu_context_t* ctx,
                                   const npu_runtime_config_t* config) {
    if (!ctx) {
        return NULL;
    }
    
    npu_runtime_t* runtime = (npu_runtime_t*)malloc(sizeof(npu_runtime_t));
    if (!runtime) {
        return NULL;
    }
    
    memset(runtime, 0, sizeof(npu_runtime_t));
    runtime->npu_ctx = ctx;
    
    if (config) {
        memcpy(&runtime->config, config, sizeof(npu_runtime_config_t));
    } else {
        /* Default config */
        runtime->config.max_models = 8;
        runtime->config.workspace_size = 1024 * 1024;  /* 1MB */
        runtime->config.enable_profiling = false;
        runtime->config.enable_debug = false;
    }
    
    /* Allocate model slots */
    runtime->models = (npu_model_t**)calloc(runtime->config.max_models,
                                             sizeof(npu_model_t*));
    if (!runtime->models) {
        free(runtime);
        return NULL;
    }
    
    /* Allocate workspace */
    runtime->workspace = malloc(runtime->config.workspace_size);
    if (!runtime->workspace) {
        free(runtime->models);
        free(runtime);
        return NULL;
    }
    runtime->workspace_size = runtime->config.workspace_size;
    
    runtime->initialized = true;
    
    return runtime;
}

void npu_runtime_destroy(npu_runtime_t* runtime) {
    if (!runtime) {
        return;
    }
    
    /* Unload all models */
    for (uint32_t i = 0; i < runtime->config.max_models; i++) {
        if (runtime->models[i]) {
            npu_model_unload(runtime->models[i]);
        }
    }
    
    free(runtime->models);
    free(runtime->workspace);
    free(runtime);
}

/* ==========================================================================
 * Model Management
 * ========================================================================== */

static npu_model_t* allocate_model_slot(npu_runtime_t* runtime) {
    for (uint32_t i = 0; i < runtime->config.max_models; i++) {
        if (!runtime->models[i]) {
            npu_model_t* model = (npu_model_t*)calloc(1, sizeof(npu_model_t));
            if (model) {
                model->runtime = runtime;
                runtime->models[i] = model;
                runtime->num_models++;
            }
            return model;
        }
    }
    return NULL;
}

npu_model_t* npu_model_load_memory(npu_runtime_t* runtime,
                                    const void* data,
                                    uint32_t size) {
    if (!runtime || !data || size < sizeof(npu_model_header_t)) {
        return NULL;
    }
    
    const npu_model_header_t* header = (const npu_model_header_t*)data;
    
    /* Validate header */
    if (header->magic != NPU_MODEL_MAGIC) {
        if (runtime->config.enable_debug) {
            printf("Invalid model magic: 0x%08X\n", header->magic);
        }
        return NULL;
    }
    
    /* Allocate model */
    npu_model_t* model = allocate_model_slot(runtime);
    if (!model) {
        return NULL;
    }
    
    /* Parse header */
    model->info.num_instructions = header->num_instructions;
    model->info.weights_size = header->weights_size;
    model->info.input_size = header->input_size;
    model->info.output_size = header->output_size;
    
    /* Calculate offsets */
    const uint8_t* ptr = (const uint8_t*)data + sizeof(npu_model_header_t);
    
    /* Allocate and copy instructions */
    uint32_t inst_size = header->num_instructions * sizeof(uint64_t);
    model->instructions = (uint64_t*)malloc(inst_size);
    if (!model->instructions) {
        npu_model_unload(model);
        return NULL;
    }
    memcpy(model->instructions, ptr, inst_size);
    ptr += inst_size;
    
    /* Allocate and copy weights */
    if (header->weights_size > 0) {
        model->weights = (int8_t*)malloc(header->weights_size);
        if (!model->weights) {
            npu_model_unload(model);
            return NULL;
        }
        memcpy(model->weights, ptr, header->weights_size);
        ptr += header->weights_size;
    }
    
    /* Allocate and copy bias */
    if (header->bias_size > 0) {
        model->bias = (int8_t*)malloc(header->bias_size);
        if (!model->bias) {
            npu_model_unload(model);
            return NULL;
        }
        memcpy(model->bias, ptr, header->bias_size);
    }
    
    /* Default quantization params */
    model->info.input_quant.scale = 1.0f / 127.0f;
    model->info.input_quant.zero_point = 0;
    model->info.output_quant.scale = 1.0f / 127.0f;
    model->info.output_quant.zero_point = 0;
    
    model->loaded = true;
    
    if (runtime->config.enable_debug) {
        printf("Model loaded: %d instructions, %d bytes weights\n",
               model->info.num_instructions, model->info.weights_size);
    }
    
    return model;
}

npu_model_t* npu_model_load_file(npu_runtime_t* runtime, const char* path) {
    if (!runtime || !path) {
        return NULL;
    }
    
    FILE* f = fopen(path, "rb");
    if (!f) {
        if (runtime->config.enable_debug) {
            printf("Failed to open model file: %s\n", path);
        }
        return NULL;
    }
    
    /* Get file size */
    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    fseek(f, 0, SEEK_SET);
    
    /* Read file */
    void* data = malloc(size);
    if (!data) {
        fclose(f);
        return NULL;
    }
    
    if (fread(data, 1, size, f) != (size_t)size) {
        free(data);
        fclose(f);
        return NULL;
    }
    fclose(f);
    
    /* Load from memory */
    npu_model_t* model = npu_model_load_memory(runtime, data, size);
    
    /* Copy filename to model name */
    if (model) {
        const char* name = strrchr(path, '/');
        name = name ? name + 1 : path;
        strncpy(model->info.name, name, sizeof(model->info.name) - 1);
    }
    
    free(data);
    return model;
}

void npu_model_unload(npu_model_t* model) {
    if (!model) {
        return;
    }
    
    /* Remove from runtime */
    if (model->runtime) {
        for (uint32_t i = 0; i < model->runtime->config.max_models; i++) {
            if (model->runtime->models[i] == model) {
                model->runtime->models[i] = NULL;
                model->runtime->num_models--;
                break;
            }
        }
    }
    
    /* Free resources */
    free(model->instructions);
    free(model->weights);
    free(model->bias);
    free(model);
}

npu_status_t npu_model_get_info(npu_model_t* model, npu_model_info_t* info) {
    if (!model || !info) {
        return NPU_ERROR_INVALID_PARAM;
    }
    
    memcpy(info, &model->info, sizeof(npu_model_info_t));
    return NPU_OK;
}

/* ==========================================================================
 * Inference Execution
 * ========================================================================== */

npu_status_t npu_infer(npu_model_t* model,
                        const npu_tensor_t* input,
                        npu_tensor_t* output) {
    if (!model || !input || !output || !model->loaded) {
        return NPU_ERROR_INVALID_PARAM;
    }
    
    npu_runtime_t* runtime = model->runtime;
    npu_context_t* ctx = runtime->npu_ctx;
    npu_status_t status;
    
    uint64_t start_time = 0, load_time = 0, compute_time = 0;
    
    if (runtime->config.enable_profiling) {
        start_time = get_time_us();
    }
    
    /* Load instructions */
    status = npu_load_instructions(ctx, model->instructions,
                                    model->info.num_instructions);
    if (status != NPU_OK) {
        return status;
    }
    
    /* Load weights */
    if (model->weights && model->info.weights_size > 0) {
        status = npu_load_weights(ctx, model->weights, model->info.weights_size);
        if (status != NPU_OK) {
            return status;
        }
    }
    
    /* Load input */
    status = npu_load_input(ctx, (const int8_t*)input->data, input->size);
    if (status != NPU_OK) {
        return status;
    }
    
    if (runtime->config.enable_profiling) {
        load_time = get_time_us();
    }
    
    /* Run inference */
    status = npu_run(ctx, 10000);  /* 10 second timeout */
    if (status != NPU_OK) {
        return status;
    }
    
    if (runtime->config.enable_profiling) {
        compute_time = get_time_us();
    }
    
    /* Read output */
    status = npu_read_output(ctx, (int8_t*)output->data, output->size);
    if (status != NPU_OK) {
        return status;
    }
    
    /* Update profiling */
    if (runtime->config.enable_profiling) {
        uint64_t end_time = get_time_us();
        model->profile.data_load_time_us = load_time - start_time;
        model->profile.compute_time_us = compute_time - load_time;
        model->profile.data_read_time_us = end_time - compute_time;
        model->profile.inference_time_us = end_time - start_time;
        npu_get_perf_stats(ctx, &model->profile.hw_stats);
    }
    
    return NPU_OK;
}

npu_status_t npu_infer_float(npu_model_t* model,
                              const float* input,
                              uint32_t input_size,
                              float* output,
                              uint32_t output_size) {
    if (!model || !input || !output) {
        return NPU_ERROR_INVALID_PARAM;
    }
    
    /* Allocate quantized buffers */
    int8_t* input_q = (int8_t*)malloc(input_size);
    int8_t* output_q = (int8_t*)malloc(output_size);
    
    if (!input_q || !output_q) {
        free(input_q);
        free(output_q);
        return NPU_ERROR_NO_MEMORY;
    }
    
    /* Quantize input */
    npu_quantize_int8(input, input_q, input_size, &model->info.input_quant);
    
    /* Create tensors */
    npu_tensor_t input_tensor = {
        .data = input_q,
        .size = input_size
    };
    
    npu_tensor_t output_tensor = {
        .data = output_q,
        .size = output_size
    };
    
    /* Run inference */
    npu_status_t status = npu_infer(model, &input_tensor, &output_tensor);
    
    if (status == NPU_OK) {
        /* Dequantize output */
        npu_dequantize_int8(output_q, output, output_size, &model->info.output_quant);
    }
    
    free(input_q);
    free(output_q);
    
    return status;
}

npu_status_t npu_infer_async(npu_model_t* model,
                              const npu_tensor_t* input,
                              npu_tensor_t* output,
                              npu_callback_t callback,
                              void* user_data) {
    if (!model || !input || !output || !model->loaded) {
        return NPU_ERROR_INVALID_PARAM;
    }
    
    npu_context_t* ctx = model->runtime->npu_ctx;
    npu_status_t status;
    
    /* Load data */
    status = npu_load_instructions(ctx, model->instructions,
                                    model->info.num_instructions);
    if (status != NPU_OK) return status;
    
    if (model->weights) {
        status = npu_load_weights(ctx, model->weights, model->info.weights_size);
        if (status != NPU_OK) return status;
    }
    
    status = npu_load_input(ctx, (const int8_t*)input->data, input->size);
    if (status != NPU_OK) return status;
    
    /* Start async execution */
    return npu_run_async(ctx, callback, user_data);
}

/* ==========================================================================
 * Tensor Utilities
 * ========================================================================== */

static uint32_t calc_tensor_size(const npu_tensor_shape_t* shape) {
    uint32_t size = 1;
    for (uint32_t i = 0; i < shape->ndim; i++) {
        size *= shape->dims[i];
    }
    
    switch (shape->dtype) {
        case NPU_DTYPE_INT8:
        case NPU_DTYPE_UINT8:
            return size;
        case NPU_DTYPE_INT16:
        case NPU_DTYPE_FLOAT16:
            return size * 2;
        case NPU_DTYPE_FLOAT32:
            return size * 4;
        default:
            return size;
    }
}

npu_tensor_t* npu_tensor_create(const npu_tensor_shape_t* shape) {
    if (!shape) {
        return NULL;
    }
    
    npu_tensor_t* tensor = (npu_tensor_t*)malloc(sizeof(npu_tensor_t));
    if (!tensor) {
        return NULL;
    }
    
    tensor->size = calc_tensor_size(shape);
    tensor->data = malloc(tensor->size);
    
    if (!tensor->data) {
        free(tensor);
        return NULL;
    }
    
    memcpy(&tensor->shape, shape, sizeof(npu_tensor_shape_t));
    memset(tensor->data, 0, tensor->size);
    
    return tensor;
}

void npu_tensor_destroy(npu_tensor_t* tensor) {
    if (tensor) {
        free(tensor->data);
        free(tensor);
    }
}

npu_status_t npu_tensor_copy_from(npu_tensor_t* tensor,
                                   const void* data,
                                   uint32_t size) {
    if (!tensor || !data) {
        return NPU_ERROR_INVALID_PARAM;
    }
    
    uint32_t copy_size = (size < tensor->size) ? size : tensor->size;
    memcpy(tensor->data, data, copy_size);
    
    return NPU_OK;
}

npu_status_t npu_tensor_copy_to(const npu_tensor_t* tensor,
                                 void* data,
                                 uint32_t size) {
    if (!tensor || !data) {
        return NPU_ERROR_INVALID_PARAM;
    }
    
    uint32_t copy_size = (size < tensor->size) ? size : tensor->size;
    memcpy(data, tensor->data, copy_size);
    
    return NPU_OK;
}

void npu_quantize_int8(const float* input, int8_t* output,
                        uint32_t size, const npu_quant_params_t* params) {
    float scale = params->scale;
    int32_t zp = params->zero_point;
    
    for (uint32_t i = 0; i < size; i++) {
        int32_t val = (int32_t)(input[i] / scale + 0.5f) + zp;
        if (val < -128) val = -128;
        if (val > 127) val = 127;
        output[i] = (int8_t)val;
    }
}

void npu_dequantize_int8(const int8_t* input, float* output,
                          uint32_t size, const npu_quant_params_t* params) {
    float scale = params->scale;
    int32_t zp = params->zero_point;
    
    for (uint32_t i = 0; i < size; i++) {
        output[i] = ((float)input[i] - zp) * scale;
    }
}

/* ==========================================================================
 * Profiling
 * ========================================================================== */

npu_status_t npu_get_profile(npu_model_t* model, npu_profile_t* profile) {
    if (!model || !profile) {
        return NPU_ERROR_INVALID_PARAM;
    }
    
    memcpy(profile, &model->profile, sizeof(npu_profile_t));
    return NPU_OK;
}
