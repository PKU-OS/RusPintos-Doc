# Suggestions

## Development Suggestions

### Understanding Threads

To complete this lab, the first step is to read and understand the code for the initial thread system. Tacos already implements **thread creation** and **thread completion**, **a FIFO scheduler** to switch between threads, and **synchronization primitives (semaphores, locks, condition variables, and optimization barriers)**. Some of the code might seem slightly mysterious. You can read through the [kernel thread](3-kernelthread.md) part to see what's going on. Understand normal thread in user spaces will be helpful, but not necessary. You can find introduction to threads in any OS textbook (including CSAPP).
<!-- ! Do we have Optimization Barriers? -->

### Use Source Code Control System (e.g. Git)

In this lab, you will extensively modify the origin thread implementation, including but not limited to the parts mentioned in the previous section. If you do not want to lose the last working copy, then it's crucial that you use a source code control system to manage your changes. For this class we recommend that you use Git. If you don't already know how to use Git, we recommend that you read the Pro Git book online.

## Suggestion Order of Implementation

We suggest first implementing the following, which can happen in parallel:

* Optimized timer_sleep() in Exercise 1.1.
* Basic support for priority scheduling in Exercise 2.1 when a new thread is created.
* Then you can add full support for priority scheduling in Exercise 2.1 by considering all other possible scenarios and the synchronization primitives.
* Then it is time to support priority donations.
