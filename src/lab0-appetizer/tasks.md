# Tasks

## Enviroment preparation

Read the [ENVIROMENT](environment/install_toolchain.md) to setup your local development environment and get familiar with the course project.

## Design Doc

Download the [design document template](https://github.com/PKU-OS/Tacos/blob/main/doc/lab0.md) of project 0. Read through questions in the document for motivations, and fill it in afterwards.

## Booting Tacos

If you have Tacos development environment setup as described in the [Install toolchain](environment/install_toolchain.md) section, you should see Tacos booting in the QEMU emulator, and print SBI messages, "Hello, world!" and "Goodbye, world!". __Take screenshots of the successful booting of Tacos in QEMU.__

## Debugging

While you are working on the projects, you will frequently use the GNU Debugger (GDB) to help you find bugs in your code. Make sure you read the [Debugging](appendix/debugging.md) section first. In addition, if you are unfamiliar with riscv assembly, the [RISC-V Instruction Set Manual](https://riscv.org/wp-content/uploads/2017/05/riscv-spec-v2.2.pdf) is a excellent reference. Some online resources, such as [Five Embeddev](https://five-embeddev.com/riscv-isa-manual/latest/riscv-spec.html), are also available.

In this section, you will use GDB to trace the QEMU emulation to understand how Tacos boots. __Follow the steps below and answer the questions in your design document__:

1. Use proper command to start Tacos, freeze it and use gdb-multiarch to connect the guest kernel.

> __Question__
>
> * What is the first instruction that gets executed?
> * At which physical address is this instruction located?

> __Note: Zero Stage Bootloader (ZSBL)__
>
> If you use commands in [Debugging](appendix/debugging.md) to start Tacos & freeze Tacos's execution, QEMU will wait exactly at the first instruction, which will be executed by the machine later.
> The first few executed instructions are called (at least in riscv world) the __Zero Stage Bootloader (ZSBL)__. In real machines, the ZSBL is most likely located in a ROM firmware on the board.
> The ZSBL reads some machine information, initializes a few registers based on them, and then passes contrl to __SBI__ using `jmp` instructions.

2. QEMU's ZSBL only contains a few (less than 20) instructions, and ends with a `jmp` instruction. Use gdb to trace the ZSBL's execution.

> __Question__
>
> * Which address will the ZSBL jump to?

3. Before entering the `main` function in `main.rs`, the SBI has already generated some output. Use breakpoints to stop the execution at the beginning of the `main` function. Read the output and answer following questions:

> __Question__
>
> * What's the value of the argument `hard_id` and `dtb`?
> * What's the value of `Domain0 Next Address`, `Domain0 Next Arg1`, `Domain0 Next Mode` and `Boot HART ID` in OpenSBI's output?
> * What's the relationship between the four output values and the two arguments?

4. The functionality of SBI is basically the same as BIOS. e.g. When Tacos kernel wants to output some string to the console, it simply invokes interfaces provided by SBI. Tacos uses OpenSBI, an opensource riscv SBI implementation. Trace the execution of `console_putchar` in `sbi.rs`, and answer following questions:

> __Question__
>
> * Inside `console_putchar`, Tacos uses `ecall` instruction to transfer control to SBI. What's the value of register `a6` and `a7` when executing that `ecall`?

## Kernel Monitor

At last, you will get to make a small enhancement to Tacos and write some code!

> __Note: Features in Tacos__
>
> * When compiled with different features, Tacos can do more than just printing "Hello, world!".
> * For example, if `test` feature is enabled, Tacos will check for the supplied command line arguments stored in the kernel image. Typically you will pass some tests for the kernel to run.
> * There is another feature named `shell`. To build and run the kernel with `shell` feature, you could use `cargo run -F shell`.

Currently the kernel with `shell` feature will simply finish up. This is a little boring. Your task is to add a tiny __kernel shell__ to Tacos so that when compiled with `shell` feature, it will run this shell interactively.

> __Note: Kernel shell__
>
> * You will implement a kernel-level shell. In later projects, you will be enhancing the user program and file system parts of Tacos, at which point you will get to run the regular shell.
> * You only need to make this monitor very simple. Its requirements are described below.

Requirements:

* Enhance `main.rs` to implement a tiny kernel monitor in Tacos.
* It starts with a prompt `PKUOS>` and waits for user input.
* When a newline is entered, it parses the input and checks if it is `whoami`. If it is `whoami`, print your student id. Afterward, the monitor will print the command prompt `PKUOS>` again in the next line and repeat.
* If the user input is `exit`, the monitor will quit to allow the kernel to finish. For the other input, print invalid command.

> __Hint__
>
> * The code place for you to add this feature is in `main.rs`:
>   `// TODO: Lab 0`
> * You may find some interfaces in `sbi.rs` to be very useful for this lab.
