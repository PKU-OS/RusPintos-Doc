# Tasks

## Design Document

Download the [design document template](https://github.com/PKU-OS/pintos/blob/master/docs/p2.md) of project 2. Read through questions in the document for motivations, and fill it in afterwards.

<!-- todo: maybe  -->
## Process Control Syscalls

TacOS currently supports only one syscall — `exit`, which terminates the calling process. You will add support for the following new syscalls: `halt`, `exec`, `wait`.

Rust has no stable application binary interfaces at the moment. Therefore, all syscalls are represented in C signiture and user programs are also written in C. (Though, it's not hard at all to write a Rust user program if you try.)

The capability of switching in/out of the user mode is well handled by the skeleton code, and arguments passed by users will be forwarded to:

```Rust
// src/kernel/trap/syscall.rs
pub fn syscall_handler(id: usize, args: [usize; 3]) -> isize
```

`id` and `args` are the number identifier and arguments (at most 3) of the syscall being called, and the return value equals the syscall's return value.

Basically, you dispatch an environment call from users to one of syscalls based on the `id`. Then, implement each syscall's functionality as described below.

### halt

```C
void halt(void);
```

Terminates TacOS by calling the `shutdown` function in `src/sbi.rs`. This should be seldom used, because you lose some information about possible deadlock situations, etc.

### exit

```C
void exit(int status);
```

Terminates the current user program, returning status to the kernel. If the process’s parent waits for it (see below), this is the status that will be returned. Conventionally, a status of 0 indicates success and non-zero values indicate errors.

```admonish
Every user program that finishes in normally calls exit – even a program that returns from main calls exit indirectly.
```

### exec

```C
int exec(const char* file, const char* argv[]);
```

Runs the executable whose path is given in `file`, passing any given arguments, and returns the new process’s program id (pid). `argv` is a `NULL`-terminated array of arguments, where the first argument is always the path of the executable. On success, return 0; if the program cannot load or run for any reason, return -1. Thus, the parent process cannot return from a call to exec until it knows whether the child process successfully loaded its executable. You must use appropriate synchronization to ensure this.


```admonish
Keep in mind `exec` is different from Unix `exec`. It can be thought of as a Unix `fork` + Unix `exec`.
```

## File Operation Syscalls
