/**
 * EdgeNPU Runtime Library
 * High-level runtime for model execution
 * 
 * Copyright (c) 2024 EdgeNPU Project
 */

#ifndef NPU_RUNTIME_H
#define NPU_RUNTIME_H

#include "npu_driver.h"

#ifdef __cplusplus
extern "C" {
#endif

/* ==========================================================================
 * Model Binary Format
 * ========================================================================== */

#define NPU_MODEL_MAGIC     0x55504E45  /* "ENPU" */
#define NPU_MODEL_VERSION   0x0100

typedef struct __attribute__((packed)) {
    uint32_t magic;             /* Magic number "ENPU" */
    uint32_t version;           /* Format version */
    uint32_t num_instructions;  /* Number of instructions */
    uint32_t instructions_size; /* Instructions size in bytes */
    uint32_t weights_size;      /* Weights size in bytes */
    uint32_t bias_size;         /* Bias size in bytes */
    uint32_t input_size;        /* Expected input size */
    uint32_t output_size;       /* Expected output size */
    uint32_t reserved[8];       /* Reserved for future use */
} npu_model_header_t;

/* ==========================================================================
 * Runtime Data Types
 * ========================================================================== */

typedef enum {
    NPU_DTYPE_INT8 = 0,
    NPU_DTYPE_UINT8,
    NPU_DTYPE_INT16,
    NPU_DTYPE_FLOAT16,
    NPU_DTYPE_FLOAT32,
} npu_dtype_t;

typedef struct {
    uint32_t dims[4];       /* NCHW format */
    uint32_t ndim;          /* Number of dimensions */
    npu_dtype_t dtype;      /* Data type */
} npu_tensor_shape_t;

typedef struct {
    void* data;
    npu_tensor_shape_t shape;
    uint32_t size;          /* Total size in bytes */
} npu_tensor_t;

typedef struct {
    float scale;
    int32_t zero_point;
} npu_quant_params_t;

/* ==========================================================================
 * Model Handle
 * ========================================================================== */

typedef struct npu_model npu_model_t;

typedef struct {
    char name[64];
    uint32_t num_instructions;
    uint32_t weights_size;
    uint32_t input_size;
    uint32_t output_size;
    npu_tensor_shape_t input_shape;
    npu_tensor_shape_t output_shape;
    npu_quant_params_t input_quant;
    npu_quant_params_t output_quant;
} npu_model_info_t;

/* ==========================================================================
 * Runtime Context
 * ========================================================================== */

typedef struct npu_runtime npu_runtime_t;

typedef struct {
    uint32_t max_models;        /* Maximum loaded models */
    uint32_t workspace_size;    /* Workspace memory size */
    bool enable_profiling;      /* Enable profiling */
    bool enable_debug;          /* Enable debug output */
} npu_runtime_config_t;

/* ==========================================================================
 * Runtime Initialization
 * ========================================================================== */

/**
 * Create runtime instance
 * @param ctx NPU driver context
 * @param config Runtime configuration
 * @return Runtime instance or NULL
 */
npu_runtime_t* npu_runtime_create(npu_context_t* ctx, 
                                   const npu_runtime_config_t* config);

/**
 * Destroy runtime instance
 * @param runtime Runtime instance
 */
void npu_runtime_destroy(npu_runtime_t* runtime);

/* ==========================================================================
 * Model Management
 * ========================================================================== */

/**
 * Load model from binary file
 * @param runtime Runtime instance
 * @param path Path to model file
 * @return Model handle or NULL
 */
npu_model_t* npu_model_load_file(npu_runtime_t* runtime, const char* path);

/**
 * Load model from memory
 * @param runtime Runtime instance
 * @param data Model binary data
 * @param size Data size
 * @return Model handle or NULL
 */
npu_model_t* npu_model_load_memory(npu_runtime_t* runtime,
                                    const void* data,
                                    uint32_t size);

/**
 * Unload model
 * @param model Model handle
 */
void npu_model_unload(npu_model_t* model);

/**
 * Get model information
 * @param model Model handle
 * @param info Output model info
 * @return Status code
 */
npu_status_t npu_model_get_info(npu_model_t* model, npu_model_info_t* info);

/* ==========================================================================
 * Inference Execution
 * ========================================================================== */

/**
 * Run inference (blocking)
 * @param model Model handle
 * @param input Input tensor
 * @param output Output tensor
 * @return Status code
 */
npu_status_t npu_infer(npu_model_t* model,
                        const npu_tensor_t* input,
                        npu_tensor_t* output);

/**
 * Run inference with float input/output (auto quantize/dequantize)
 * @param model Model handle
 * @param input Input data (float32)
 * @param input_size Input size in elements
 * @param output Output data (float32)
 * @param output_size Output size in elements
 * @return Status code
 */
npu_status_t npu_infer_float(npu_model_t* model,
                              const float* input,
                              uint32_t input_size,
                              float* output,
                              uint32_t output_size);

/**
 * Run inference async
 * @param model Model handle
 * @param input Input tensor
 * @param output Output tensor
 * @param callback Completion callback
 * @param user_data User data
 * @return Status code
 */
npu_status_t npu_infer_async(npu_model_t* model,
                              const npu_tensor_t* input,
                              npu_tensor_t* output,
                              npu_callback_t callback,
                              void* user_data);

/* ==========================================================================
 * Tensor Utilities
 * ========================================================================== */

/**
 * Create tensor
 * @param shape Tensor shape
 * @return Tensor or NULL
 */
npu_tensor_t* npu_tensor_create(const npu_tensor_shape_t* shape);

/**
 * Destroy tensor
 * @param tensor Tensor to destroy
 */
void npu_tensor_destroy(npu_tensor_t* tensor);

/**
 * Copy data to tensor
 * @param tensor Destination tensor
 * @param data Source data
 * @param size Data size
 * @return Status code
 */
npu_status_t npu_tensor_copy_from(npu_tensor_t* tensor,
                                   const void* data,
                                   uint32_t size);

/**
 * Copy data from tensor
 * @param tensor Source tensor
 * @param data Destination buffer
 * @param size Buffer size
 * @return Status code
 */
npu_status_t npu_tensor_copy_to(const npu_tensor_t* tensor,
                                 void* data,
                                 uint32_t size);

/**
 * Quantize float data to int8
 * @param input Float input
 * @param output Int8 output
 * @param size Number of elements
 * @param params Quantization parameters
 */
void npu_quantize_int8(const float* input, int8_t* output,
                        uint32_t size, const npu_quant_params_t* params);

/**
 * Dequantize int8 data to float
 * @param input Int8 input
 * @param output Float output
 * @param size Number of elements
 * @param params Quantization parameters
 */
void npu_dequantize_int8(const int8_t* input, float* output,
                          uint32_t size, const npu_quant_params_t* params);

/* ==========================================================================
 * Profiling
 * ========================================================================== */

typedef struct {
    uint64_t inference_time_us;     /* Total inference time */
    uint64_t data_load_time_us;     /* Data loading time */
    uint64_t compute_time_us;       /* Compute time */
    uint64_t data_read_time_us;     /* Result reading time */
    npu_perf_stats_t hw_stats;      /* Hardware statistics */
} npu_profile_t;

/**
 * Get profiling data from last inference
 * @param model Model handle
 * @param profile Output profile data
 * @return Status code
 */
npu_status_t npu_get_profile(npu_model_t* model, npu_profile_t* profile);

#ifdef __cplusplus
}
#endif

#endif /* NPU_RUNTIME_H */
