# Tasks

> __Suggestion__
>
> Please read through this document before working on any task.

## Design Document

<!-- todo: tweak the old design document? -->
Download the [design document template](https://github.com/PKU-OS/Tacos/blob/main/doc/lab2.md) of project 2. Read through questions in the document for motivations, and fill it in afterwards.

## Argument Passing

Currently, the `fn execute(mut file: File, argv: Vec<String>)` does not pass arguments to new processes. You need to implement it in this task.

* Currently the `argv` argument is not used. To implement this functionality, you need to __pass the `argv` to the user program__.
* The kernel must put the arguments for the initial function on the __stack__ to allow the user program to assess it. The user program will access the arguments following the normal calling convention (see [RISC-V calling convention](https://riscv.org/wp-content/uploads/2015/01/riscv-calling.pdf)).
* You can impose a reasonable limit on the length of the command line arguments. For example, you could limit the arguments to those that will __fit in a single page (4 kB)__.

> __Hint__
>
> You can parse argument strings any way you like. A viable implementation maybe like:
>
> 1. Put `String`s in the `argv` at the top (high address) of the stack. You should terminate those string with `"\0"` when putting them on the stack.
> 2. Push the address of each string (i.e. the contents of user `argv[]`) on the stack. Those values are pointers, you should align them to 8 bytes to ensure fast access. Don't forget that `argv[]` ends with a `NULL`. 
> 3. Prepare the argument `argc` and `argv`, and then deliver them to the user program. They are the first and second arguments of `main`.
>
> Here is an [argument passing example](https://pkuflyingpig.gitbook.io/pintos/project-description/lab2-user-programs/background#argument-passing) in 80x86 provided by Pintos. Use the example to help you understand how to set up the stack.

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

> __Note__
>
> Every user program that finishes in normally calls exit – even a program that returns from main calls exit indirectly.

### exec

```C
int exec(const char* pathname, const char* argv[]);
```

Runs the executable whose path is given in `pathname`, passing any given arguments, and returns the new process’s program id (pid). `argv` is a `NULL`-terminated array of arguments, where the first argument is usually the executable's name. If the program cannot load or run for any reason, return -1. Thus, the parent process cannot return from a call to exec until it knows whether the child process successfully loaded its executable. You must use appropriate synchronization to ensure this.

> __Note__
>
> Keep in mind `exec` is different from Unix `exec`. It can be thought of as a Unix `fork` + Unix `exec`.

> __Tip: Access User Memory Space__
>
> `exec` is the first syscall where a user passes a pointer to the kernel. Be careful and check if the pointer is valid. You may look up the page table to see if the pointer lays in a valid virtual memory region. Also, do make sure that each character within a string has a valid address. Don't just check the first address.
>
> With any invalid arguments, it's just fine to return -1. As for other syscalls with pointer arguments, please always check the validity of their memory addresses.

### wait

```C
int wait(int pid);
```

Waits for a child process pid and retrieves the child’s exit status. If pid is still alive, waits until it terminates. Then, returns the status that pid passed to exit. If pid did not call exit but was terminated by the kernel (e.g. killed due to an exception), wait must return -1. It is perfectly legal for a parent process to wait for child processes that have already terminated by the time the parent calls wait, but the kernel must still allow the parent to retrieve its child’s exit status, or learn that the child was terminated by the kernel.

wait must fail and return -1 immediately if any of the following conditions are true:

- pid does not refer to a **direct** child of the calling process. pid is a direct child of the calling process if and only if the calling process received pid as a return value from a successful call to exec. Note that children are not inherited: if A spawns child B and B spawns child process C, then A cannot wait for C, even if B is dead. A call to wait(C) by process A must fail. Similarly, orphaned processes are not assigned to a new parent if their parent process exits before they do.

- The process that calls wait has already called wait on pid. That is, a process may wait for any given child **at most once**.

Processes may spawn any number of children, wait for them in any order, and may even exit without having waited for some or all of their children. Your design should consider all the ways in which waits can occur. All of a process’s resources, including its struct thread, **must be freed** whether its parent ever waits for it or not, and regardless of whether the child exits before or after its parent.

> __Tip__
>
> Implementing wait requires considerably more work than the other syscalls. Schedule your work wisely.

## File Operation Syscalls

In addition to process control syscalls, you will also implement the following file operation syscalls,
including `open`, `read`, `write`, `remove`, `seek`, `tell`, `fstat`, `close`. A lot of syscalls, right? Don't worry. It's not hard at all to implement them, as the skeleton code has a basic **thread-safe** file system already. Your implementations will simply call the appropriate functions in the file system library.

### open

```C
int open(const char* pathname, int flags);
```

Opens the file located at `pathname`. If the specified file does not exist, it may **optionally** (if `O_CREATE` is specified in `flags`) be created by `open`. Returns a non-negative integer handle called a *file descriptor* (fd), or -1 if the file could not be opened.

The argument `flags` must include one of the following *access modes*: `O_RDONLY`, `O_WRONLY`, or `O_RDWR`.  These request opening the file read-only, write-only, or read/write, respectively.

File descriptors numbered 0 and 1 are reserved for the console: 0 is standard input and 1 is standard output. `open` should never return either of these file descriptors, which are valid as system call arguments only as explicitly described below.

Each process has an **independent** set of file descriptors. File descriptors in TacOS are not inherited by child processes.

When a single file is opened more than once, whether by a single process or different processes, each open returns a new file descriptor. Different file descriptors for a single file are closed independently in separate calls to `close` and they **do not share** a file position.

### read

```C
int read(int fd, void* buffer, unsigned size);
```

Reads `size` bytes from the file open as `fd` into buffer. Returns the number of bytes actually read (0 at end of file), or -1 if the file could not be read (due to a condition other than end of file, such as fd is invalid). File descriptor 0 reads from the keyboard.

### write

```C
int write(int fd, const void* buffer, unsigned size);
```

Writes `size` bytes from buffer to the open file with file descriptor `fd`. Returns the number of bytes actually written. Returns -1 if fd does not correspond to an entry in the file descriptor table. Writing past end-of-file would normally extend the file, and file growth is implemented by the basic file system.

File descriptor 1 writes to the console. You can simply use the `kprint` macro which also applys a lock on `Stdout` for you, making sure that output by different processes won't be interleaved on the console.

> **Tip**
>
> Before you implement syscall `write` for fd 1, many test cases won't work properly.

### remove

```C
int remove(const char* pathname);
```

Deletes the file at `pathname`. Returns 0 if successful, -1 otherwise. A file may be removed regardless of whether it is open or closed, and removing an open file does not close it.

> **What happens when an open file is removed?**
>
> You should implement the standard Unix semantics for files. That is, when a file is removed any process which has a file descriptor for that file may continue to use that descriptor. This means that they can read and write from the file. The file will not have a name, and no other processes will be able to open it, but it will continue to exist until all file descriptors referring to the file are closed or the machine shuts down.

### seek

```C
void seek(int fd, unsigned position);
```

Changes the next byte to be read or written in open file `fd` to `position`, expressed in bytes from the beginning of the file (0 is the file’s start). If fd does not correspond to an entry in the file descriptor table, this function should do nothing.

A seek past the current end of a file is not an error. A later read obtains 0 bytes, indicating end of file. A later write extends the file, filling any unwritten gap with zeros. These semantics are implemented in the file system and do not require any special effort in the syscall implementation.

### tell

```C
int tell(int fd)
```

Returns the position of the next byte to be read or written in open file `fd`, expressed in bytes from the beginning of the file. If the operation is unsuccessful, it returns -1.

### fstat

```C
// user/lib/fstat.h
typedef struct {
    uint64 ino;     // Inode number
    uint64 size;  // Size of file in bytes
} stat;

int fstat(int fd, stat* buf);
```

Fills the `buf` with the statistic of the open file `fd`. Returns -1 if fd does not correspond to an entry in the file descriptor table.

### close

```C
int close (int fd);
```

Closes file descriptor `fd`. Exiting or terminating a process must implicitly close all its open file descriptors, as if by calling this function for each one. If the operation is unsuccessful, it returns -1.
