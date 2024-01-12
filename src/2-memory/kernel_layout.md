# Kernel layout

At the end of the [Hello, World!](../1-HELLOWORLD.md) section, our kernel is a compact binary located right at the beginning of physical memory. In order to provide isolation from user programs later, we place the kernel code to somewhere else. One can of course keep kernel here and use another virtual page, plus some tranpoline tricks, to achieve this. But we've chosen to move kernel because of simplicity and our design choice.

Below shows typical memory layout for a running kernel:

```
      PHYSICAL MEMORY               VIRTUAL MEMORY                VIRTUAL MEMORY      
                                       (KERNEL)                   (USER PROGRAM)      
                              ┌────────────────────────┐    ┌────────────────────────┐  0xFFFFFFFFFFFFFFFF
                              ·                        ·    ·                        ·
                              ├────────────────────────┤    ├────────────────────────┤
                              │                        │    │                        │
                              │         KERNEL         │    │         KERNEL         │
                              │                        │    │                        │
                              ├────────────────────────┤    ├────────────────────────┤  0xFFFFFFC080200000
                              ·                        ·    ·                        ·
┌────────────────────────┐    ·                        ·    │                        │
│                        │    ·                        ·    │                        │
│          PAGE          │    ·                        ·    │                        │
│                        │    ·                        ·    │      USER PROGRAM      │
├────────────────────────┤    ·                        ·    │                        │
│                        │    ·                        ·    │                        │
│         KERNEL         │    ·                        ·    │                        │
│                        │    ·                        ·    │                        │
├────────────────────────┤    ├────────────────────────┤    ├────────────────────────┤  0x80200000
│        OPEN SBI        │    │        OPEN SBI        │    ·                        ·
├────────────────────────┤    ├────────────────────────┤    ·                        ·  0x80000000
·                        ·    ·                        ·    ·                        ·
├────────────────────────┤    ├────────────────────────┤    ·                        ·
│          MMIO          │    │          MMIO          │    ·                        ·
├────────────────────────┤    ├────────────────────────┤    ·                        ·  0x10001000
·                        ·    ·                        ·    ·                        ·
└────────────────────────┘    └────────────────────────┘    └────────────────────────┘  0x0
```

The kernel runs at the higher address space `0xFFFFFFC080200000`, shifting from its physical address `0x80200000` by `0xFFFFFFC000000000`. Below we define some utilities:

File: src/mem.rs
```rust
pub const BASE_LMA: usize = 0x0000000080000000;
pub const BASE_VMA: usize = 0xFFFFFFC080000000;
pub const OFFSET: usize = BASE_VMA - BASE_LMA;

/// Is `va` a kernel virtual address?
pub fn is_vaddr<T>(va: *mut T) -> bool {
    va as usize >= BASE_VMA
}

/// From virtual to physical address.
pub fn vtop<T>(va: *mut T) -> usize {
    assert!(is_vaddr(va as *mut T));
    va as usize - OFFSET
}

/// From physical to virtual address.
pub fn ptov<T>(pa: usize) -> *mut T {
    assert!(!is_vaddr(pa as *mut T));
    (pa + OFFSET) as *mut T
}
```

## Link the kernel

In the previous linker script, anything is linked at its physical address - the linker assumes the code runs at where it was compiled. But since we are running the whole kernel at the higher address space, the `pc` is shifted from where it was compiled - when weird things could happen. To resolve this, we use the [AT](https://sourceware.org/binutils/docs/ld/Output-Section-Address.html) keyword to specify load address that is different from virtual address. In this linker script, every virtual address is shifted by `0xFFFFFFC000000000`, but shifted back for load address:

File: src/linker.ld
```
BASE_LMA = 0x0000000080000000;
BASE_VMA = 0xFFFFFFC080000000;
OFFSET = BASE_VMA - BASE_LMA;

SECTIONS
{
    . = BASE_VMA;
    . += 0x200000;

    .text : AT(. - OFFSET) {
        *(.text.entry) 
        *(.text*)
    }

    . = ALIGN(4K);
    etext = .;

    .data : AT(. - OFFSET) { *(.*data*) }
    .bss : AT(. - OFFSET) {
        sbss = .;
        *(.*bss*)
        ebss = .;
    }

    . = ALIGN(4K);
    ekernel = .;

    /DISCARD/ : { *(.eh_frame) }
}
```


## Move the kernel

The kernel is moved by creating a *kernel pagetable*, which has

1. An identity mapping for the whole kernel image at its physical address (starting from `0x80000000`). This is done by registering a 1GB large page to the third page table entry.

2. Another large page that maps `0xFFFFFFC080000000` to `0x80000000` similiarily.

File: src/main.rs
```rust
core::arch::global_asm! {r#"
    .section .data

    .globl _pgtable
    .align 12
    _pgtable:

        .zero 4096

    .section .text.entry

    .globl _start
    _start:

        la t0, _pgtable

        addi t1, t0, 1024
        li t2, 0x2000002F               # maps 0x80000000+1GB
        sd t2, 16-1024(t1)              #   to 0x80000000+1GB, and
        sd t2, 16+1024(t1)              #   to 0xFFFFFFC080000000+1GB

        srli t0, t0, 12                 # set the PPN field of satp

        li t1, 0x8 << 60
        or t0, t0, t1                   # set MODE=8 to use SV39

        sfence.vma zero, zero
        csrw satp, t0                   # enable page table
        sfence.vma zero, zero

        la sp, _stack
        ld t0, _main
        jr t0
"#}
```

Note that we are jumping a little bit differently: instead of directly `j main`, we load from the symbol `_main` and `jr` to it. The symbol `_main` stores the address of `main` - why are we doing this? The answer is in the RISC-V ISA itself. The `j` instruction, which is a pseudo-instruction of `jal`, works by relative addressing. If we just call `j main`, the PC will still be in lower address space. Therefore we have to store the (absolute) address of the symbol `main` into memory, and then jump there:

File: src/main.rs
```rust
core::arch::global_asm! {r#"
    .section .data

    .globl _main
    _main:

        .dword main
"#}
```
