# First function

No one would ever want to write an OS in assembly. This section aims to transfer the control flow to Rust.

## From assembly to Rust

Recall that in the previous section, we've compiled and linked the instruction `addi x0, x1, 42` to the correct place. Following this line, let's jump:

File: src/main.rs
```rust
#[no_mangle]
extern "C" fn main() -> ! { loop {} }

arch::global_asm! {r#"
    .section .text.entry
        li sp, 0x80400000
        j main
"#}
```

An empty `main` is created and the dummy `addi` is replaced with `j`. A few other things happened here:

- The `extern "C"` is part of the Foreign Function Interface (FFI) - a set of compiler arguments to make foreign function calls are compatible. Since we are transfering from assembly, which is not part of the Rust standard, `rustc` is free to changing the calling convention in the future. This attribute ensures `j main`, the way function get called in `C`, always works.

- The `#[no_mangle]` attribute asks the compiler not to mess up the name `main`. If not, `rustc` will probably rename it to something like `__ZN6pintos4main17h704e3c653e7bf0d3E` - not sweet for someone who need to directly reference the symbol in assembly.

- The stack pointer is initialized by some memory address. Page fault will be raised once `sp` is accessed to save call stack. Again, `0x80400000` is an arbitrary address which will not overlap with anything useful, for now.

## More sections

The above `main` is probably too naïve. Let's add some Rust-y magic:

File: src/main.rs
```rust
static ZERO: u32 = 0;
static DATA: u32 = 0xDEADBEEF;

#[no_mangle]
extern "C" fn main() -> ! {

    assert!(ZERO == 0);
    assert!(DATA != 0);

    for i in Fib(1, 0).take(10000) { drop(i) }

    loop {}
}

struct Fib(usize, usize);
impl Iterator for Fib {

    type Item = usize;
    fn next(&mut self) -> Option<usize> {

        let value = self.0 + self.1;

        self.1 = self.0;
        self.0 = value;

        Some(value)
    }
}

arch::global_asm! {r#"
    .section .text.entry
        li sp, 0x80400000
        j main
"#}
```

The linker script in the previous section probably won't work now. There are multiple segments in `.text`, and we need to make sure the assembly snippet is executed first. Apart from this, there're also data segments and we need to include them to the linker:

File: src/linker.ld
```
SECTIONS
{
    . = 0x0000000080200000;
    .entry : { *(*.entry) }

    .text : { *(.*text*) }
    .data : { *(.*data*) }

    .bss : {
        sbss = .;
        *(.*bss*)
        ebss = .;
    }

    /DISCARD/ : { *(.eh_frame) }
}
```

## Don't forget B.S.S.

As you've probably noticed, we left some symbols in `.bss`. It's always good to keep in mind that no one is doing anything for us, including clearing up the `.bss` segment. Forgetting to do so probably works fine on a simulator - but will definitely cause trouble on real machines.

File: src/main.rs
```rust
extern "C" {
    fn sbss();
    fn ebss();
}

#[no_mangle]
extern "C" fn main() -> ! {

    unsafe { ptr::write_bytes(sbss as *mut u8, 0, ebss as usize - sbss as usize) };

    ...
}
```