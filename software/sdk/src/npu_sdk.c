/**
 * EdgeNPU SDK Implementation
 * High-Level API for AI inference
 * 
 * Copyright (c) 2024 EdgeNPU Project
 */

#include "npu_sdk.h"
#include "npu_runtime.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

/* ==========================================================================
 * Internal Structures
 * ========================================================================== */

struct npu_device_s {
    npu_context_t* driver_ctx;
    npu_runtime_t* runtime;
    npu_device_info_t info;
    bool initialized;
};

struct npu_model_s {
    npu_device_t device;
    npu_model_t* runtime_model;
    npu_model_info_t info;
    bool loaded;
};

struct npu_session_s {
    npu_model_handle_t model;
    void* input_buffer;
    void* output_buffer;
    uint32_t input_size;
    uint32_t output_size;
    npu_profile_result_t profile;
    bool has_input;
};

/* Global state */
static bool g_debug_logging = false;
static char g_last_error[256] = {0};

/* ==========================================================================
 * Helper Functions
 * ========================================================================== */

static void set_error(const char* msg) {
    strncpy(g_last_error, msg, sizeof(g_last_error) - 1);
    if (g_debug_logging) {
        fprintf(stderr, "[NPU SDK] Error: %s\n", msg);
    }
}

static void debug_log(const char* fmt, ...) {
    if (g_debug_logging) {
        va_list args;
        va_start(args, fmt);
        fprintf(stderr, "[NPU SDK] ");
        vfprintf(stderr, fmt, args);
        fprintf(stderr, "\n");
        va_end(args);
    }
}

/* ==========================================================================
 * Version & Device Discovery
 * ========================================================================== */

const char* npu_get_version(void) {
    return NPU_SDK_VERSION_STRING;
}

int npu_get_device_count(void) {
    /* For now, assume single device */
    return 1;
}

/* ==========================================================================
 * Device Management
 * ========================================================================== */

npu_device_t npu_open_device(int device_id) {
    if (device_id != 0) {
        set_error("Invalid device ID");
        return NULL;
    }
    
    npu_device_t device = (npu_device_t)calloc(1, sizeof(struct npu_device_s));
    if (!device) {
        set_error("Out of memory");
        return NULL;
    }
    
    /* Configure driver */
    npu_config_t config = {
        .base_addr = NPU_BASE_ADDR,
        .inst_buf_addr = 0x40100000,
        .inst_buf_size = 64 * 1024,      /* 64KB */
        .weight_buf_addr = 0x40200000,
        .weight_buf_size = 2 * 1024 * 1024,  /* 2MB */
        .act_buf_addr = 0x40400000,
        .act_buf_size = 1 * 1024 * 1024,     /* 1MB */
    };
    
    device->driver_ctx = npu_init(&config);
    if (!device->driver_ctx) {
        set_error("Failed to initialize NPU driver");
        free(device);
        return NULL;
    }
    
    /* Create runtime */
    npu_runtime_config_t rt_config = {
        .max_models = 8,
        .workspace_size = 1024 * 1024,
        .enable_profiling = true,
        .enable_debug = g_debug_logging,
    };
    
    device->runtime = npu_runtime_create(device->driver_ctx, &rt_config);
    if (!device->runtime) {
        set_error("Failed to create runtime");
        npu_deinit(device->driver_ctx);
        free(device);
        return NULL;
    }
    
    /* Get hardware info */
    npu_hw_info_t hw_info;
    npu_get_hw_info(device->driver_ctx, &hw_info);
    
    strcpy(device->info.name, "EdgeNPU");
    snprintf(device->info.version, sizeof(device->info.version), 
             "%d.%d", (hw_info.hw_version >> 8) & 0xFF, hw_info.hw_version & 0xFF);
    device->info.pe_count = hw_info.pe_array_size * hw_info.pe_array_size;
    device->info.max_batch_size = 16;
    device->info.weight_memory_kb = hw_info.weight_buf_kb;
    device->info.activation_memory_kb = hw_info.act_buf_kb;
    device->info.max_ops_per_sec = device->info.pe_count * 500;  /* 500MHz assumed */
    device->info.supports_int8 = true;
    device->info.supports_float16 = false;
    device->info.supports_dynamic_shape = false;
    
    device->initialized = true;
    
    return device;
}

void npu_close_device(npu_device_t device) {
    if (!device) return;
    
    if (device->runtime) {
        npu_runtime_destroy(device->runtime);
    }
    if (device->driver_ctx) {
        npu_deinit(device->driver_ctx);
    }
    free(device);
}

