# Interruption and Exception

We have already built basic thread interfaces. However, current implementation has a problem: if a thread runs and never yields, other threads will be unable to make progress, which is unfair. Enable timer interrupt is a solution: after each interrupt happens, we call `schedule()` to force it to yield CPU to other threads (The scheduler will decide who runs next).

## Prepare the interrupt handler


