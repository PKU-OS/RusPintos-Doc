# Debugging

## Print

The most useful debug tool must be directly print some messages to the console. `kprintln` is the kernel version of `println`, you can call it from almost anywhere in the kernel. `kprintln` is not just more than just examining data. It can also help figure out when and where something goes wrong, even when the kernel crashes or panics without a useful error message. You could thus narrow the problem down to a smaller amount of code, and even to a single instruction.

As you may have noticed, the `debug` cargo feature enables a lot of debug messages printed by `kprintln`. To run the empty example with `debug` feature, use following command in the project root directory:

```bash
cargo run -F debug
```

When you are debugging some test cases, running it with `debug` feature may (or may not) be helpful. You could use the testing tool in the `tool/` directory to find the testing command:

```bash
Workspace/tool/> cargo tt -c args-none --dry
Command for args-none:
cargo run -r -q -F test-user -- -append args-none
```

And then run it with `debug` feature (without the `-r` and `-q` option):

```bash
Workspace/tool/> cd ..
Workspace/> cargo -F test-user,debug -- -append args-none
```

## Assert

Assertions are also helpful for debugging, because they can catch problems early, before they'd otherwise be noticed. You could add assertions throughout the execution path where you suspect things are likely to go wrong. They are especially useful for checking loop invariants. They will invoke the `panic!` macro if the provided expression cannot be evaluated to true at runtime.

Following assertions may be helpful for your developent: `assert!`, `assert_eq!`, `assert_matches!`, ...

Our tests also use assertions to check your implementations.

## GDB

You can run Tacos under the supervision of the GDB debugger.

* First, you should start Tacos, and freeze CPU at startup, and open a remote gdb port to wait for connection. You could enable it by passing `-S` and `-s` option to qemu. For the empty example's execution, you could run following command in the project root directory:

```bash
/Workspace/> cargo run -- -s -S
```

For a particular test case, you could use the tool introduced in the test section, in `tool/` directory. For example, to debug the `args-none` testcase, you could start Tacos by:

```bash
/Workspace/tool> cargo gdb -c args-none
Use 'gdb-multiarch' to debug.
```

This may take some time, so please be patient.

* The next step is to use gdb to connect the guest kernel:

```bash
> gdb-multiarch
# In gdb, we've provided helpful tools.
# See ./.gdbinit for details.
# Load symbols of debug target.
(gdb) file-debug
# Get into qemu.
(gdb) debug-qemu
# Set breakpoints...
(gdb) b ...
# Start debugging!
(gdb) continue
```

FYI, `file-debug` and `debug-qemu` are gdb macros defined in `.gdbinit` file.

## Qemu

TBD
