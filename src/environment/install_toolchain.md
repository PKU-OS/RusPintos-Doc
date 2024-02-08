# Install toolchain

We provided several ways to setup the develop enviroment. If you're using vscode on a desktop platform, the simplest way to setup is to use `Docker Desktop` and the `Dev Container` plugin in vscode (Option A). If you prefer other editors, you are free to use it with docker image (Option B). Installing everything is also supported.

## Option A: Use pre-built Docker image and dev container (recommended)

### Download docker

On normal desktop platform, the easiest way is to install the [Docker Desktop](https://www.docker.com/get-started/). You could also install docker on linux machines follow the instructions on this [page](https://docs.docker.com/engine/install/). Run the docker desktop after it is installed. Run following commands on a terminal (windows powershell, bash, zsh, ...) to ensure docker is successfully installed:

```bash
> docker --version
Docker version 20.10.17, build 100c701
```

### Clone the skeleton code

The next step is to clone the Tacos repository:

```bash
cd /somewhere/you/like
git clone <link>
cd tacos
```

### Setup dev container

Open this folder (the project root folder) in vscode, and then run the `Dev Containers: Open Folder in Container...` command from the Command Palette (F1) or quick actions Status bar item, and select this folder. This step may take a while.
This [website](https://code.visualstudio.com/docs/devcontainers/containers#_quick-start-open-an-existing-folder-in-a-container) displays the potential outputs that VSCode might produce during this process, feel free to use it to verify your setting.

### Run the empty kernel

Use following command to build and run a test kernel: 

```shell
cargo run
```

`cargo run` first builds the kernel, and then use `qemu` emulator to run it. This is done by setting `runner` in `.cargo/config.toml`.

If everything goes fine, you will see following outputs:

```
root@8dc8de33b91a:/workspaces/Tacos# cargo run
    Blocking waiting for file lock on build directory
   Compiling tacos v0.1.0 (/workspaces/Tacos)
    Finished dev [unoptimized + debuginfo] target(s) in 6.44s
     Running `qemu-system-riscv64 -machine virt -display none -bios fw_jump.bin -global virtio-mmio.force-legacy=false --blockdev driver=file,node-name=disk,filename=build/disk.img -snapshot -device virtio-blk-device,drive=disk,bus=virtio-mmio-bus.0 -kernel target/riscv64gc-unknown-none-elf/debug/tacos`

OpenSBI v1.4-15-g9c8b18e
   ____                    _____ ____ _____
  / __ \                  / ____|  _ \_   _|
 | |  | |_ __   ___ _ __ | (___ | |_) || |
 | |  | | '_ \ / _ \ '_ \ \___ \|  _ < | |
 | |__| | |_) |  __/ | | |____) | |_) || |_
  \____/| .__/ \___|_| |_|_____/|____/_____|
        | |
        |_|

Platform Name             : riscv-virtio,qemu
Platform Features         : medeleg
Platform HART Count       : 1
Platform IPI Device       : aclint-mswi

... (sbi outputs)

[41 ms] Hello, World!
[105 ms] Goodbye, World!
```

Congratulations! You have successfully setup Tacos, and are prepared for the labs! Hope you will enjoy it!

## Option B: User Docker image

If you don't want to use `Dev Contianer`, but want to use the docker image, you still need to follow the instructions in Option A to install docker and clone the code. Then you could build the env with Dockerfile and then start a container with following commands.:

```shell
docker build . -t tacos
docker run -d --name <container name> --mount type=bind,source=</absolute/path/to/this/folder/on/your/machine>,target=/workspaces/Tacos -it tacos bash
cd /workspaces/Tacos
```

Then you are free to follow the running instructions in Option A.

## Option C: Install from scratch

Following install process are verified on a ubuntu 22.04 machine.

The first thing would always be to [install](https://www.rust-lang.org/tools/install) Rust and the build tool Cargo:

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

Since our OS is written for the RISC-V, we also need to add cross-compiling targets to `rustc`:

```shell
rustup target add riscv64gc-unknown-none-elf
```

Our OS runs on machine simulator - [QEMU](https://www.qemu.org). Follow the referenced link to install it.