npu_error_t npu_get_device_info(npu_device_t device, npu_device_info_t* info) {
    if (!device || !info) {
        return NPU_ERR_INVALID_PARAM;
    }
    memcpy(info, &device->info, sizeof(npu_device_info_t));
    return NPU_SUCCESS;
}

/* ==========================================================================
 * Model Management
 * ========================================================================== */

npu_model_handle_t npu_load_model(npu_device_t device, const char* path) {
    if (!device || !path) {
        set_error("Invalid parameters");
        return NULL;
    }
    
    npu_model_handle_t model = (npu_model_handle_t)calloc(1, sizeof(struct npu_model_s));
    if (!model) {
        set_error("Out of memory");
        return NULL;
    }
    
    model->device = device;
    model->runtime_model = npu_model_load_file(device->runtime, path);
    
    if (!model->runtime_model) {
        set_error("Failed to load model file");
        free(model);
        return NULL;
    }
    
    /* Get model info */
    npu_model_info_t rt_info;
    npu_model_get_info(model->runtime_model, &rt_info);
    
    strncpy(model->info.name, rt_info.name, sizeof(model->info.name));
    model->info.num_inputs = 1;
    model->info.num_outputs = 1;
    model->info.weight_size = rt_info.weights_size;
    
    model->loaded = true;
    
    return model;
}

npu_model_handle_t npu_load_model_memory(npu_device_t device,
                                          const void* data,
                                          size_t size) {
    if (!device || !data || size == 0) {
        set_error("Invalid parameters");
        return NULL;
    }
    
    npu_model_handle_t model = (npu_model_handle_t)calloc(1, sizeof(struct npu_model_s));
    if (!model) {
        set_error("Out of memory");
        return NULL;
    }
    
    model->device = device;
    model->runtime_model = npu_model_load_memory(device->runtime, data, size);
    
    if (!model->runtime_model) {
        set_error("Failed to load model from memory");
        free(model);
        return NULL;
    }
    
    model->loaded = true;
    return model;
}

void npu_unload_model(npu_model_handle_t model) {
    if (!model) return;
    
    if (model->runtime_model) {
        npu_model_unload(model->runtime_model);
    }
    free(model);
}

npu_error_t npu_get_model_info(npu_model_handle_t model, npu_model_info_t* info) {
    if (!model || !info) {
        return NPU_ERR_INVALID_PARAM;
    }
    memcpy(info, &model->info, sizeof(npu_model_info_t));
    return NPU_SUCCESS;
}

/* ==========================================================================
 * Session Management
 * ========================================================================== */

npu_session_t npu_create_session(npu_model_handle_t model) {
    if (!model || !model->loaded) {
        set_error("Invalid model");
        return NULL;
    }
    
    npu_session_t session = (npu_session_t)calloc(1, sizeof(struct npu_session_s));
    if (!session) {
        set_error("Out of memory");
        return NULL;
    }
    
    session->model = model;
    
    /* Get sizes from model info */
    npu_model_info_t rt_info;
    npu_model_get_info(model->runtime_model, &rt_info);
    
    session->input_size = rt_info.input_size;
    session->output_size = rt_info.output_size;
    
    /* Allocate buffers */
    session->input_buffer = malloc(session->input_size);
    session->output_buffer = malloc(session->output_size);
    
    if (!session->input_buffer || !session->output_buffer) {
        free(session->input_buffer);
        free(session->output_buffer);
        free(session);
        set_error("Out of memory for buffers");
        return NULL;
    }
    
    return session;
}

void npu_destroy_session(npu_session_t session) {
    if (!session) return;
    
    free(session->input_buffer);
    free(session->output_buffer);
    free(session);
}

/* ==========================================================================
 * Inference API
 * ========================================================================== */

npu_error_t npu_set_input(npu_session_t session,
                           uint32_t index,
                           const void* data,
                           size_t size) {
    if (!session || !data || index != 0) {
        return NPU_ERR_INVALID_PARAM;
    }
    
    size_t copy_size = (size < session->input_size) ? size : session->input_size;
    memcpy(session->input_buffer, data, copy_size);
    session->has_input = true;
    
    return NPU_SUCCESS;
}

npu_error_t npu_set_input_by_name(npu_session_t session,
                                   const char* name,
                                   const void* data,
                                   size_t size) {
    /* For now, just use index 0 */
    (void)name;
    return npu_set_input(session, 0, data, size);
}

