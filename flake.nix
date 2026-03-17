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

        riscv64Gcc = import nixpkgs {
          inherit system;
          crossSystem.config = "riscv64-unknown-linux-gnu";
        };

        riscv64Musl = import nixpkgs {
          inherit system;
          crossSystem.config = "riscv64-unknown-linux-musl";
        };

        rustToolchain = pkgs.rust-bin.nightly."2026-03-15".default.override {
          extensions = [ "rust-src" "rustfmt" "llvm-tools" "rust-analyzer" ];
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
            rustToolchain
            openocd
            riscv64Gcc.buildPackages.gcc
            riscv64Musl.buildPackages.gcc
            gnumake pkg-config cmake ninja
            bison flex swig
            openssl openssl.dev gnutls
            clang llvm llvmPackages.libclang libclang.lib llvmPackages.llvm.lib
            qemu
            python3 python3Packages.pip python3Packages.setuptools
            git
          ];

          LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";
          BINDGEN_EXTRA_CLANG_ARGS = "-I${pkgs.glibc.dev}/include -I${riscv64Musl.buildPackages.gcc.libc}/include";

          shellHook = ''
            unset OBJCOPY

            # Compiler aliases for riscv64-linux-musl
            alias riscv64-linux-musl-gcc="riscv64-unknown-linux-musl-gcc"
            alias riscv64-linux-musl-cc="riscv64-unknown-linux-musl-gcc"
            alias riscv64-linux-musl-g++="riscv64-unknown-linux-musl-g++"
            alias riscv64-linux-musl-c++="riscv64-unknown-linux-musl-g++"

            export LD_LIBRARY_PATH="${pkgs.llvmPackages.llvm.lib}/lib:${pkgs.llvmPackages.libclang.lib}/lib:$LD_LIBRARY_PATH"
            '';
        };
      });
}
