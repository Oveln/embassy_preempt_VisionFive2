# Embassy Preempt + StarryOS AMP 方案 for VisionFive2

本项目实现 Embassy Preempt 异步 RTOS 与 StarryOS 操作系统在 VisionFive2（星光2）开发板上的异构 AMP（非对称多处理）方案。

## 项目概述

VisionFive2 搭载 JH7110 **异构五核** RISC-V 处理器，本项目利用其异构特性实现 AMP 架构：

### JH7110 核心架构

JH7110 采用 SiFive U74-MC 核心复杂（Core Complex），包含：

- **1 × S7 核心** (hart0) - 支持 RV64IMAC，较小缓存，适合实时任务
- **4 × U74 核心** (hart1-hart4) - 支持 RV64GC，完整缓存，高性能计算

### AMP 架构分配

- **hart0 (S7)**: 运行 **Embassy Preempt** 异步实时操作系统
- **hart1-4 (U74)**: 运行 **StarryOS** 多核操作系统

这种异构架构充分发挥了不同核心的特性：小核心处理实时任务，大核心处理通用计算。

### 组件介绍

- **Embassy Preempt**: 基于 Rust 异步编程的抢占式多任务 RTOS，支持优先级调度、信号量、互斥锁等同步机制
- **StarryOS**: 基于 ArceOS unikernel 的 Linux 兼容操作系统内核，支持多核（SMP）
- **RustSBI/OpenSBI**: RISC-V SBI（Supervisor Binary Interface）固件实现
- **U-Boot**: 针对 VisionFive2 定制的引导加载程序

## 目录结构

```
.
├── embassy_preempt/    # Embassy Preempt RTOS
│   └── example/        # 示例程序和测试用例
├── StarryOS/           # StarryOS 操作系统
│   └── kernel/         # 内核代码
├── rustsbi/            # RustSBI 固件
├── opensbi/            # OpenSBI 固件（备选）
├── u-boot/             # 定制化的 U-Boot
├── references/         # 参考文档
│   └── u74mc_core_complex_manual_21G1.pdf
└── Makefile            # 统一构建系统
```

## 硬件规格

### VisionFive2 (JH7110)

| 项目 | 规格 |
|------|------|
| 处理器 | StarFive JH7110 SoC |
| CPU | 5× RISC-V 核心 @ 1.5GHz |
| | - 1× S7 (RV64IMAC, hart0) |
| | - 4× U74 (RV64GC, hart1-4) |
| 缓存 | U74-MC: 独立小缓存 |
| | U74: 完整 L1 缓存 + 共享 L2 缓存 |
| 内存 | 8GB DDR4 |
| 存储 | microSD 卡 / eMMC |

### U74-MC vs U74 对比

| 特性 | S7 (hart0) | U74 (hart1-4) |
|------|----------------|---------------|
| 指令集 | RV64IMAC | RV64GC |
| 浮点 | 无 | 有 (双精度) |
| 原子指令 | **部分支持** (无 CAS) | 完整 A 扩展 |
| 缓存 | 较小 | 完整 L1 + 共享 L2 |
| 适用场景 | 实时任务、控制 | 通用计算、OS |

> **⚠️ 重要**: S7 核心不支持硬件 CAS（Compare-And-Swap）原子指令。详见 [U74-MC 核心手册](references/u74mc_core_complex_manual_21G1.pdf)。

## 软件依赖

项目包含完整的 Nix Flakes 配置，自动管理所有依赖：

```bash
# 进入开发环境（自动安装所有依赖）
nix develop

# 或使用 direnv (自动加载)
echo "use flake" > .envrc
direnv allow
```

### Target 配置说明

项目包含针对 S7 的`hart0`核心的定制 target 配置：

- `embassy_preempt/example/riscv64imc-unknown-none-elf.json`
  - `"atomic-cas": false` - 禁用 CAS 指令（S7 硬件限制）
  - `"features": "+m,+c"` - 仅启用整数乘法(M)和压缩(C)指令
  - `"max-atomic-width": 64` - 软件模拟最大 64 位原子操作

**环境变量自动配置**：
- `CC`, `CXX`, `AR`, `OBJCOPY` 等指向 RISC-V 工具链
- `RUST_SRC_PATH` 指向 Rust 源码
- PATH 自动包含所有工具

## 快速开始

### 1. 克隆项目

```bash
git clone --recursive https://github.com/Oveln/embassy_preempt_VisionFive2.git
cd embassy_preempt_VisionFive2

# 如果已克隆但未初始化子模块
git submodule update --init --recursive
```

### 2. 进入开发环境

**使用 Nix（推荐）**：
```bash
nix develop
```

### 3. 编译项目

```bash
# 完整编译（SBI + U-Boot）
make

# 或使用 OpenSBI
make SBI_TYPE=opensbi

# 仅编译 Embassy Preempt
make embassy

# 仅编译 SBI 固件
make sbi
```

### 4. 查看构建输出与烧录

编译完成后，关键文件位于：

