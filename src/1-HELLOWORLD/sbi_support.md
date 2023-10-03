# SBI support

Up to now, we only have access to the CPU itself (and haven't managed to print `Hello, World!`). In this section, we will talk about how SBI helps us to do basic interactions with the platform.

## About SBI

Supervisor Binary Interface (SBI) provides us with a limited but out-of-box interface for interacting with the platform. As you all know, RISC-V has several privileged execution levels, and our OS runs in the middle: Supervisor (S)-mode. Firmware, on the other hand, runs on the Machine (M)-mode, and is responsible for backing up all platform-specific setups. SBI is the protocol that firmware uses to serve us, similar to syscall but at a lower abstraction level.

<img src="sbi-intro.png" width="100%">

We will not cover the tedious [calling specification](https://github.com/riscv-non-isa/riscv-sbi-doc/blob/master/riscv-sbi.adoc) here, and provide a macro that just does the job:

File: src/sbi.rs
```rust
macro_rules! call {

/* ---------------------------------- V0.1 ---------------------------------- */

    ( $eid: expr; $($args: expr),* ) => { call!($eid, 0; $($args),*).0 };

/* ---------------------------------- V0.2 ---------------------------------- */

    ( $eid: expr, $fid: expr; $($arg0: expr $(, $arg1: expr $(, $arg2: expr $(, $arg3: expr $(, $arg4: expr $(, $arg5: expr)?)?)?)?)?)? ) => {
        {
            let (err, ret): (usize, usize);
            unsafe {
                arch::asm!("ecall",
                    in("a7") $eid, lateout("a0") err,
                    in("a6") $fid, lateout("a1") ret,

                  $(in("a0") $arg0, $(in("a1") $arg1, $(in("a2") $arg2, $(in("a3") $arg3, $(in("a4") $arg4, $(in("a5") $arg5)?)?)?)?)?)?
                );
            }

            (err, ret)
        }
    };
}
```

Built on that, we have some useful wrapper functions:

File: src/sbi.rs
```rust
const SET_TIMER: usize = 0x00;
const CONSOLE_PUTCHAR: usize = 0x01;
const CONSOLE_GETCHAR: usize = 0x02;
const SHUTDOWN: usize = 0x08;

pub fn set_timer(timer: usize) {
    call!(SET_TIMER; timer);
}

pub fn console_putchar(char: usize) {
    call!(CONSOLE_PUTCHAR; char);
}

pub fn console_getchar() -> usize {
    call!(CONSOLE_GETCHAR;)
}

pub fn shutdown() -> ! {
    call!(SHUTDOWN;);
    unreachable!()
}
```

## Kernel output

Time to write our own output using the above SBI calls! Our own implementation of the `Write` trait will be used by `core::fmt` to output formatted string:

File: src/sbi/console.rs
```rust
struct Kout;
impl Write for Kout {
    fn write_str(&mut self, string: &str) -> fmt::Result {
        for char in string.chars() {
            console_putchar(char as usize);
        }
        Ok(())
    }
}

pub fn print(args: fmt::Arguments) {
    Kout.write_fmt(args).unwrap();
}

macro_rules! printk {
    ($fmt: literal $(, $arg: expr)*) => {
        $crate::sbi::console::print(format_args!(concat!("[{:012.2}] ", $fmt, "\n"), $crate::sbi::timer::time_us() $(, $arg)*));
    }
}
```

Putting them all together, let's say hello to the world and then gracefully exit:

File: src/main.rs
```rust
#[macro_use]
pub mod sbi;

#[no_mangle]
fn main() -> ! {
    printk!("Hello, World!");
    sbi::shutdown()
}

```
