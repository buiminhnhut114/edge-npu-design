/**
 * EdgeNPU SDK - High-Level API
 * Easy-to-use API for AI inference on EdgeNPU
 * 
 * Copyright (c) 2024 EdgeNPU Project
 */

#ifndef NPU_SDK_H
#define NPU_SDK_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ==========================================================================
 * Version Information
 * ========================================================================== */

#define NPU_SDK_VERSION_MAJOR   1
#define NPU_SDK_VERSION_MINOR   0
#define NPU_SDK_VERSION_PATCH   0
#define NPU_SDK_VERSION_STRING  "1.0.0"

/* ==========================================================================
 * Error Codes
 * ========================================================================== */

typedef enum {
    NPU_SUCCESS = 0,
    NPU_ERR_INVALID_PARAM = -1,
    NPU_ERR_NOT_INITIALIZED = -2,
    NPU_ERR_OUT_OF_MEMORY = -3,
    NPU_ERR_MODEL_INVALID = -4,
    NPU_ERR_MODEL_NOT_LOADED = -5,
    NPU_ERR_INFERENCE_FAILED = -6,
    NPU_ERR_TIMEOUT = -7,
    NPU_ERR_HARDWARE = -8,
    NPU_ERR_NOT_SUPPORTED = -9,
    NPU_ERR_FILE_NOT_FOUND = -10,
} npu_error_t;

/* ==========================================================================
 * Data Types
 * ========================================================================== */

/* Opaque handles */
typedef struct npu_device_s* npu_device_t;
typedef struct npu_model_s* npu_model_handle_t;
typedef struct npu_session_s* npu_session_t;

/* Tensor data types */
typedef enum {
    NPU_TYPE_FLOAT32 = 0,
    NPU_TYPE_FLOAT16,
    NPU_TYPE_INT32,
    NPU_TYPE_INT16,
    NPU_TYPE_INT8,
    NPU_TYPE_UINT8,
} npu_data_type_t;

/* Tensor layout */
typedef enum {
    NPU_LAYOUT_NCHW = 0,    /* Batch, Channel, Height, Width */
    NPU_LAYOUT_NHWC,        /* Batch, Height, Width, Channel */
    NPU_LAYOUT_NC,          /* Batch, Channel (for FC layers) */
} npu_layout_t;

/* Tensor descriptor */
typedef struct {
    npu_data_type_t dtype;
    npu_layout_t layout;
    uint32_t dims[4];
    uint32_t ndim;
    const char* name;
} npu_tensor_desc_t;

/* Device information */
typedef struct {
    char name[64];
    char version[32];
    uint32_t pe_count;          /* Number of processing elements */
    uint32_t max_batch_size;
    uint32_t weight_memory_kb;
    uint32_t activation_memory_kb;
    uint32_t max_ops_per_sec;   /* Peak TOPS */
    bool supports_int8;
    bool supports_float16;
    bool supports_dynamic_shape;
} npu_device_info_t;

/* Model information */
typedef struct {
    char name[64];
    uint32_t num_inputs;
    uint32_t num_outputs;
    npu_tensor_desc_t* inputs;
    npu_tensor_desc_t* outputs;
    uint32_t weight_size;
    uint32_t estimated_flops;
} npu_model_info_t;

/* Inference options */
typedef struct {
    uint32_t timeout_ms;        /* Inference timeout (0 = infinite) */
    bool async;                 /* Async execution */
    bool profile;               /* Enable profiling */
    int priority;               /* Execution priority */
} npu_infer_options_t;

/* Profiling results */
typedef struct {
    uint64_t total_time_us;
    uint64_t preprocess_time_us;
    uint64_t inference_time_us;
    uint64_t postprocess_time_us;
    uint64_t mac_operations;
    float utilization_percent;
    float power_mw;             /* Estimated power consumption */
} npu_profile_result_t;

/* Callback for async inference */
typedef void (*npu_infer_callback_t)(npu_error_t status, void* user_data);

/* ==========================================================================
 * Device Management
 * ========================================================================== */

/**
 * Get SDK version string
 * @return Version string
 */
const char* npu_get_version(void);

