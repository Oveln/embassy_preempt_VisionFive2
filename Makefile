# Makefile for Embassy Preempt VisionFive2

# Configuration
CROSS_COMPILE ?= riscv64-unknown-linux-gnu-
NPROC ?= $(shell nproc)
JOBS ?= -j $(NPROC)

# Embassy Preempt configuration
EMBASSY_DIR = embassy_preempt/example
EMBASSY_BIN ?= console
EMBASSY_TARGET = riscv64imc-unknown-none-elf.json
EMBASSY_FEATURES ?= jh7110
EMBASSY_BUILD_STD = core,alloc
EMBASSY_TARGET_DIR = $(EMBASSY_DIR)/target/$(basename $(EMBASSY_TARGET))
EMBASSY_ELF = $(EMBASSY_TARGET_DIR)/release/$(EMBASSY_BIN)
EMBASSY_BIN_OUT = $(EMBASSY_DIR)/$(EMBASSY_BIN).bin

# Paths
OPENSBI_DIR = opensbi
UBOOT_DIR = u-boot
OPENSBI_BUILD_DIR = $(OPENSBI_DIR)/build
UBOOT_BUILD_DIR = $(UBOOT_DIR)/target

# OpenSBI configuration
FW_TEXT_START ?= 0x40000000
FW_OPTIONS ?= 0
PLATFORM ?= generic

# OpenSBI firmware path
OPENSBI_FIRMWARE = $(OPENSBI_BUILD_DIR)/platform/$(PLATFORM)/firmware/fw_dynamic.bin

.PHONY: all
all: opensbi uboot

.PHONY: embassy
embassy:
	@echo "Building Embassy Preempt (bin: $(EMBASSY_BIN))..."
	cd $(EMBASSY_DIR) && \
	cargo build -Z build-std=$(EMBASSY_BUILD_STD) \
		--features "$(EMBASSY_FEATURES)" \
		--target $(EMBASSY_TARGET) \
		--bin $(EMBASSY_BIN) \
		--release
	@echo "Converting to binary..."
	rust-objcopy --binary-architecture=riscv64 \
		$(EMBASSY_ELF) \
		-O binary $(EMBASSY_BIN_OUT)
	@echo "Embassy Preempt build complete"
	@echo "Binary location: $(EMBASSY_BIN_OUT)"

.PHONY: opensbi
opensbi:
	@echo "Building OpenSBI..."
	@mkdir -p $(OPENSBI_BUILD_DIR)
	cd $(OPENSBI_DIR) && \
	make $(JOBS) \
		PLATFORM=generic \
		FW_TEXT_START=$(FW_TEXT_START) \
		FW_OPTIONS=$(FW_OPTIONS) \
		CROSS_COMPILE=$(CROSS_COMPILE) \
		O=build
	@echo "OpenSBI build complete"
	@echo "Firmware location: $(OPENSBI_FIRMWARE)"

.PHONY: uboot-config
uboot-config:
	@echo "Configuring U-Boot for VisionFive2..."
	@mkdir -p $(UBOOT_BUILD_DIR)
	cd $(UBOOT_DIR) && \
	make $(JOBS) \
		ARCH=riscv \
		CROSS_COMPILE=$(CROSS_COMPILE) \
		O=build \
		starfive_visionfive2_defconfig
	@echo "U-Boot configuration complete"

.PHONY: uboot
uboot: uboot-config opensbi embassy
	@echo "Building U-Boot..."
	cd $(UBOOT_DIR) && \
	export OPENSBI=$(abspath $(OPENSBI_FIRMWARE)) && \
	export EMBASSY_PREEMPT=$(abspath $(EMBASSY_BIN_OUT)) && \
	make $(JOBS) \
		ARCH=riscv \
		CROSS_COMPILE=$(CROSS_COMPILE) \
		O=build
	@echo "U-Boot build complete"

.PHONY: clean
clean:
	@echo "Cleaning OpenSBI..."
	cd $(OPENSBI_DIR) && make clean O=build 2>/dev/null || true
	rm -rf $(OPENSBI_BUILD_DIR)
	@echo "Cleaning U-Boot..."
	cd $(UBOOT_DIR) && make clean O=target 2>/dev/null || true
	rm -rf $(UBOOT_BUILD_DIR)
	@echo "Cleaning Embassy Preempt..."
	cd $(EMBASSY_DIR) && cargo clean 2>/dev/null || true
	rm -f $(EMBASSY_DIR)/*.bin

.PHONY: clean-opensbi
clean-opensbi:
	@echo "Cleaning OpenSBI..."
	cd $(OPENSBI_DIR) && make clean O=build 2>/dev/null || true
	rm -rf $(OPENSBI_BUILD_DIR)

.PHONY: clean-uboot
clean-uboot:
	@echo "Cleaning U-Boot..."
	cd $(UBOOT_DIR) && make clean O=target 2>/dev/null || true
	rm -rf $(UBOOT_BUILD_DIR)

.PHONY: clean-embassy
clean-embassy:
	@echo "Cleaning Embassy Preempt..."
	cd $(EMBASSY_DIR) && cargo clean 2>/dev/null || true
	rm -f $(EMBASSY_DIR)/*.bin

.PHONY: help
help:
	@echo "Available targets:"
	@echo "  all           - Build OpenSBI and U-Boot"
	@echo "  embassy       - Build Embassy Preempt (bin: $(EMBASSY_BIN))"
	@echo "  opensbi       - Build OpenSBI only"
	@echo "  uboot-config  - Configure U-Boot for VisionFive2"
	@echo "  uboot         - Build U-Boot (auto-configures first, requires OpenSBI)"
	@echo "  clean         - Clean all build artifacts"
	@echo "  clean-opensbi - Clean OpenSBI build artifacts"
	@echo "  clean-uboot   - Clean U-Boot build artifacts"
	@echo "  clean-embassy - Clean Embassy Preempt build artifacts"
	@echo "  help          - Show this help message"
	@echo ""
	@echo "Configuration variables:"
	@echo "  CROSS_COMPILE   - Cross-compiler prefix (default: $(CROSS_COMPILE))"
	@echo "  JOBS           - Number of parallel jobs (default: $(JOBS))"
	@echo "  FW_TEXT_START  - OpenSBI text start address (default: $(FW_TEXT_START))"
	@echo "  FW_OPTIONS     - OpenSBI firmware options (default: $(FW_OPTIONS))"
	@echo "  EMBASSY_BIN    - Embassy binary name (default: $(EMBASSY_BIN))"
	@echo "  EMBASSY_FEATURES- Cargo features for Embassy (default: $(EMBASSY_FEATURES))"

# Print current configuration
.PHONY: config
config:
	@echo "Current configuration:"
	@echo "  CROSS_COMPILE: $(CROSS_COMPILE)"
	@echo "  JOBS: $(JOBS)"
	@echo "  FW_TEXT_START: $(FW_TEXT_START)"
	@echo "  FW_OPTIONS: $(FW_OPTIONS)"
	@echo "  OpenSBI Firmware: $(OPENSBI_FIRMWARE)"
	@echo "  EMBASSY_BIN: $(EMBASSY_BIN)"
	@echo "  EMBASSY_TARGET: $(EMBASSY_TARGET)"
	@echo "  EMBASSY_FEATURES: $(EMBASSY_FEATURES)"
	@echo "  Embassy Binary: $(EMBASSY_BIN_OUT)"