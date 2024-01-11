# Background

## Understanding Threads







> Hints
> Feel free to add calls to printf() almost anywhere, then recompile and run to see what happens and in what order.
> You can also run the kernel in a debugger and set breakpoints at interesting spots, single-step through code and examine data, and so on.

### Create a New Thread

When a thread is created, you are creating a new context to be scheduled. You provide a function to be run in this context as an argument to thread_create().

The first time the thread is scheduled and runs, it starts from the beginning of that function and executes in that context.
When the function returns, the thread terminates. Each thread, therefore, acts like a mini-program running inside Pintos, with the function passed to thread_create() acting like main().
At any given time, exactly one thread runs and the rest, if any, become inactive. The scheduler decides which thread to run next.
If no thread is ready to run at any given time, then the special "idle" thread, implemented in idle(), runs.
Synchronization primitives can force context switches when one thread needs to wait for another thread to do something.
Context Switch
The mechanics of a context switch are in threads/switch.S, which is 80x86 assembly code. (You don't have to understand it.)
It saves the state of the currently running thread and restores the state of the thread we're switching to.
Using the GDB debugger, slowly trace through a context switch to see what happens (see section GDB).
You can set a breakpoint on schedule() to start out, and then single-step from there.
Be sure to keep track of each thread's address and state, and what procedures are on the call stack for each thread.
You will notice that when one thread calls switch_threads(), another thread starts running, and the first thing the new thread does is to return from switch_threads().
You will understand the thread system once you understand why and how the switch_threads() that gets called is different from the switch_threads() that returns. See section Thread Switching, for more information.