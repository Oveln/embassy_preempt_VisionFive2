FROM ubuntu:24.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install basic dependencies and cleanup in a single layer
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    build-essential \
    pkg-config \
    cmake \
    ninja-build \
    make \
    bison \
    flex \
    swig \
    qemu-system \
    gdb \
    gdb-multiarch \
    python3 \
    python3-dev \
    python3-pip \
    python3-setuptools \
    wget \
    xz-utils \
    ca-certificates \
    bash-completion \
    libssl-dev \
    libgnutls28-dev \
    libfdt-dev \
    clang \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean \
    && echo "source /usr/share/bash-completion/bash_completion" >> /etc/bash.bashrc

ENV PATH="/root/.cargo/bin:/opt/riscv64-linux-musl-cross/bin:${PATH}"

# Install all Rust toolchains and their specific targets in a single layer
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    --default-toolchain nightly-2026-03-15 \
    --profile minimal \
    --component rust-src \
    --component rustfmt \
    --component llvm-tools \
    --component rust-analyzer \
    && rustup toolchain install nightly-2026-02-25 --profile minimal \
    --component rust-src \
    --component rustfmt \
    --component llvm-tools \
    --component clippy \
    --component rust-analyzer \
    && rustup target add --toolchain nightly-2026-02-25 \
        aarch64-unknown-none-softfloat \
        riscv64gc-unknown-none-elf \
        x86_64-unknown-none \
        loongarch64-unknown-none-softfloat \
    && rustup target add --toolchain nightly-2026-03-15 \
        riscv64imac-unknown-none-elf \
    && pip3 install --no-cache-dir --break-system-packages pyelftools \
    && cargo install --locked cargo-binutils \
    && wget -q https://github.com/arceos-org/setup-musl/releases/download/prebuilt/riscv64-linux-musl-cross.tgz \
    && tar -xzf riscv64-linux-musl-cross.tgz -C /opt/ \
    && rm riscv64-linux-musl-cross.tgz \
    && rm -rf /root/.cargo/registry \
    && rm -rf /root/.cargo/git \
    && rm -rf /tmp/*

# Set working directory
WORKDIR /workspace

# Default shell
SHELL ["/bin/bash", "-c"]

CMD ["/bin/bash"]
