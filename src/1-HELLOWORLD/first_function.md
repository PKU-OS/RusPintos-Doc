# First function

We just ran our first instruction in the kernel. Let's keep going, and have some "fun-ctions" this
time.

```rust
#[no_mangle]
extern "C" fn main() { loop {} }
```

Here is our first function. You can notice a few things: `#[no_mangle]` prevents the function's name
from being mangled by the compiler, which allows us to reference the "main" symbol in assembly code.
Also, `extern "C"` tells the compiler to conform C-language's calling convention. (Removing the
`extern "C"` probably won't break our code, but keeping it ensures the code always perform as
expected.)

```rust
core::arch::global_asm! {r#"
    .global _entry
    _entry:
        li sp, 0x80400000
        j main
"#}
```

The next step is to set up the stack correctly, and then "jump" to our target. The `0x80400000` is
just a random but safe address to use as the stack. (In the future, we will set up the stack in a
more thoughtful way.)

Now type `cargo run` in your shell, and we see nothing different as expected (bacause all we added
is just an empty loop).

Then, type in `ctrl-a c` to enter the qemu moniter:

```sh
QEMU 7.0.0 monitor - type 'help' for more information
(qemu)
```

Now keep going and type in `(qemu) info registers` to inspect all registers in the machine emulated
by qemu. And then, you can see `pc 000000008020000c` on top of the output (though pc's value might
vary).

```sh
riscv64-unknown-elf-objdump -S target/riscv64gc-unknown-none-elf/debug/rus_pintos_tutorial > kernel.asm
```

Next, open another shell and run the command above. In file `kernel.asm`, you can see
`8020000c: a001   j 8020000c <main+0x2>`, which shows that our code did enter the `main` function as
expected.
