# Install toolchain

## Install from scratch

The first thing would always be to [install](https://www.rust-lang.org/tools/install) Rust and the build tool Cargo. Since our OS is written for the RISC-V, we also need to add cross-compiling targets to `rustc`:
```shell
rustup target add riscv64gc-unknown-none-elf
```

Our OS runs on machine simulator - [QEMU](https://www.qemu.org). Follow the referenced link to install it.

## Use pre-built Docker image

TODO: I'm not familiar with it.