**烧录到 VisionFive2 的文件**（仅需这 2 个）：

- **U-Boot SPL**: `u-boot/build/spl/u-boot-spl.bin.normal.out`
- **U-Boot ITB**: `u-boot/build/u-boot.itb`
  - 包含：U-Boot proper + OpenSBI/RustSBI + Embassy Preempt + StarryOS

**中间文件**（用于调试，不需要烧录）：

- **Embassy Preempt**: `embassy_preempt/example/console.bin`
- **StarryOS**: `StarryOS/StarryOS_visionfive2.bin`
- **OpenSBI**: `opensbi/build/platform/generic/firmware/fw_dynamic.bin`
- **RustSBI**: `rustsbi/target/riscv64gc-unknown-none-elf/release/rustsbi-prototyper-dynamic.bin`

## 构建系统详解

### Makefile 目标

| 目标 | 描述 |
|------|------|
| `all` | 构建完整的系统（SBI + U-Boot）|
| `sbi` | 构建选定的 SBI 固件 |
| `rustsbi` | 仅构建 RustSBI |
| `opensbi` | 仅构建 OpenSBI |
| `embassy` | 构建 Embassy Preempt |
| `uboot` | 构建 U-Boot |
| `clean` | 清理所有构建产物 |
| `config` | 显示当前配置 |

### 配置变量

```makefile
SBI_TYPE=rustsbi|opensbi    # SBI 实现（默认：rustsbi）
CROSS_COMPILE=prefix-       # 交叉编译器前缀
EMBASSY_BIN=console        # Embassy 二进制名称
EMBASSY_FEATURES=jh7110    # Cargo features
FW_TEXT_START=0x40000000   # OpenSBI 起始地址
```

## 启动流程

### JH7110 完整启动流程

```
┌─────────────────────────────────────────────────────────────────┐
│                    JH7110 AMP 启动流程                          │
└─────────────────────────────────────────────────────────────────┘

  系统上电
      │
      ▼
┌─────────────┐
│ ZSBL (ROM)  │  Zero-stage Bootloader (Mask ROM)
│  0x0        │  - 初始化基本硬件
└──────┬──────┘  - 从 SD 卡/eMMC 加载 FSBL
       │
       ▼
┌─────────────┐
│ FSBL        │  First-stage Bootloader (SPI NOR Flash)
│  (SRAM)     │  - 初始化 DDR
└──────┬──────┘  - 加载 U-Boot SPL
       │
       ▼
┌─────────────┐
│ U-Boot SPL  │  Secondary Program Loader
│  0x0800_0000│  - 初始化外设
└──────┬──────┘  - 加载 U-Boot proper + SBI
       │
       ▼
┌──────────────────────────────────────┐
│         SBI 固件启动                  │
│   (RustSBI/OpenSBI @ 0x40000000)     │
└──────────────┬───────────────────────┘
               │
               │ 检查 mhartid (hart ID)
               │
       ┌───────┴────────┐
       │                │
       ▼                ▼
  ┌─────────┐      ┌─────────┐
  │ hart0?  │      │ hart1-4 │
  └────┬────┘      └────┬────┘
       │                │
       ▼                ▼
┌─────────────┐  ┌─────────────┐
│ 跳转到      │  │ 正常启动到  │
│            │  │            │
│Embassy     │  │  U-Boot    │
│Preempt     │  │            │
│            │  │  ┌───────┐ │
│ 0xc0000000 │  │  │加载   │ │
│            │  │  │StarryOS│ │
│ (S7     )   │  │  └───────┘ │
└─────────────┘  └─────────────┘
       │                │
       ▼                ▼
┌─────────────┐  ┌─────────────┐
│ Embassy     │  │ StarryOS    │
│ Preempt RTOS│  │             │
│             │  │             │
│ - 异步任务   │  │ hart1-4 并行│
│ - 实时调度   │  │             │
│ - UART控制   │  │ - 通用计算  │
└─────────────┘  └─────────────┘
```

## 内存布局

### JH7110 完整内存映射

```
┌─────────────────────────────────────────────────────────────────┐
│                    JH7110 内存布局                              │
│                    (DDR 8GB @ 0x4000_0000)                     │
└─────────────────────────────────────────────────────────────────┘

  物理地址          大小            用途
─────────────────────────────────────────────────────────────────
  0x0000_0000                    外设区域
  (各种外设)                    - UART, GPIO, I2C, SPI, Timer 等
                               - 系统控制器
                               - MMC/SD

─────────────────────────────────────────────────────────────────
  0x0800_0000                  U-Boot SPL (从 SD 卡加载到内存运行)

─────────────────────────────────────────────────────────────────
  0x4000_0000   2 MB           SBI 固件
                               (RustSBI/OpenSBI + uboot)
  0x4020_0000                  StarryOS kernel (hart1-4 共享)

─────────────────────────────────────────────────────────────────
  0xC000_0000   2 MB           Embassy Preempt RTOS (hart0)

