# Members of a kernel thread

This section introduces the members of a kernel thread.

## States of a kernel thread

At a given time, a thread can be in one of four states: `Running`, `Ready`, `Blocked` and `Dying`. `Running` simply means the thread is running. A thread in `Ready` state is ready to run. `Blocked` threads are blocked for different reasons(e.g. IO, wait for another thread to terminate, etc.). `Dying` is a little bit tricky, we label a thread as `Dying` to release its resources in the (hopefully near) future. The state transitions are illustrated in the followin graph.

<img src="state.png" width="100%">

Those states can be found in:

File: TODO

```rust
/// States of a thread's life cycle
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Status {
    /// Not running but ready to run
    Ready,
    /// Currently running
    Running,
    /// Waiting for an event to trigger
    Blocked,
    /// About to be destroyed
    Dying,
}
```

## Context of a kernel thread: enable time-sharing

Our OS is running on a single-core processor, which is shared by multiple kernel threads. When a kernel thread is descheduled by OS, it should save the current context(general purpose registers, PC, etc.), and restore the context when it is scheduled by OS. The context of a thread could be represented in following struct:

```rust
/// Records a thread's running context when it switches to another thread,
/// and when switching back, restore it.
#[repr(C)]
#[derive(Debug)]
pub struct Context {
    /// return address
    ra: usize,
    /// kernel stack
    sp: usize,
    /// callee-saved registers
    s: [usize; 12],
}
```

## Other fields of a kernel thread: tid, name and stack

We need a `tid` to identify a thread. `name` is set to help us debug. As mentioned in the previous section, we need to manually get stack from page allocator, `stack` is set to remember the pointer and free it when the kernel thread exits.

```rust
/// All data of a kernel thread
#[repr(C)]
pub struct Thread {
    tid: isize,
    name: &'static str,
    stack: usize,
    status: Mutex<Status>,
    context: Mutex<Context>,
}
```

## Interfaces of Kernel Thread

Before we get into the details of implementing kernel threads, it is worthwhile to look at the design of kernel thread interfaces. Some of them are inspired by rust std library, others are closely related to the states of a kernel thread.

File: TODO

```rust
/// Create a new thread
pub fn spawn<F>(name: &'static str, f: F) -> Arc<Thread>
where
    F: FnOnce() + Send + 'static,
{ ... }

/// Yield the control to another thread (if there's another one ready to run).
pub fn schedule() { ... }

/// Gracefully shut down the current thread.
pub fn exit() -> ! { ... }

/// Mark the current thread as [`Blocked`](Status::Blocked) and
/// yield the control to another thread
pub fn block() { ... }

/// Wake up a previously blocked thread, mark it as [`Ready`](Status::Ready),
/// and register it into the scheduler.
pub fn wake_up(thread: Arc<Thread>) { ... }
```
