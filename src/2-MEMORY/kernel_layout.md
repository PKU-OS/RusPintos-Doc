# Kernel layout

At the end of the [Hello, World!](../1-HELLOWORLD.md) section, our kernel is a compact binary located right at the beginning of physical memory. In order to provide isolation from user programs later, we place the kernel code to somewhere else. One can of course keep kernel here and use another virtual page, plus some tranpoline tricks, to achieve this. But we've chosen to move kernel because of simplicity and our design choice.

TODO: flesh out more on how this layout works

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
                              ├────────────────────────┤    ├────────────────────────┤  0xFFFFFFC080000000
                              ·                        ·    │                        │
┌────────────────────────┐    ·                        ·    │                        │
│                        │    ·                        ·    │                        │
│          PAGE          │    ·                        ·    │                        │
│                        │    ·                        ·    │                        │
├────────────────────────┤    ·                        ·    │      USER PROGRAM      │
│                        │    ·                        ·    │                        │
│         KERNEL         │    ├────────────────────────┤    │                        │
│                        │    │      _ENTRY/STACK      │    │                        │
├────────────────────────┤    ├────────────────────────┤    │                        │  0x80200000
│        OPEN SBI        │    │        OPEN SBI        │    │                        │
├────────────────────────┤    ├────────────────────────┤    ├────────────────────────┤  0x80000000
·                        ·    ·                        ·    ·                        ·
├────────────────────────┤    ├────────────────────────┤    ·                        ·
│          MMIO          │    │          MMIO          │    ·                        ·
├────────────────────────┤    ├────────────────────────┤    ·                        ·  0x10001000
·                        ·    ·                        ·    ·                        ·
└────────────────────────┘    └────────────────────────┘    └────────────────────────┘  0x0
```

File: src/mem.rs
```rust
pub const PM_BASE: usize = 0x80000000;
pub const VM_BASE: usize = 0xFFFFFFC080000000;
pub const VM_OFFSET: usize = VM_BASE - PM_BASE;
```

## Move the kernel

The kernel is moved by creating a *kernel pagetable*, which has

1. Identity mapping for the whole kernel image at its physical address (starting from `0x80000000`). This is done by registering a 1GB large page.

2. Another large page that maps `0xFFFFFFC080000000` to `0x80000000`.

File: src/kernel.rs
```rust
core::arch::global_asm! {r#"
    .section .text.entry

    .equ OFFSET, 0xFFFFFFC000000000
    .equ STACK_SIZE, 8 * 0x1000

    la t0, _pgtable

    srli t0, t0, 12

    li t1, 0x8 << 60
    or t0, t0, t1

    sfence.vma zero, zero
    csrw satp, t0
    sfence.vma zero, zero

    la sp, _stack
    li t0, OFFSET
    add sp, sp, t0

    ld t0, _main
    jr t0

    .globl _pgtable
    .align 12
    _pgtable:
        .zero 16
        .8byte 0x2000002F
        .zero 2040
        .8byte 0x2000002F
        .zero 2048

    .globl _stack
    .align 4
        .zero STACK_SIZE
    _stack:

    .globl _main
    _main:
        .8byte main
"#}
```

File: src/linker.ld
```
BASE_LMA = 0x0000000080200000;
BASE_VMA = 0xFFFFFFC080200000;
OFFSET = BASE_VMA - BASE_LMA;

SECTIONS
{
    . = BASE_LMA;

    .entry : { *(*.entry) }

    . = ALIGN(4K);
    . += OFFSET;

    .text : AT(. - OFFSET) { *(.*text*) }
    .data : AT(. - OFFSET) { *(.*data*) }

    .bss : AT(. - OFFSET) {
        sbss = .;
        *(.*bss*)
        ebss = .;
    }

    . = ALIGN(4K);
    ekernel = .;

    /DISCARD/ : {
        *(.eh_frame)
    }
}
```
