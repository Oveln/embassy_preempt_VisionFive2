{
  description = "Development environment for Embassy Preempt on VisionFive2";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs {
          inherit system overlays;
        };

        # Import cross-compilation packages
        riscv64Gcc = import nixpkgs {
          inherit system;
          crossSystem.config = "riscv64-unknown-linux-gnu";
        };


        # Rust toolchain matching embassy_preempt/rust-toolchain.toml
        rustToolchain = pkgs.rust-bin.nightly."2025-11-05".default.override {
          extensions = [ "rust-src" "rustfmt" "llvm-tools" "miri" ];
          targets = [
            "thumbv7em-none-eabi"
            "thumbv7em-none-eabihf"
            "riscv32imc-unknown-none-elf"
            "riscv32imac-unknown-none-elf"
            "riscv64imac-unknown-none-elf"
            "riscv64gc-unknown-none-elf"
          ];
        };

      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Rust toolchain
            rustToolchain

            # OpenOCD for debugging
            openocd

            # RISC-V cross-compilation
            riscv64Gcc.buildPackages.gcc

            # Build tools
            gnumake  # Use gnumake instead of make
            pkg-config
            cmake
            ninja
            bison
            flex
            swig
            openssl
            openssl.dev
            gnutls

            # Verification tools
            python3
            python3Packages.pip
            python3Packages.virtualenv
            python3Packages.setuptools  # Needed for U-Boot build

            # Git tools
            git
          ];

          # Environment variables
          RUST_SRC_PATH = "${rustToolchain}/lib/rustlib/src/rust/library";
          CC = "riscv64-unknown-linux-gnu-gcc";
          CXX = "riscv64-unknown-linux-gnu-g++";
          AR = "riscv64-unknown-linux-gnu-ar";
          OBJCOPY = "riscv64-unknown-linux-gnu-objcopy";
          OBJDUMP = "riscv64-unknown-linux-gnu-objdump";
          READELF = "riscv64-unknown-linux-gnu-readelf";
          SIZE = "riscv64-unknown-linux-gnu-size";

          # Add cross compiler to PATH
          nativeBuildInputs = with pkgs; [
            riscv64Gcc.buildPackages.gcc
          ];

          # Shell prompt customization
          shellHook = ''
            export PATH="${riscv64Gcc.buildPackages.gcc}/bin:$PATH"
            echo "Embassy Preempt VisionFive2 Development Environment"
            echo "Rust toolchain: $(rustc --version)"
            echo "RISC-V GCC: $(riscv64-unknown-linux-gnu-gcc --version | head -n1)"
            echo "OpenOCD: $(openocd --version 2>&1 | head -n1)"
          '';
        };
      });
}