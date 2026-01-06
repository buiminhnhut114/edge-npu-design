/**
 * EdgeNPU SDK - Batch Inference Example
 * 
 * Demonstrates batch processing with sessions
 */

#include "npu_sdk.h"
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#define BATCH_SIZE  10
#define INPUT_SIZE  (224 * 224 * 3)
#define OUTPUT_SIZE 1000

int main(int argc, char* argv[]) {
    const char* model_path = (argc > 1) ? argv[1] : "mobilenet.npu";
    
    printf("EdgeNPU SDK Example - Batch Inference\n");
    printf("Batch size: %d\n\n", BATCH_SIZE);
    
    /* Open device and load model */
    npu_device_t device = npu_open_device(0);
    if (!device) {
        fprintf(stderr, "Failed to open device\n");
        return 1;
    }
    
    npu_model_handle_t model = npu_load_model(device, model_path);
    if (!model) {
        fprintf(stderr, "Failed to load model\n");
        npu_close_device(device);
        return 1;
    }
    
    /* Create session for inference */
    npu_session_t session = npu_create_session(model);
    if (!session) {
        fprintf(stderr, "Failed to create session\n");
        npu_unload_model(model);
        npu_close_device(device);
        return 1;
    }
    
    /* Allocate batch buffers */
    int8_t* input = (int8_t*)malloc(INPUT_SIZE);
    int8_t* output = (int8_t*)malloc(OUTPUT_SIZE);
    
    /* Process batch */
    printf("Processing %d samples...\n", BATCH_SIZE);
    
    npu_infer_options_t options = {
        .timeout_ms = 5000,
        .profile = true,
    };
    
    uint64_t total_time = 0;
    
    for (int i = 0; i < BATCH_SIZE; i++) {
        /* Prepare input (dummy data) */
        for (int j = 0; j < INPUT_SIZE; j++) {
            input[j] = (int8_t)((i + j) % 256 - 128);
        }
        
        /* Run inference */
        npu_set_input(session, 0, input, INPUT_SIZE);
        npu_error_t err = npu_run(session, &options);
        
        if (err != NPU_SUCCESS) {
            fprintf(stderr, "Inference failed for sample %d\n", i);
            continue;
        }
        
        npu_get_output(session, 0, output, OUTPUT_SIZE);
        
        /* Get profiling */
        npu_profile_result_t profile;
        npu_get_profile_result(session, &profile);
        total_time += profile.inference_time_us;
        
        printf("  Sample %d: %lu us, utilization: %.1f%%\n",
               i, (unsigned long)profile.inference_time_us,
               profile.utilization_percent);
    }
    
    printf("\nBatch complete!\n");
    printf("Total time: %lu us\n", (unsigned long)total_time);
    printf("Average time: %lu us/sample\n", (unsigned long)(total_time / BATCH_SIZE));
    printf("Throughput: %.1f samples/sec\n", 
           1000000.0 * BATCH_SIZE / total_time);
    
    /* Cleanup */
    free(input);
    free(output);
    npu_destroy_session(session);
    npu_unload_model(model);
    npu_close_device(device);
    
    return 0;
}
