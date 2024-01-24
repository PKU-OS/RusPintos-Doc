# Tasks

## Design Doc

Download the [design document template](https://github.com/PKU-OS/pintos/blob/master/docs/p1.md) of project 1. Read through questions in the document for motivations, and fill it in afterwards.

## Alarm Clock

Reimplement `sleep()` in `kernel/thread.rs` to avoid busy waiting. The prototype of `sleep()` is:

```Rust
// src/kernel/thread.rs
pub fn sleep(ticks: i64)
```

The `sleep()` function:

* Suspends execution of the calling thread until time has advanced by __at least__ `ticks` timer ticks.
* Unless the system is otherwise idle, the thread __need not__ wake up after exactly ticks. Just put it on the ready queue after they have waited for the right amount of time.
* The argument to `sleep()` is expressed in timer ticks, not in milliseconds or any another unit. There are `TICKS_PER_SEC` timer ticks per second, where `TICKS_PER_SEC` is a const value defined in `sbi/timer.rs`. The default value is 10. We don't recommend changing this value, because any change is likely to cause many of the tests to fail.

> __Note__
>
> In Windows and Linux, the `sleep` function may block for longer than the requested time due to scheduling or resource contention delays. In fact, only __real-time operating systems(RTOS)__ could guarantee exact sleep interval. In practice, if you do need fine-grained timing control, it is better to sleep for a bit less than the amount of time you want to wait for, and then wake up and spin.

`sleep()` is useful for threads that operate in real-time, e.g. for blinking the cursor once per second. Although a working implementation is provided, it "busy waits," that is, it spins in a loop checking the current time and calling `schedule()` until enough time has gone by. You are supposed to reimplement it to avoid busy waiting.

The alarm clock implementation is __not__ needed for other parts of this project. But it is still suggested to implement the alarm clock first.

> __Hint__
>
> You need to decide where to check whether the elapsed time exceeded the sleep time.
>
> * The original `sleep()` implementation calls `timer_ticks()`, which returns the current ticks.
> * You may want to check where the static `TICKS` variable in `src/sbi/timer.rs` is updated.

> __Hint__
>
> * You may want to leverage some synchronization primitives that provides some sort of thread "waiting" functionality, e.g., semaphore.
> * In addition, when modifying some global variable, you will need to use some synchronized data structures to ensure it is not modified or read concurrently (e.g., a timer interrupt occurs during the modification and we switch to run another thread). You may find `Mutex` struct inplemented in `src/kernel/sync/mutex.rs` to be useful in this project, and the following ones.

> __Hint__
>
> You may find some data structures provided by `alloc` crate to be useful in this project, and the following ones. 
>
> * The `alloc` crate provides `Vec`, `VecDeque`, `BTreeMap` and many useful data structures. As you may have noticed, the FIFO scheduler uses `VecDeque`.
> * Feel free to choose appropriate data structures to support your design!

## Priority Scheduling

### Basic Priority Scheduling

In Priority Scheduling, thread with higher priority should always go first. If another thread with higher priority is ready to run, the current thread should immediately __yield__ the processor to the new thread. Therefore, your scheduler should ensure that for any ready thread A and B:

* If Priority(A) > Priority(B), A runs (B doesn't).
* If Priority(A) == Priority(B), A and B run in RR (Round Robin).

For example, if a kernel thread A creates another kernel thread B with higher priority, A should immediately yield the processor to B, because A and B are ready, and Priority(A) < Priority(B). Things are similar when some threads are waken up.

> __Tip__
>
> In Tacos, thread priorities range from __`PRI_MIN` (0) to `PRI_MAX` (63)__. Lower numbers correspond to lower priorities, so that priority 0 is the lowest priority and priority 63 is the highest. Each thread has an initial priority after it is created. Most thread use __`PRI_DEFAULT` (31)__ as its priority. The `PRI_` constants are defined in `src/kernel/thread/imp.rs`, and you should not change their values.

In addition, for threads that are waiting for a lock, semaphore or condition variable, the highest priority waiting thread should be awakened first. Therefore, you may need to modify implementation of lock, semaphore and condition variable to ensure this.

A thread may also raise or lower its own priority at any time. Lowering its priority such that it no longer has the highest priority must cause it to immediately __yield__ the CPU. In this part, your should also implement `set_priority()` and `get_priority()` to support priority changing. Their prototypes are:

```Rust
/// In src/kernel/thread.rs
pub fn set_priority(_priority: u32)
pub fn get_priority() -> u32
```

> __Hint__
>
> * For this practice, you need to consider __all the scenarios__ where the priority must be enforced. You can find some of these scenarios by looking for places that uses the `Schedule` trait (directly and indirectly). Look at test cases under the `src/tests/` directory may be helpful.
> * To yield the CPU, you can check the APIs in `src/kernel/thread.rs`.

<!-- TODO: 在完成了这部分之后，哪些 testcase 应该能够 pass -->

### Priority Donation

One issue with priority scheduling is __"priority inversion"__. Consider high, medium, and low priority threads H, M, and L, respectively. If H needs to wait for L (for instance, for a lock held by L), and M is on the ready list, then H will never get the CPU because the low priority thread will not get any CPU time.

A partial fix for this problem is for H to __"donate"__ its priority to L while L is holding the lock, then __recall the donation__ once L releases (and thus H acquires) the lock. Generally, your scheduler must support following functionality:

* __Multiple donations__: multiple priorities are donated to a single thread.
* __Nested donations__: H is waiting on a lock that M holds, and M is waiting on a lock that L holds, then both M and L should be boosted to H's priority.
* __Get effective priority__: if H is waiting on a lock that L holds, then the `get_priority()` called by L should return H's priority.

You are __not required__ to implement priority donations for __semaphores__. Implement it for locks is enough.

__The priority scheduler is not used in any later project.__
