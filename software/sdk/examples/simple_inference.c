/**
 * EdgeNPU SDK - Simple Inference Example
 * 
 * Demonstrates basic model loading and inference
 */

#include "npu_sdk.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Example: Image classification with MobileNet */
#define INPUT_SIZE  (224 * 224 * 3)  /* RGB image */
#define OUTPUT_SIZE 1000             /* ImageNet classes */

int main(int argc, char* argv[]) {
    const char* model_path = (argc > 1) ? argv[1] : "mobilenet.npu";
    
    printf("EdgeNPU SDK Example - Simple Inference\n");
    printf("SDK Version: %s\n\n", npu_get_version());
    
    /* Enable debug logging */
    npu_set_debug_logging(true);
    
    /* 1. Open device */
    printf("Opening NPU device...\n");
    npu_device_t device = npu_open_device(0);
    if (!device) {
        fprintf(stderr, "Failed to open device: %s\n", npu_get_last_error());
        return 1;
    }
    
    /* Print device info */
    npu_device_info_t dev_info;
    npu_get_device_info(device, &dev_info);
    printf("Device: %s v%s\n", dev_info.name, dev_info.version);
    printf("  PE Count: %d\n", dev_info.pe_count);
    printf("  Weight Memory: %d KB\n", dev_info.weight_memory_kb);
    printf("  Activation Memory: %d KB\n\n", dev_info.activation_memory_kb);
    
    /* 2. Load model */
    printf("Loading model: %s\n", model_path);
    npu_model_handle_t model = npu_load_model(device, model_path);
    if (!model) {
        fprintf(stderr, "Failed to load model: %s\n", npu_get_last_error());
        npu_close_device(device);
        return 1;
    }
    
    /* 3. Prepare input data (dummy data for example) */
    float* input = (float*)malloc(INPUT_SIZE * sizeof(float));
    float* output = (float*)malloc(OUTPUT_SIZE * sizeof(float));
    
    /* Fill with dummy data (normally would be preprocessed image) */
    for (int i = 0; i < INPUT_SIZE; i++) {
        input[i] = (float)(i % 256) / 255.0f;
    }
