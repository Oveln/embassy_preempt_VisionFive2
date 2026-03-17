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

# SBI configuration: rustsbi or opensbi (default: rustsbi)
SBI_TYPE ?= rustsbi

# Paths
OPENSBI_DIR = opensbi
RUSTSBI_DIR = rustsbi
UBOOT_DIR = u-boot
OPENSBI_BUILD_DIR = $(OPENSBI_DIR)/build
RUSTSBI_BUILD_DIR = $(RUSTSBI_DIR)/target
UBOOT_BUILD_DIR = $(UBOOT_DIR)/target

# OpenSBI configuration
FW_TEXT_START ?= 0x40000000
FW_OPTIONS ?= 0
PLATFORM ?= generic

# OpenSBI firmware path
OPENSBI_FIRMWARE = $(OPENSBI_BUILD_DIR)/platform/$(PLATFORM)/firmware/fw_dynamic.bin

# RustSBI firmware path
RUSTSBI_FIRMWARE = $(RUSTSBI_BUILD_DIR)/riscv64gc-unknown-none-elf/release/rustsbi-prototyper-dynamic.bin

# Select firmware based on SBI_TYPE
ifeq ($(SBI_TYPE),rustsbi)
SBI_FIRMWARE = $(RUSTSBI_FIRMWARE)
else
SBI_FIRMWARE = $(OPENSBI_FIRMWARE)
endif

.PHONY: all
all: sbi uboot

.PHONY: sbi
sbi:
	@if [ "$(SBI_TYPE)" = "rustsbi" ]; then \
		$(MAKE) rustsbi; \
	else \
		$(MAKE) opensbi; \
	fi

.PHONY: embassy
embassy:
	@echo "Building Embassy Preempt (bin: $(EMBASSY_BIN))..."
	cd $(EMBASSY_DIR) && \
	RISCV_RT_BASE_ISA=rv64i cargo build -Z build-std=$(EMBASSY_BUILD_STD) \
		--features "$(EMBASSY_FEATURES)" \
		-Zjson-target-spec \
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

.PHONY: rustsbi
rustsbi:
	@echo "Building RustSBI..."
	cd $(RUSTSBI_DIR) && \
	cargo xtask prototyper
	@echo "RustSBI build complete"
	@echo "Firmware location: $(RUSTSBI_FIRMWARE)"

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
uboot: uboot-config sbi embassy
	@echo "Building U-Boot with $(SBI_TYPE)..."
	cd $(UBOOT_DIR) && \
	export OPENSBI=$(abspath $(SBI_FIRMWARE)) && \
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
	@echo "Cleaning RustSBI..."
	cd $(RUSTSBI_DIR) && cargo clean 2>/dev/null || true
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

.PHONY: clean-rustsbi
clean-rustsbi:
	@echo "Cleaning RustSBI..."
	cd $(RUSTSBI_DIR) && cargo clean 2>/dev/null || true

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
	@echo "  all           - Build SBI (rustsbi by default) and U-Boot"
	@echo "  sbi           - Build selected SBI (rustsbi or opensbi)"
	@echo "  rustsbi       - Build RustSBI only"
	@echo "  opensbi       - Build OpenSBI only"
	@echo "  embassy       - Build Embassy Preempt (bin: $(EMBASSY_BIN))"
	@echo "  uboot-config  - Configure U-Boot for VisionFive2"
	@echo "  uboot         - Build U-Boot (auto-configures first, requires SBI)"
	@echo "  clean         - Clean all build artifacts"
	@echo "  clean-rustsbi - Clean RustSBI build artifacts"
	@echo "  clean-opensbi - Clean OpenSBI build artifacts"
	@echo "  clean-uboot   - Clean U-Boot build artifacts"
	@echo "  clean-embassy - Clean Embassy Preempt build artifacts"
	@echo "  help          - Show this help message"
	@echo ""
	@echo "Configuration variables:"
	@echo "  SBI_TYPE        - SBI implementation: rustsbi or opensbi (default: $(SBI_TYPE))"
	@echo "  CROSS_COMPILE   - Cross-compiler prefix (default: $(CROSS_COMPILE))"
	@echo "  JOBS           - Number of parallel jobs (default: $(JOBS))"
	@echo "  FW_TEXT_START  - OpenSBI text start address (default: $(FW_TEXT_START))"
	@echo "  FW_OPTIONS     - OpenSBI firmware options (default: $(FW_OPTIONS))"
	@echo "  EMBASSY_BIN    - Embassy binary name (default: $(EMBASSY_BIN))"
	@echo "  EMBASSY_FEATURES- Cargo features for Embassy (default: $(EMBASSY_FEATURES))"
	@echo ""
	@echo "Examples:"
	@echo "  make                    # Build with RustSBI (default)"
	@echo "  make SBI_TYPE=opensbi   # Build with OpenSBI"
	@echo "  make rustsbi            # Build only RustSBI"
	@echo "  make opensbi            # Build only OpenSBI"

# Print current configuration
.PHONY: config
config:
	@echo "Current configuration:"
	@echo "  SBI_TYPE: $(SBI_TYPE)"
	@echo "  CROSS_COMPILE: $(CROSS_COMPILE)"
	@echo "  JOBS: $(JOBS)"
	@echo "  FW_TEXT_START: $(FW_TEXT_START)"
	@echo "  FW_OPTIONS: $(FW_OPTIONS)"
	@echo "  SBI Firmware: $(SBI_FIRMWARE)"
	@echo "  RustSBI Firmware: $(RUSTSBI_FIRMWARE)"
	@echo "  OpenSBI Firmware: $(OPENSBI_FIRMWARE)"
	@echo "  EMBASSY_BIN: $(EMBASSY_BIN)"
	@echo "  EMBASSY_TARGET: $(EMBASSY_TARGET)"
	@echo "  EMBASSY_FEATURES: $(EMBASSY_FEATURES)"
	@echo "  Embassy Binary: $(EMBASSY_BIN_OUT)"
