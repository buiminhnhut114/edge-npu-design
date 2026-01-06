/**
 * EdgeNPU C++ API
 * Modern C++ wrapper for NPU SDK
 * 
 * Copyright (c) 2024 EdgeNPU Project
 */

#ifndef NPU_API_HPP
#define NPU_API_HPP

#include <string>
#include <vector>
#include <memory>
#include <functional>
#include <stdexcept>
#include <cstdint>

// Include C API
extern "C" {
#include "../../include/npu_sdk.h"
}

namespace npu {

// =============================================================================
// Exception
// =============================================================================

class Exception : public std::runtime_error {
public:
    explicit Exception(npu_error_t code, const std::string& msg = "")
        : std::runtime_error(msg.empty() ? get_error_string(code) : msg)
        , error_code_(code) {}
    
    npu_error_t code() const { return error_code_; }
    
    static std::string get_error_string(npu_error_t code) {
        switch (code) {
            case NPU_SUCCESS: return "Success";
            case NPU_ERR_INVALID_PARAM: return "Invalid parameter";
            case NPU_ERR_NOT_INITIALIZED: return "Not initialized";
            case NPU_ERR_OUT_OF_MEMORY: return "Out of memory";
            case NPU_ERR_MODEL_INVALID: return "Invalid model";
            case NPU_ERR_MODEL_NOT_LOADED: return "Model not loaded";
            case NPU_ERR_INFERENCE_FAILED: return "Inference failed";
            case NPU_ERR_TIMEOUT: return "Timeout";
            case NPU_ERR_HARDWARE: return "Hardware error";
            case NPU_ERR_NOT_SUPPORTED: return "Not supported";
            case NPU_ERR_FILE_NOT_FOUND: return "File not found";
            default: return "Unknown error";
        }
    }

private:
    npu_error_t error_code_;
};

inline void check_error(npu_error_t code) {
    if (code != NPU_SUCCESS) {
        throw Exception(code);
    }
}

// =============================================================================
// Tensor
// =============================================================================

template<typename T>
class Tensor {
public:
    Tensor() = default;
    
    Tensor(const std::vector<size_t>& shape) : shape_(shape) {
        size_t size = 1;
        for (auto d : shape) size *= d;
        data_.resize(size);
    }
    
    Tensor(const std::vector<size_t>& shape, const T* data) : Tensor(shape) {
        std::copy(data, data + data_.size(), data_.begin());
    }
    
    T* data() { return data_.data(); }
    const T* data() const { return data_.data(); }
    
    size_t size() const { return data_.size(); }
    size_t bytes() const { return data_.size() * sizeof(T); }
    
    const std::vector<size_t>& shape() const { return shape_; }
    
    T& operator[](size_t i) { return data_[i]; }
    const T& operator[](size_t i) const { return data_[i]; }
    
    // Reshape
    void reshape(const std::vector<size_t>& new_shape) {
        size_t new_size = 1;
        for (auto d : new_shape) new_size *= d;
        if (new_size != data_.size()) {
            throw Exception(NPU_ERR_INVALID_PARAM, "Invalid reshape size");
        }
        shape_ = new_shape;
    }

private:
    std::vector<T> data_;
    std::vector<size_t> shape_;
};

using TensorF32 = Tensor<float>;
using TensorI8 = Tensor<int8_t>;
using TensorU8 = Tensor<uint8_t>;

// =============================================================================
// Device
// =============================================================================

class Device {
public:
    explicit Device(int device_id = 0) {
        handle_ = npu_open_device(device_id);
        if (!handle_) {
            throw Exception(NPU_ERR_HARDWARE, "Failed to open device");
        }
    }
    
    ~Device() {
        if (handle_) {
            npu_close_device(handle_);
        }
    }
    
    // Non-copyable
    Device(const Device&) = delete;
    Device& operator=(const Device&) = delete;
    
    // Movable
    Device(Device&& other) noexcept : handle_(other.handle_) {
        other.handle_ = nullptr;
    }
    
    Device& operator=(Device&& other) noexcept {
        if (this != &other) {
            if (handle_) npu_close_device(handle_);
            handle_ = other.handle_;
            other.handle_ = nullptr;
        }
        return *this;
    }
    
    npu_device_t handle() const { return handle_; }
    
    npu_device_info_t get_info() const {
        npu_device_info_t info;
        check_error(npu_get_device_info(handle_, &info));
        return info;
    }
    
    void* alloc(size_t size) {
        return npu_alloc(handle_, size);
    }
    
    void free(void* ptr) {
        npu_free(handle_, ptr);
    }
    
    static int get_device_count() {
        return npu_get_device_count();
    }

private:
    npu_device_t handle_ = nullptr;
};

// =============================================================================
// Model
// =============================================================================

class Model {
public:
    Model(Device& device, const std::string& path) {
        handle_ = npu_load_model(device.handle(), path.c_str());
        if (!handle_) {
            throw Exception(NPU_ERR_MODEL_INVALID, "Failed to load model: " + path);
        }
    }
    