npu_error_t npu_get_output(npu_session_t session,
                            uint32_t index,
                            void* data,
                            size_t size) {
    if (!session || !data || index != 0) {
        return NPU_ERR_INVALID_PARAM;
    }
    
    size_t copy_size = (size < session->output_size) ? size : session->output_size;
    memcpy(data, session->output_buffer, copy_size);
    
    return NPU_SUCCESS;
}

npu_error_t npu_get_output_by_name(npu_session_t session,
                                    const char* name,
                                    void* data,
                                    size_t size) {
    (void)name;
    return npu_get_output(session, 0, data, size);
}

npu_error_t npu_run(npu_session_t session, const npu_infer_options_t* options) {
    if (!session || !session->has_input) {
        return NPU_ERR_INVALID_PARAM;
    }
    
    npu_tensor_t input = {
        .data = session->input_buffer,
        .size = session->input_size
    };
    
    npu_tensor_t output = {
        .data = session->output_buffer,
        .size = session->output_size
    };
    
    npu_status_t status = npu_infer(session->model->runtime_model, &input, &output);
    
    if (status != NPU_OK) {
        set_error("Inference failed");
        return NPU_ERR_INFERENCE_FAILED;
    }
    
    /* Get profiling if enabled */
    if (options && options->profile) {
        npu_profile_t profile;
        npu_get_profile(session->model->runtime_model, &profile);
        
        session->profile.total_time_us = profile.inference_time_us;
        session->profile.preprocess_time_us = profile.data_load_time_us;
        session->profile.inference_time_us = profile.compute_time_us;
        session->profile.postprocess_time_us = profile.data_read_time_us;
        session->profile.mac_operations = profile.hw_stats.mac_operations;
        session->profile.utilization_percent = profile.hw_stats.utilization;
    }
    
    return NPU_SUCCESS;
}

npu_error_t npu_run_async(npu_session_t session,
                           const npu_infer_options_t* options,
                           npu_infer_callback_t callback,
                           void* user_data) {
    (void)options;
    (void)callback;
    (void)user_data;
    
    /* For now, just run synchronously */
    return npu_run(session, options);
}

npu_error_t npu_wait(npu_session_t session, uint32_t timeout_ms) {
    (void)session;
    (void)timeout_ms;
    /* Already complete for sync execution */
    return NPU_SUCCESS;
}

/* ==========================================================================
 * Convenience Functions
 * ========================================================================== */

npu_error_t npu_infer_simple(npu_model_handle_t model,
                              const void* input,
                              size_t input_size,
                              void* output,
                              size_t output_size) {
    if (!model || !input || !output) {
        return NPU_ERR_INVALID_PARAM;
    }
    
    npu_session_t session = npu_create_session(model);
    if (!session) {
        return NPU_ERR_OUT_OF_MEMORY;
    }
    
    npu_error_t err = npu_set_input(session, 0, input, input_size);
    if (err != NPU_SUCCESS) {
        npu_destroy_session(session);
        return err;
    }
    
    err = npu_run(session, NULL);
    if (err != NPU_SUCCESS) {
        npu_destroy_session(session);
        return err;
    }
    
    err = npu_get_output(session, 0, output, output_size);
    npu_destroy_session(session);
    
    return err;
}

npu_error_t npu_infer_float32(npu_model_handle_t model,
                               const float* input,
                               size_t input_count,
                               float* output,
                               size_t output_count) {
    if (!model || !input || !output) {
        return NPU_ERR_INVALID_PARAM;
    }
    
    npu_status_t status = npu_infer_float(model->runtime_model,
                                           input, input_count,
                                           output, output_count);
    
    return (status == NPU_OK) ? NPU_SUCCESS : NPU_ERR_INFERENCE_FAILED;
}

/* ==========================================================================
 * Profiling & Debug
 * ========================================================================== */

npu_error_t npu_get_profile_result(npu_session_t session,
                                    npu_profile_result_t* result) {
    if (!session || !result) {
        return NPU_ERR_INVALID_PARAM;
    }
    
    memcpy(result, &session->profile, sizeof(npu_profile_result_t));
    return NPU_SUCCESS;
}

void npu_set_debug_logging(bool enable) {
    g_debug_logging = enable;
}

const char* npu_get_last_error(void) {
    return g_last_error;
}

/* ==========================================================================
 * Memory Management
 * ========================================================================== */

void* npu_alloc(npu_device_t device, size_t size) {
    (void)device;
    return malloc(size);
}

void npu_free(npu_device_t device, void* ptr) {
    (void)device;
    free(ptr);
}
