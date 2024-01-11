# Your Tasks

## Task 0: Design Doc

## Task 1: Alarm Clock

### Exercise 1.1

Reimplement `sleep()` in `kernel/thread.rs` to avoid busy waiting.

> ### Function: `fn sleep(ticks: i64)`
>
> * Suspends execution of the calling thread until time has advanced by at least ticks timer ticks.
> * Unless the system is otherwise idle, the thread need not wake up after exactly ticks. Just put it on the ready queue after they have waited for the right amount of time.
> * `sleep()` is useful for threads that operate in real-time, e.g. for blinking the cursor once per second.
> * The argument to `sleep()` is expressed in timer ticks, not in milliseconds or any another unit. There are `TICKS_PER_SEC` timer ticks per second, where `TICKS_PER_SEC` is a const value defined in `sbi/timer.rs`. The default value is 10. We don't recommend changing this value, because any change is likely to cause many of the tests to fail.
<!-- ! Default TICKS_PER_SEC=? -->

* Although a working implementation is provided, it "busy waits," that is, it spins in a loop checking the current time and calling `schedule()` until enough time has gone by.
* Reimplement it to avoid busy waiting.