    Model(Device& device, const void* data, size_t size) {
        handle_ = npu_load_model_memory(device.handle(), data, size);
        if (!handle_) {
            throw Exception(NPU_ERR_MODEL_INVALID, "Failed to load model from memory");
        }
    }
    
    ~Model() {
        if (handle_) {
            npu_unload_model(handle_);
        }
    }
    
    // Non-copyable
    Model(const Model&) = delete;
    Model& operator=(const Model&) = delete;
    
    // Movable
    Model(Model&& other) noexcept : handle_(other.handle_) {
        other.handle_ = nullptr;
    }
    
    npu_model_handle_t handle() const { return handle_; }
    
    npu_model_info_t get_info() const {
        npu_model_info_t info;
        check_error(npu_get_model_info(handle_, &info));
        return info;
    }
    
    // Simple inference
    template<typename TIn, typename TOut>
    void infer(const Tensor<TIn>& input, Tensor<TOut>& output) {
        check_error(npu_infer_simple(
            handle_,
            input.data(), input.bytes(),
            output.data(), output.bytes()
        ));
    }
    
    // Float32 inference with auto quantization
    void infer_float32(const TensorF32& input, TensorF32& output) {
        check_error(npu_infer_float32(
            handle_,
            input.data(), input.size(),
            output.data(), output.size()
        ));
    }
    
    // Convenience: infer and return output
    TensorF32 infer(const TensorF32& input, const std::vector<size_t>& output_shape) {
        TensorF32 output(output_shape);
        infer_float32(input, output);
        return output;
    }

private:
    npu_model_handle_t handle_ = nullptr;
};

// =============================================================================
// Session
// =============================================================================

class Session {
public:
    explicit Session(Model& model) {
        handle_ = npu_create_session(model.handle());
        if (!handle_) {
            throw Exception(NPU_ERR_OUT_OF_MEMORY, "Failed to create session");
        }
    }
    
    ~Session() {
        if (handle_) {
            npu_destroy_session(handle_);
        }
    }
    
    // Non-copyable
    Session(const Session&) = delete;
    Session& operator=(const Session&) = delete;
    
    npu_session_t handle() const { return handle_; }
    
    template<typename T>
    void set_input(uint32_t index, const Tensor<T>& tensor) {
        check_error(npu_set_input(handle_, index, tensor.data(), tensor.bytes()));
    }
    
    void set_input_by_name(const std::string& name, const void* data, size_t size) {
        check_error(npu_set_input_by_name(handle_, name.c_str(), data, size));
    }
    
    template<typename T>
    void get_output(uint32_t index, Tensor<T>& tensor) {
        check_error(npu_get_output(handle_, index, tensor.data(), tensor.bytes()));
    }
    
    void run(const npu_infer_options_t* options = nullptr) {
        check_error(npu_run(handle_, options));
    }
    
    void run(uint32_t timeout_ms, bool profile = false) {
        npu_infer_options_t options = {};
        options.timeout_ms = timeout_ms;
        options.profile = profile;
        run(&options);
    }
    
    using Callback = std::function<void(npu_error_t)>;
    
    void run_async(Callback callback) {
        // Store callback for later invocation
        callback_ = std::move(callback);
        
        npu_infer_options_t options = {};
        options.async = true;
        
        check_error(npu_run_async(handle_, &options, 
            [](npu_error_t status, void* user_data) {
                auto* self = static_cast<Session*>(user_data);
                if (self->callback_) {
                    self->callback_(status);
                }
            }, this));
    }
    
    void wait(uint32_t timeout_ms = 0) {
        check_error(npu_wait(handle_, timeout_ms));
    }
    
    npu_profile_result_t get_profile_result() const {
        npu_profile_result_t result;
        check_error(npu_get_profile_result(handle_, &result));
        return result;
    }

private:
    npu_session_t handle_ = nullptr;
    Callback callback_;
};

// =============================================================================
// Utility functions
// =============================================================================

inline std::string get_version() {
    return npu_get_version();
}

inline int get_device_count() {
    return npu_get_device_count();
}

inline void set_debug_logging(bool enable) {
    npu_set_debug_logging(enable);
}

inline std::string get_last_error() {
    return npu_get_last_error();
}

// =============================================================================
// RAII helpers
// =============================================================================

template<typename T>
class ScopedBuffer {
public:
    ScopedBuffer(Device& device, size_t count)
        : device_(device)
        , ptr_(static_cast<T*>(device.alloc(count * sizeof(T))))
        , count_(count) {}
    
    ~ScopedBuffer() {
        if (ptr_) {
            device_.free(ptr_);
        }
    }
    
    T* get() { return ptr_; }
    const T* get() const { return ptr_; }
    size_t count() const { return count_; }
    size_t bytes() const { return count_ * sizeof(T); }
    
    T& operator[](size_t i) { return ptr_[i]; }
    const T& operator[](size_t i) const { return ptr_[i]; }

private:
    Device& device_;
    T* ptr_;
    size_t count_;
};

} // namespace npu

#endif // NPU_API_HPP
