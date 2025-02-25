# Scheduling

> __Deadline & Submission__
>
> __Code Due__: Thursday 03/20 11:59pm
>
> * Use `make submission` to tarball and compress your code as `submission.tar.bz2`
> * Change the name of submission.tar.bz2 to `submission_yourStudentID.tar.bz2`, e.g., `submission_20000xxxxx.tar.bz2`
> * Submit this file to the `Lab1: Threads` on [PKU course website](https://course.pku.edu.cn/)
>
> __Design Doc Due__: Sunday 03/23 11:59pm
>
> * Submit your design document as a PDF to the `Lab1: Design Doc` on [PKU course website](https://course.pku.edu.cn/)

In this assignment, we give you a minimally functional thread system. Your job is to extend the functionality of this system to support priority scheduling. You will gain a better understanding of synchronization problems after finishing this project.

You will focus on the code under the `thread/` directory.

To complete this lab, the first step is to read and understand the code for the initial thread system. Tacos already implements **thread creation** and **thread completion**, **a FIFO scheduler** to switch between threads, and **synchronization primitives (semaphores, locks, condition variables)**. Some of the code might seem slightly mysterious. You can read through the [kernel thread](/3-kernelthread.md) part to see what's going on.
