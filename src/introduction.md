# Welcome to Tacos Doc!

<img src="/assets/tacos-title/tacos-title.PNG" width="100%">

Tacos is an operating system developed in Rust for RISC-V platforms. This minimal OS incorporates Rust's design principles and is intended for educational purposes. The source code, toolchain, and documentation have been developed by our team at Peking University (refer to [Acknowledgement](#Acknowledgement) for details). The main source code is available at [https://github.com/PKU-OS/Tacos](https://github.com/PKU-OS/Tacos).

The code structure is designed to be modular, which means that some components of the OS can be enabled by including the corresponding source code directory for compilation. Under the `src` directory, some folders (e.g., `sbi`) are required for running the OS, while others (e.g., `userproc`) are only used incrementally for each lab.

This documentation contains a detailed walkthrough of how Tacos is written from scratch. We will start from an empty folder. The basic code structure for bare-metal execution is implemented in the [HelloWorld](./1-helloworld.md) section. Then, in the [Memory](./2-memory.md) section, we set up the kernel address space and manage the physical memory, including a global memory allocator. The code written in the above two sections is required for running the OS and will stay unchanged throughout the whole lab.

## Projects

In the [Thread](./3-kernelthread.md) section, we implement preemptive kernel threading. This includes the thread data structure, a simple kernel thread scheduler, and synchronization primitives. We will be able to perform concurrent programming after this section. One lab is associated with this section:

- [**Scheduling**](./lab1-scheduling.md). We will implement an advanced scheduler that supports priority scheudling and priority donation. We will get you familiar with it by first implementing thread sleeping.

In the [FileSystem](./4-filesystem.md) section, we implement a naïve file system. We will use it to manage files and load executables from disk devices. There will be no lab associated with this section.

In the [UserProgram](./5-userprogram.md) section, we implement user-level programs. This is achieved by setting up proper execution privileges and virtual memory pages. Two labs are associated with this section:

- [**Syscalls**](./lab2-userprograms.md). We will implement various system calls for the user program, including process control calls (e.g., `wait` and `exit`) and file system operations (e.g., `read` and `write`).

- [**Virtual Memory**](./lab3-virtual_memory.md). We will implement virtual page swapping, and memory map system call for user programs.

## Acknowledgement

Tacos is inspired by [Pintos from Stanford](https://web.stanford.edu/class/cs140/projects/pintos), which was again inspired by [Nachos from UC Berkeley](https://inst.eecs.berkeley.edu/~cs162/sp07/Nachos).