/**
 * Get number of available NPU devices
 * @return Number of devices
 */
int npu_get_device_count(void);

/**
 * Open NPU device
 * @param device_id Device index (0 for first device)
 * @return Device handle or NULL on error
 */
npu_device_t npu_open_device(int device_id);

/**
 * Close NPU device
 * @param device Device handle
 */
void npu_close_device(npu_device_t device);

/**
 * Get device information
 * @param device Device handle
 * @param info Output device info
 * @return Error code
 */
npu_error_t npu_get_device_info(npu_device_t device, npu_device_info_t* info);

/* ==========================================================================
 * Model Management
 * ========================================================================== */

/**
 * Load model from file
 * @param device Device handle
 * @param path Path to model file (.npu format)
 * @return Model handle or NULL on error
 */
npu_model_handle_t npu_load_model(npu_device_t device, const char* path);

/**
 * Load model from memory
 * @param device Device handle
 * @param data Model binary data
 * @param size Data size in bytes
 * @return Model handle or NULL on error
 */
npu_model_handle_t npu_load_model_memory(npu_device_t device,
                                          const void* data,
                                          size_t size);

/**
 * Unload model
 * @param model Model handle
 */
void npu_unload_model(npu_model_handle_t model);

/**
 * Get model information
 * @param model Model handle
 * @param info Output model info
 * @return Error code
 */
npu_error_t npu_get_model_info(npu_model_handle_t model, npu_model_info_t* info);

/* ==========================================================================
 * Session Management
 * ========================================================================== */

/**
 * Create inference session
 * @param model Model handle
 * @return Session handle or NULL on error
 */
npu_session_t npu_create_session(npu_model_handle_t model);

/**
 * Destroy inference session
 * @param session Session handle
 */
void npu_destroy_session(npu_session_t session);

/* ==========================================================================
 * Inference API
 * ========================================================================== */

/**
 * Set input tensor data
 * @param session Session handle
 * @param index Input index
 * @param data Input data pointer
 * @param size Data size in bytes
 * @return Error code
 */
npu_error_t npu_set_input(npu_session_t session,
                           uint32_t index,
                           const void* data,
                           size_t size);

/**
 * Set input tensor by name
 * @param session Session handle
 * @param name Input tensor name
 * @param data Input data pointer
 * @param size Data size in bytes
 * @return Error code
 */
npu_error_t npu_set_input_by_name(npu_session_t session,
                                   const char* name,
                                   const void* data,
                                   size_t size);

/**
 * Get output tensor data
 * @param session Session handle
 * @param index Output index
 * @param data Output buffer
 * @param size Buffer size
 * @return Error code
 */
npu_error_t npu_get_output(npu_session_t session,
                            uint32_t index,
                            void* data,
                            size_t size);

/**
 * Get output tensor by name
 * @param session Session handle
 * @param name Output tensor name
 * @param data Output buffer
 * @param size Buffer size
 * @return Error code
 */
npu_error_t npu_get_output_by_name(npu_session_t session,
                                    const char* name,
                                    void* data,
                                    size_t size);

/**
 * Run inference (blocking)
 * @param session Session handle
 * @param options Inference options (NULL for defaults)
 * @return Error code
 */
npu_error_t npu_run(npu_session_t session, const npu_infer_options_t* options);

/**
 * Run inference (async)
 * @param session Session handle
 * @param options Inference options
 * @param callback Completion callback
 * @param user_data User data for callback
 * @return Error code
 */
npu_error_t npu_run_async(npu_session_t session,
                           const npu_infer_options_t* options,
                           npu_infer_callback_t callback,
                           void* user_data);

/**
 * Wait for async inference completion
 * @param session Session handle
 * @param timeout_ms Timeout in milliseconds
 * @return Error code
 */
npu_error_t npu_wait(npu_session_t session, uint32_t timeout_ms);

/* ==========================================================================
 * Convenience Functions
 * ========================================================================== */

/**
 * Simple inference (single input, single output)
 * Combines set_input, run, get_output in one call
 * 
 * @param model Model handle
 * @param input Input data
 * @param input_size Input size
 * @param output Output buffer
 * @param output_size Output buffer size
 * @return Error code
 */
