# Install toolchain

We provided several ways to setup the develop enviroment.

* Option A: If you're using vscode on a desktop platform, the simplest and the recommended way to setup is to use `Docker Desktop` and the `Dev Container` plugin in vscode.
* Option B: If you prefer other editors, you are encouraged to use build or use the pre-built docker image.
* Option C: Installing everything is also supported.

Before you install the toolchain, please ensure that your device have enough space (>= 5G is enough), and a good network connection.

## Option A: Use pre-built Docker image and dev container (recommended)

### Download docker

There are 2 ways to install docker:

1. On normal desktop platform, the easiest way is to install the [Docker Desktop](https://www.docker.com/get-started/).
2. You could also install docker on linux machines follow the instructions on this [page](https://docs.docker.com/engine/install/).

Start the docker desktop, or docker, after it is installed. You could use following commands to ensure it is successfully installed:

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

Run `ls` under the Tacos root folder, you will see following output:

```bash
user@your_host> ls
Cargo.lock  Cargo.toml  Dockerfile  README.md  build  fw_jump.bin  makefile  mkfs.c  src  target  test  tool  user

```

### Setup dev container

Open this folder (the project root folder) in vscode, and then run the `Dev Containers: Open Folder in Container...` command from the Command Palette (F1) or quick actions Status bar item, and select this folder. This step may take a while, because we are pulling a ~3G image from dockerhub.
This [website](https://code.visualstudio.com/docs/devcontainers/containers#_quick-start-open-an-existing-folder-in-a-container) displays the potential outputs that VSCode might produce during this process, feel free to use it to verify your setting.

### Run Tacos

After entered the dev container, open a shell and use following command to build Tacos's disk image:

```shell
make
```

`make` will build `disk.img` under `build/` directory, which is used as the hard disk of Tacos. Then, you are able to run Tacos with:

```shell
cargo run
```

`cargo run` will build the kernel, and then use `qemu` emulator to run it. This is done by setting `runner` in `.cargo/config.toml`. 

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

## Option B: User pre-built Docker image, or manually build the image

If you don't want to use `Dev Contianer`, but want to use the docker image, you still __need__ to follow the instructions in Option A to __download docker__ and __clone the code__. Then you could _either_ build the image manually _or_ use the pre-built one.

* To manually build the image, `cd` to the project root folder, and then run following command to build an image:

```shell
docker build . -t tacos
```

This may take a few minutes. If the build goes fine, you will see following output:

```bash
user@your_host> docker build -t tacos .
[+] Building ...s (16/16) 
... (build output)
 => => exporting layers
 => => writing image
 => => naming to docker.io/library/tacos
```

And then start a container with following commands:

```shell
docker run --rm --name <container name> --mount type=bind,source=</absolute/path/to/this/folder/on/your/machine>,target=/workspaces/Tacos -it tacos bash
cd /workspaces/Tacos
```

> __Important__
>
> * __Do not just copy and paste the command below!__ At least you need to replace __the absolute path to your Tacos directory__ and the __container name__ in the command!
> * If you choose this way to setup the enviroment, you will use this command throughout this semester. It is tedious to remember it and type it again and again. You can choose the way you like to avoid this. e.g. You can use the alias Linux utility to save this command as tacos-up for example.

If you see following output, you are already inside the container:

```bash
user@your_host> docker run --rm --name <container name> --mount type=bind,source=</absolute/path/to/this/folder/on/your/machine>,target=/workspaces/Tacos -it tacos bash
root@0349a612bcf8:~# cd /workspaces/Tacos
root@0349a612bcf8:/workspaces/Tacos# ls
Cargo.lock  Cargo.toml  Dockerfile  README.md  build  fw_jump.bin  makefile  mkfs.c  src  target  test  tool  user
```

Then you are free to follow the running instructions in Option A.

* To use the pre-built version, run following commands:

```shell
docker pull chromi2eugen/tacos
```

This may take a few minutes. If the download goes fine, you will see following output:

```bash
user@your_host> docker pull chromi2eugen/tacos
Using default tag: latest
latest: Pulling from chromi2eugen/tacos
some_hash_value: Pull complete
...
some_hash_value: Pull complete
Digest: sha256:...
Status: Downloaded newer image for chromi2eugen/tacos:latest
docker.io/chromi2eugen/tacos:latest
```

And then start a container with following commands:

```shell
docker run --rm --name <container name> --mount type=bind,source=</absolute/path/to/this/folder/on/your/machine>,target=/workspaces/Tacos -it chromi2eugen/tacos bash
cd /workspaces/Tacos
```

If you see following output, you are already inside the container:

```bash
user@your_host> docker run --rm --name <container name> --mount type=bind,source=</absolute/path/to/this/folder/on/your/machine>,target=/workspaces/Tacos -it tacos bash
root@0349a612bcf8:~# cd /workspaces/Tacos
root@0349a612bcf8:/workspaces/Tacos# ls
Cargo.lock  Cargo.toml  Dockerfile  README.md  build  fw_jump.bin  makefile  mkfs.c  src  target  test  tool  user
```

Remember that you need to replace the __absolute path to your Tacos directory__ and the __container name__ in the command. If you choose this way to setup, you will use above command throughout this semester.

Then you are free to follow the running instructions in Option A.

## Option C: Install from scratch

The first thing would always be to [install](https://www.rust-lang.org/tools/install) Rust and the build tool Cargo. Since our OS will run on a RISC-V machine, we also need to add cross-compiling targets to `rustc`:

```shell
rustup target add riscv64gc-unknown-none-elf
```

Our OS runs on machine simulator - [QEMU](https://www.qemu.org). Follow the referenced link to install it.
