# EdgeNPU Firmware Makefile
# Build firmware for NPU

# Toolchain
CROSS_COMPILE ?= riscv32-unknown-elf-
CC = $(CROSS_COMPILE)gcc
AS = $(CROSS_COMPILE)as
LD = $(CROSS_COMPILE)ld
OBJCOPY = $(CROSS_COMPILE)objcopy
OBJDUMP = $(CROSS_COMPILE)objdump
SIZE = $(CROSS_COMPILE)size

# Directories
BUILD_DIR = build
BOOT_DIR = boot
RUNTIME_DIR = runtime
INCLUDE_DIR = include

# Source files
BOOT_SRCS = $(wildcard $(BOOT_DIR)/*.c)
RUNTIME_SRCS = $(wildcard $(RUNTIME_DIR)/*.c)
ALL_SRCS = $(BOOT_SRCS) $(RUNTIME_SRCS)

# Object files
BOOT_OBJS = $(BOOT_SRCS:$(BOOT_DIR)/%.c=$(BUILD_DIR)/boot/%.o)
RUNTIME_OBJS = $(RUNTIME_SRCS:$(RUNTIME_DIR)/%.c=$(BUILD_DIR)/runtime/%.o)
ALL_OBJS = $(BOOT_OBJS) $(RUNTIME_OBJS)

# Output files
FIRMWARE_ELF = $(BUILD_DIR)/npu_firmware.elf
FIRMWARE_BIN = $(BUILD_DIR)/npu_firmware.bin
FIRMWARE_HEX = $(BUILD_DIR)/npu_firmware.hex

# Compiler flags
CFLAGS = -march=rv32imc -mabi=ilp32
CFLAGS += -Os -g
CFLAGS += -Wall -Wextra -Werror
CFLAGS += -ffunction-sections -fdata-sections
CFLAGS += -I$(INCLUDE_DIR)
CFLAGS += -DNPU_FIRMWARE

# Linker flags
LDFLAGS = -nostdlib -nostartfiles
LDFLAGS += -Wl,--gc-sections
LDFLAGS += -T linker.ld

# Default target
all: dirs $(FIRMWARE_BIN) $(FIRMWARE_HEX)

# Create build directories
dirs:
	@mkdir -p $(BUILD_DIR)/boot
	@mkdir -p $(BUILD_DIR)/runtime

# Compile boot sources
$(BUILD_DIR)/boot/%.o: $(BOOT_DIR)/%.c
	$(CC) $(CFLAGS) -c $< -o $@

# Compile runtime sources
$(BUILD_DIR)/runtime/%.o: $(RUNTIME_DIR)/%.c
	$(CC) $(CFLAGS) -c $< -o $@

# Link firmware
$(FIRMWARE_ELF): $(ALL_OBJS)
	$(CC) $(CFLAGS) $(LDFLAGS) $^ -o $@
	$(SIZE) $@

# Generate binary
$(FIRMWARE_BIN): $(FIRMWARE_ELF)
	$(OBJCOPY) -O binary $< $@

# Generate hex file
$(FIRMWARE_HEX): $(FIRMWARE_ELF)
	$(OBJCOPY) -O ihex $< $@

# Generate disassembly
disasm: $(FIRMWARE_ELF)
	$(OBJDUMP) -d -S $< > $(BUILD_DIR)/npu_firmware.dis

# Clean build
clean:
	rm -rf $(BUILD_DIR)

# Install to target
install: $(FIRMWARE_BIN)
	@echo "Installing firmware..."
	cp $(FIRMWARE_BIN) ../../../tools/firmware/

# Print size info
size: $(FIRMWARE_ELF)
	$(SIZE) -A $<

# Help
help:
	@echo "EdgeNPU Firmware Build System"
	@echo ""
	@echo "Targets:"
	@echo "  all      - Build firmware (default)"
	@echo "  clean    - Clean build files"
	@echo "  disasm   - Generate disassembly"
	@echo "  install  - Install firmware"
	@echo "  size     - Print size information"
	@echo ""
	@echo "Variables:"
	@echo "  CROSS_COMPILE - Toolchain prefix (default: riscv32-unknown-elf-)"

.PHONY: all dirs clean disasm install size help

