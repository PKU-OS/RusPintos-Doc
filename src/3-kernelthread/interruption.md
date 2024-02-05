# Enable Preemptive Scheduling

We have already built basic thread interfaces. However, current implementation has a problem: if a thread never yields, other threads will be unable to make progress, which is unfair. Enable timer interrupt is a solution: after each interrupt happens, we call `schedule()`, force it to yield CPU to another thread (The scheduler will decide who runs next). This chapter is highly related to riscv's priviledge ISA. If you are unfamiliar with some CSRs(Control and Status Register) or some instructions(e.g. sret, ...), please refer to riscv's Priviledged Specifications. This [website](https://five-embeddev.com/riscv-isa-manual/latest/supervisor.html#supervisor-csrs) could also be helpful.

## Interrupts, Exceptions, and Traps

In riscv, interrupts are external asynchronous events, while exceptions are unusual conditions occurring at run time associated with an instruction in the current RISC-V hart. Interrupts and exceptions may cause the hart to experience an unexpected transfer of control. By definition, timer interrupt is a kind of interrupt. Unlike x86, where trap is a class of exceptions, trap refers to the *transfer of control flow* in riscv. When an interrupt or exception happens in rv64 (in Supervisor mode, where OS runs), following CSRs are effective:

* `stvec`(Supervisor Trap Vector Base Address Register): `stvec` specifies the base address of the trap vector, and the trap mode (vectored or direct)
* `sstatus`(Supervisor Status Register): `sstatus` has a bit named `SIE`, whose value decides whether interrupts in supervisor mode are enabled. Exceptions are always enabled.
* `sie`(Supervisor interrupt-enable register): `sie` has three bits: `SEIE`, `STIE` and `SSIE`, they decide whether External, Timer and Software interrupts are enabled in supervisor mode

For example, when a timer interrupt happens, if `sstatus.SIE=1 and sie.STIE=1`, then a trap happens, and the control will be transfered (i.e. PC will be set) to the address stored in `stvec`. When a trap happens, following CSRs are changed:

* `sstatus`: `sstatus` has another bit named `SPIE`, whose values will be set to the value of `sstatus.SIE` before the trap happens. `sstatus.SIE` will be set to 0.
* `scause`: set `scause` register to the cause of this trap. For example, if it is a timer interrupt, then `scause=TIMER_INTERRUPT_ID`
* `sepc`: will be set to the PC's value before the trap happens

After that, we will run the trap handler code. For example, when a timer interrupt happens and traps, we probably want to schedule another kernel thread. After the interrupt is handled, the standard way to exit the interrupt context is to use the `sret` instruction, which performs following operations:

* set `sstatus.SIE` to the value of `sstatus.SPIE`, and set `sstatus.SPIE` to 0
* set PC to the value of `sepc`, and set `sepc` to 0

We will enable timer interrupt in Tacos by using above features in riscv. Fortunately, the `riscv` crate capsules many riscv priviledged instructions, we don't have to write everything in assembly.

## Enable/Disable Interrupts, and set timer interval

Timer interrupts are not enabled automatically, we need to turn it on manually. Sometimes we want to turn it down to synchronize. Turn on/off the interrupt can be done by modifying `sstatus` or `sie` CSR. We choose to modify the `sie` register:

```Rust
#[inline]
fn on() {
    unsafe {
        register::sie::set_stimer();
    };
}

#[inline]
fn off() {
    unsafe {
        register::sie::clear_stimer();
    };
}

/// Get timer & external interrupt level. `true` means interruptible.
#[inline]
pub fn get() -> bool {
    register::sie::read().stimer()
}

/// Set timer & external interrupt level.
pub fn set(level: bool) -> bool {
    let old = get();

    // To avoid unnecessary overhead, we only (un)set timer when its status need
    // to be changed. Synchronization is not used between `get` and `on/off`, as
    // data race only happens when timer is on, and timer status should have been
    // restored before the preemptor yields.
    if old != level {
        if level {
            on();
        } else {
            off();
        }
    }

    old
}
```

In riscv, two CSRs decide the behavior of timer interrupt:

* `mtime`: the value of `mtime` increment at constant frequency. The frequency is known on qemu (12500000 per second)
* `mtimecmp`: when `mtime` is greater than `mtimecmp`, a timer interrupt is generated

We could use sbi calls to read `mtime` register:

```Rust
// src/sbi/timer.rs
pub const CLOCK_PRE_SEC: usize = 12500000;

/// Get current clock cycle
#[inline]
pub fn clock() -> usize {
    riscv::register::time::read()
}

/// Get current time in milliseconds
#[inline]
pub fn time_ms() -> usize {
    clock() * 1_000 / CLOCK_PRE_SEC
}

/// Get current time in microseconds
#[inline]
pub fn time_us() -> usize {
    clock() * 1_000_000 / CLOCK_PRE_SEC
}
```

or write `mtimecmp` register. Following code modifies the `mtimecmp` register to trigger a timer interrupt after 100ms = 0.1s.

```Rust
// src/sbi/timer.rs
/// Set the next moment when timer interrupt should happen
use crate::sbi::set_timer;
pub const TICKS_PER_SEC: usize = 10;

#[inline]
pub fn next() {
    set_timer(clock() + CLOCK_PRE_SEC / TICKS_PER_SEC);
}
```

## Trap Handler

Normally a trap handler contains 3 steps:

* preserve the current context
* handles the trap
* recover the context

Let's start with context preservation and recovery. A trap may be caused by an interrupt or an exception. When it is caused by an interrupt, it happens asychronously, which means a thread cannot expect the time when the interrupt happens. When a timer interrupt happens, if the current thread is not finished, we definitely want to resume the execution after the interrupt is handled. Therefore, every general purpose registers must be preserved. The trap process and the `sret` instruction uses `sepc` and `sstatus`, we should preserve them as well (if we want to support nested interrupt, which is inevitable in supporting preemptive scheduling). We use the `Frame` struct to preserve the context:

```Rust
// src/kernel/trap.rs
#[repr(C)]
/// Trap context
pub struct Frame {
    /// General regs[0..31].
    pub x: [usize; 32],
    /// CSR sstatus.
    pub sstatus: Sstatus,
    /// CSR sepc.
    pub sepc: usize,
}
```

And use following assembly code to preserve it, and pass a mutable reference to the `trap_handler` function in the `a0` register:

```Rust
// src/kernel/trap.rs
arch::global_asm! {r#"
    .section .text
        .globl trap_entry
        .globl trap_exit

    .align 2 # Address of trap handlers must be 4-byte aligned.

    trap_entry:
        addi sp, sp, -34*8

    # save general-purpose registers
        # sd x0, 0*8(sp)
        sd x1,   1*8(sp)
        # sd x2, 2*8(sp)
        sd x3,   3*8(sp)
        sd x4,   4*8(sp)
        sd x5,   5*8(sp)
        sd x6,   6*8(sp)
        sd x7,   7*8(sp)
        sd x8,   8*8(sp)
        sd x9,   9*8(sp)
        sd x10, 10*8(sp)
        sd x11, 11*8(sp)
        sd x12, 12*8(sp)
        sd x13, 13*8(sp)
        sd x14, 14*8(sp)
        sd x15, 15*8(sp)
        sd x16, 16*8(sp)
        sd x17, 17*8(sp)
        sd x18, 18*8(sp)
        sd x19, 19*8(sp)
        sd x20, 20*8(sp)
        sd x21, 21*8(sp)
        sd x22, 22*8(sp)
        sd x23, 23*8(sp)
        sd x24, 24*8(sp)
        sd x25, 25*8(sp)
        sd x26, 26*8(sp)
        sd x27, 27*8(sp)
        sd x28, 28*8(sp)
        sd x29, 29*8(sp)
        sd x30, 30*8(sp)
        sd x31, 31*8(sp)

    # save sstatus & sepc
        csrr t0, sstatus
        csrr t1, sepc
        sd   t0, 32*8(sp)
        sd   t1, 33*8(sp)

        mv   a0, sp
        call trap_handler


    trap_exit:

    # load sstatus & sepc
        ld   t0, 32*8(sp)
        ld   t1, 33*8(sp)
        csrw sstatus,  t0
        csrw sepc,     t1

    # load general-purpose registers
        # ld x0, 0*8(sp)
        ld x1,   1*8(sp)
        # ld x2, 2*8(sp)
        ld x3,   3*8(sp)
        ld x4,   4*8(sp)
        ld x5,   5*8(sp)
        ld x6,   6*8(sp)
        ld x7,   7*8(sp)
        ld x8,   8*8(sp)
        ld x9,   9*8(sp)
        ld x10, 10*8(sp)
        ld x11, 11*8(sp)
        ld x12, 12*8(sp)
        ld x13, 13*8(sp)
        ld x14, 14*8(sp)
        ld x15, 15*8(sp)
        ld x16, 16*8(sp)
        ld x17, 17*8(sp)
        ld x18, 18*8(sp)
        ld x19, 19*8(sp)
        ld x20, 20*8(sp)
        ld x21, 21*8(sp)
        ld x22, 22*8(sp)
        ld x23, 23*8(sp)
        ld x24, 24*8(sp)
        ld x25, 25*8(sp)
        ld x26, 26*8(sp)
        ld x27, 27*8(sp)
        ld x28, 28*8(sp)
        ld x29, 29*8(sp)
        ld x30, 30*8(sp)
        ld x31, 31*8(sp)

        addi sp, sp, 34*8
        sret
"#}

```

Before the `trap_exit` part, we called `trap_handler`, which is used to handle the interrupt or exception. When a trap happens, the

```Rust
// src/kernel/trap.rs
use riscv::register::scause::{
    Exception::{self, *},
    Interrupt::*,
    Trap::*,
};
use riscv::register::sstatus::*;
use riscv::register::*;

#[no_mangle]
pub extern "C" fn trap_handler(frame: &mut Frame) {
    let scause = scause::read().cause();
    let stval = stval::read();

    match scause {
        Interrupt(SupervisorTimer) => {
            sbi::timer::tick();
            unsafe { riscv::register::sstatus::set_sie() };
            thread::schedule();
        }

        _ => {
            unimplemented!(
                "Unsupported trap {:?}, stval={:#x}, sepc={:#x}",
                scause,
                stval,
                frame.sepc,
            )
        }
    }
}
```

Currently we only handle timer interrupts. Other interrupts/exceptions will be added with IO devices or user programs. We handle the timer interrupt in this way: first, we call `tick` to update the `TICKS` static variable, and call `next` reset the `mtimecmp` register:

```Rust
// src/sbi/timer.rs
static TICKS: AtomicI64 = AtomicI64::new(0);

/// Returns the number of timer ticks since booted.
pub fn timer_ticks() -> i64 {
    TICKS.load(SeqCst)
}

/// Update [`TICKS`] and set the next timer interrupt
pub fn tick() {
    TICKS.fetch_add(1, SeqCst);
    next();
}
```

Remember that when a trap happens, the `sstatus.SIE` will be set to 0. We then set it back to 1. After that, we simplt call `schedule()` to enforce the current thread to yield the CPU to another thread.

Congratulations! Now we have supported preemptive scheduling in Tacos. But the introduction of interrupts may cause problems with some of the original implementations. We need to resolve them with synchronizations.
