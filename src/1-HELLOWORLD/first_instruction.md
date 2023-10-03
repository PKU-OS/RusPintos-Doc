# First instruction

The goal of this section is to execute one instruction on QEMU. With the support of modern OS, we can readily compile an executable and ask the OS to load it - but now no one is there to help us. We will need to 
craft a binary file and feed it to QEMU.

## [no_std]-ifying it

By default, `rustc` compiles with a lot of extra OS-dependent things, and giving us a binary that can only be understood by the current platform. These stuff are called `std` - Rust Standard Library, and we can't use any of them on a bare metal system. Also, we need to have full control of the binary we are generating, including where should the entry point be. Fortunately, `rustc` permits this with the `#![no_std]` and `#![no_main]` global attributes, along with a empty panic handler:

File: src/main.rs
```rust
#![no_std]
#![no_main]

#[panic_handler]
fn panic(_: &panic::PanicInfo) -> ! { loop {} }
```

That actually compiles, provided that we have the right target:

```shell
$ cargo build --target riscv64gc-unknown-none-elf
   Compiling rus_pintos v0.1.0 (/path/to/rus_pintos)
    Finished dev [unoptimized + debuginfo] target(s) in 0.20s
```

At this point, we have generated an object file with empty content. Now let's try to add our first instruction by injecting some assembly into the source file:

File: src/main.rs
```rust
arch::global_asm! {r#"
    .section .text
        addi x0, x1, 42
"#}
```

## Linking by hand

We have no idea where the `.text` section is located. If an OS exists, it could read the output object file and determine the `_entry` point. But on a bare metal system, we have to manually design the layout of the whole codebase such that the hardware can just treat it as an unstructured binary and go ahead executing whatever is on the upfront.

[Linker script](https://ftp.gnu.org/old-gnu/Manuals/ld-2.9.1/html_chapter/ld_3.html) is a standard way to customize binary layout. We can specify the address of each section we created in the source files. Let's put this instruction to where QEMU is able to find:

File: src/linker.ld
```
OUTPUT_ARCH(riscv)

SECTIONS
{
    . = 0x0000000080200000;
    .entry : { *(.text) }
    /DISCARD/ : { *(.eh_frame) }
}
```

Just to clearify, the section `.text` and the segment `.entry` is arbitrarily named - call them whever you want as long as the names are consistent in the source file and linker script.

QEMU's physical address starts at `0x80000000`, and at that address, there's a small code snippet that comes with it - Supervisor Binary Interface (SBI). It is responsible for setting up the machine and providing basic services, and we will back it up [later](sbi_support.md). In the linker script, the load address `0x80200000` works because we know the size of SBI will not exceed it.

Now we can compile our instruction with the linker script

```shell
RUSTFLAGS=-Clink-arg=-Tsrc/linker.ld cargo build --target riscv64gc-unknown-none-elf
```

and ask QEMU to load and simulate the generated target on a virtual machine

```shell
qemu-system-riscv64 -nographic -machine virt -kernel target/riscv64gc-unknown-none-elf/debug/rus_pintos
```

If nothing went wrong, it will stuck after printing some pretty welcome message:

```shell

OpenSBI v1.2
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
Platform Timer Device     : aclint-mtimer @ 10000000Hz
Platform Console Device   : uart8250
Platform HSM Device       : ---
Platform PMU Device       : ---
Platform Reboot Device    : sifive_test
Platform Shutdown Device  : sifive_test
Firmware Base             : 0x80000000
Firmware Size             : 212 KB
Runtime SBI Version       : 1.0

Domain0 Name              : root
Domain0 Boot HART         : 0
Domain0 HARTs             : 0*
Domain0 Region00          : 0x0000000002000000-0x000000000200ffff (I)
Domain0 Region01          : 0x0000000080000000-0x000000008003ffff ()
Domain0 Region02          : 0x0000000000000000-0xffffffffffffffff (R,W,X)
Domain0 Next Address      : 0xfffffffffffff000
Domain0 Next Arg1         : 0x0000000087e00000
Domain0 Next Mode         : S-mode
Domain0 SysReset          : yes

Boot HART ID              : 0
Boot HART Domain          : root
Boot HART Priv Version    : v1.12
Boot HART Base ISA        : rv64imafdch
Boot HART ISA Extensions  : time,sstc
Boot HART PMP Count       : 16
Boot HART PMP Granularity : 4
Boot HART PMP Address Bits: 54
Boot HART MHPM Count      : 16
Boot HART MIDELEG         : 0x0000000000001666
Boot HART MEDELEG         : 0x0000000000f0b509

```

We don't want to type this everytime, so let's put it down and we can go with `cargo run` afterwards:

File: .cargo/config.toml
```toml
[build]
target = "riscv64gc-unknown-none-elf"

[target.riscv64gc-unknown-none-elf]
rustflags = ["-Clink-arg=-Tsrc/linker.ld"]
runner = "qemu-system-riscv64 -nographic -machine virt -kernel"
```

## Why it "halts"?

It's not actually halting. Since we've only loaded one instruction, the rest of the memory is uninitialized - and very likely to contain invalid instructions. Even if we are lucky and not encountering invalid instructions, the memory is small and the program counter will soon go out of the boundary. In whichever case, we are in trouble and SBI will take over control and try resetting everything - and the above loop goes over and over again.
