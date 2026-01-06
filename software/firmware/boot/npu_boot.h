/**
 * EdgeNPU Firmware - Boot API
 * Boot and initialization functions
 * 
 * Copyright (c) 2024 EdgeNPU Project
 */

#ifndef NPU_BOOT_H
#define NPU_BOOT_H

#include "../include/npu_fw_types.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Hardware reset sequence
 * Performs a full hardware reset of the NPU
 * 
 * @return FW_OK on success, error code otherwise
 */
fw_status_t npu_hw_reset(void);

/**
 * Full boot initialization
 * Initializes all NPU subsystems and prepares for operation
 * 
 * @return FW_OK on success, error code otherwise
 */
fw_status_t npu_boot_init(void);

/**
 * Get hardware information
 * Retrieves NPU hardware configuration
 * 
 * @param version   Output: Hardware version
 * @param pe_rows   Output: Number of PE rows
 * @param pe_cols   Output: Number of PE columns
 * @return FW_OK on success, error code otherwise
 */
fw_status_t npu_boot_get_info(uint32_t *version, uint32_t *pe_rows, uint32_t *pe_cols);

/**
 * Self-test routine
 * Performs basic hardware verification tests
 * 
 * @return FW_OK if all tests pass, error code otherwise
 */
fw_status_t npu_boot_selftest(void);

/**
 * Enter low power mode
 * Puts NPU into sleep state to save power
 * 
 * @return FW_OK on success
 */
fw_status_t npu_boot_sleep(void);

/**
 * Wake from low power mode
 * Restores NPU from sleep state
 * 
 * @return FW_OK on success, error code otherwise
 */
fw_status_t npu_boot_wake(void);

/**
 * Main boot entry point
 * Called by startup code after basic initialization
 * 
 * @return 0 on success, negative error code otherwise
 */
int npu_boot_main(void);

#ifdef __cplusplus
}
#endif

#endif /* NPU_BOOT_H */
