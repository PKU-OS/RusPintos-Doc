# Project 1 Grading Advice

This file contains advice for grading project 1.

## Alarm Clock

Usually, students solve this problem with a `Vec` of sleeping
threads and a timer interrupt handler that wakes up sleeping threads
at the appropriate time. Details that distinguish solutions include:

- Synchronization:
    - Prefer `Arc<Threads>` over raw pointers. Raw pointers may cause use-after-drop or thread memory leak.
    - Use `Intr` as the lock and CANNOT use `Sleep` or `Spin`.
    - `Semaphore` or `CondVar` are usually not required.
- Ordering: Good solutions order `Arc<Threads>` by wake-up time. And only need their timer interrupt to examine as many items in the list as are actually waking up on this tick (plus one). Otherwise, every sleeping thread must be examined (and possibly modified).
- Time left vs. wake-up time: Good solutions store the wake-up time in the list, instead of the number of ticks remaining.
- `Vec` vs. `BTreeMap`: Both data structure are acceptable. With `BTreeMap`, sleeping threads are ordered naturally. But be cautious if the student argues that `BTreeMap` is faster. Sorting a `Vec` has a higher complexity but a smaller constant factor.
- Wake-one vs. wake-all: Good solutions wake up all the threads that are scheduled to wake up at a particular timer tick. Bad solutions only wake up one thread and delay waking the next until the following timer tick.
- Coding Style:
    - Names of things should make sense.
    - Code and report should be formatted in a consistent way.
    - Don't use `unsafe` when there are available safe tools. For example, it's a good practice to use `Lazy` to initialize global variables.

## PRIORITY SCHEDULING

Priority scheduling by itself is a simple exercise.  Priority donation
is more difficult.  Many groups do not seem to completely grasp the
structure of priority donation.  Some properties of priority donation
that you may find useful while grading:

- A thread has to maintain two priority values — the original one and the received (from donors) one.
- A thread can only directly donate its priority to at most one donee thread at a time, because donation only occurs when a thread is blocked waiting for a lock, and a thread can only block waiting for a single lock at a time. This property means that each thread can keep track of its donee, if any, with a single `Arc<Thread>` in struct `Thread`.
- A thread can receive donations from any number of threads, because any number of threads can wait on a lock. The donors may be waiting for a single lock or multiple locks. These first two properties, taken together, mean that a thread should keep a "list" of its donor threads, and usually a `Vec` is sufficient.
- Donations can nest to form a tree, but circularity is impossible as long as no deadlock in the locking structure exists. Deadlock would itself be a bug, so there is no need to worry about circularity in donations.
- If a thread's priority has changed, it's necessary to update all its donees' priorities recursively.