npu_error_t npu_infer_simple(npu_model_handle_t model,
                              const void* input,
                              size_t input_size,
                              void* output,
                              size_t output_size);

/**
 * Inference with float32 input/output
 * Handles quantization automatically
 * 
 * @param model Model handle
 * @param input Float32 input data
 * @param input_count Number of input elements
 * @param output Float32 output buffer
 * @param output_count Number of output elements
 * @return Error code
 */
npu_error_t npu_infer_float32(npu_model_handle_t model,
                               const float* input,
                               size_t input_count,
                               float* output,
                               size_t output_count);

/* ==========================================================================
 * Profiling & Debug
 * ========================================================================== */

/**
 * Get profiling results from last inference
 * @param session Session handle
 * @param result Output profiling results
 * @return Error code
 */
npu_error_t npu_get_profile_result(npu_session_t session,
                                    npu_profile_result_t* result);

/**
 * Enable/disable debug logging
 * @param enable Enable flag
 */
void npu_set_debug_logging(bool enable);

/**
 * Get last error message
 * @return Error message string
 */
const char* npu_get_last_error(void);

/* ==========================================================================
 * Memory Management
 * ========================================================================== */

/**
 * Allocate NPU-accessible memory
 * @param device Device handle
 * @param size Size in bytes
 * @return Memory pointer or NULL
 */
void* npu_alloc(npu_device_t device, size_t size);

/**
 * Free NPU-accessible memory
 * @param device Device handle
 * @param ptr Memory pointer
 */
void npu_free(npu_device_t device, void* ptr);

#ifdef __cplusplus
}
#endif

/* ==========================================================================
 * C++ Wrapper (optional)
 * ========================================================================== */

#ifdef __cplusplus

#include <string>
#include <vector>
#include <memory>
#include <functional>

namespace npu {

class Device {
public:
    Device(int device_id = 0) : handle_(npu_open_device(device_id)) {}
    ~Device() { if (handle_) npu_close_device(handle_); }
    
    bool is_valid() const { return handle_ != nullptr; }
    npu_device_t get() const { return handle_; }
    
    npu_device_info_t get_info() const {
        npu_device_info_t info;
        npu_get_device_info(handle_, &info);
        return info;
    }
    
private:
    npu_device_t handle_;
};

class Model {
public:
    Model(Device& device, const std::string& path) 
        : handle_(npu_load_model(device.get(), path.c_str())) {}
    
    Model(Device& device, const void* data, size_t size)
        : handle_(npu_load_model_memory(device.get(), data, size)) {}
    
    ~Model() { if (handle_) npu_unload_model(handle_); }
    
    bool is_valid() const { return handle_ != nullptr; }
    npu_model_handle_t get() const { return handle_; }
    
    npu_error_t infer(const void* input, size_t input_size,
                      void* output, size_t output_size) {
        return npu_infer_simple(handle_, input, input_size, output, output_size);
    }
    
    npu_error_t infer(const std::vector<float>& input,
                      std::vector<float>& output) {
        return npu_infer_float32(handle_, input.data(), input.size(),
                                  output.data(), output.size());
    }
    
private:
    npu_model_handle_t handle_;
};

class Session {
public:
    Session(Model& model) : handle_(npu_create_session(model.get())) {}
    ~Session() { if (handle_) npu_destroy_session(handle_); }
    
    bool is_valid() const { return handle_ != nullptr; }
    
    npu_error_t set_input(uint32_t index, const void* data, size_t size) {
        return npu_set_input(handle_, index, data, size);
    }
    
    npu_error_t get_output(uint32_t index, void* data, size_t size) {
        return npu_get_output(handle_, index, data, size);
    }
    
    npu_error_t run(const npu_infer_options_t* options = nullptr) {
        return npu_run(handle_, options);
    }
    
    npu_profile_result_t get_profile() {
        npu_profile_result_t result;
        npu_get_profile_result(handle_, &result);
        return result;
    }
    
private:
    npu_session_t handle_;
};

} // namespace npu

#endif /* __cplusplus */

#endif /* NPU_SDK_H */
