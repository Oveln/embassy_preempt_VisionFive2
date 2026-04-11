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
            python3 python3Packages.pip python3Packages.setuptools python3Packages.pyelftools
            git
          ];

          LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";

          # Use musl headers for cross-compilation bindgen
          # Get the musl sysroot for proper includes
          BINDGEN_EXTRA_CLANG_ARGS = "--target=riscv64-unknown-linux-musl --sysroot=${riscv64Musl.buildPackages.gcc.libc}";

          shellHook = ''
            unset OBJCOPY

            # Create symlinks for riscv64-linux-musl compilers in /tmp
            SYMLINK_DIR=/tmp/nix-compiler-bin-$USER
            mkdir -p "$SYMLINK_DIR"

            ln -sf "$(command -v riscv64-unknown-linux-musl-gcc)" "$SYMLINK_DIR/riscv64-linux-musl-gcc"
            ln -sf "$(command -v riscv64-unknown-linux-musl-gcc)" "$SYMLINK_DIR/riscv64-linux-musl-cc"
            ln -sf "$(command -v riscv64-unknown-linux-musl-g++)" "$SYMLINK_DIR/riscv64-linux-musl-g++"
            ln -sf "$(command -v riscv64-unknown-linux-musl-g++)" "$SYMLINK_DIR/riscv64-linux-musl-c++"

            export PATH="$SYMLINK_DIR:$PATH"

            export LD_LIBRARY_PATH="${pkgs.llvmPackages.llvm.lib}/lib:${pkgs.llvmPackages.libclang.lib}/lib:$LD_LIBRARY_PATH"
            '';
        };
      });
}
