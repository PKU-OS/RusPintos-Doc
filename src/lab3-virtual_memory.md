# Virtual Memory

> __Deadline & Submission__
>
> __Code Due__: Thursday 05/30 11:59pm
>
> * Use `make submission` to tarball and compress your code as `submission.tar.bz2`
> * Change the name of submission.tar.bz2 to `submission_yourStudentID.tar.bz2`, e.g., `submission_20000xxxxx.tar.bz2`
> * Submit this file to the `Tacos Lab3: Virtual Memory` on [PKU course website](https://course.pku.edu.cn/)
>
> __Design Doc Due__: Sunday 06/02 11:59pm
>
> * Submit your design document as a PDF to the `Tacos Lab3: Design Doc Assignment` on [PKU course website](https://course.pku.edu.cn/)

By now you have already touched almost every modules in Tacos. Tacos's thread module supports multiple threads of execution, and a thread could potentially be a process and execute any user programs. Syscalls, as the interface between user and OS, allow user programs to perform I/O or wait for other workers. However, it cannot fully utilize the machine -- for example, the user stack size is limited to 4KiB.

In this assignment, you will extend Tacos's virtual memory module. This assignment is **extremely challenging**, you will spend tons of time dealing with complex concurrency problems. You will extend the functionality of `mem/` module, but you also need to modify things under other subdirectories, such as the page fault handler, to support your design.

You are **required** to start your lab3 implementation from a working lab2 implementation. To get a full score, you will need to pass all the tests in lab2 and lab3. See the [testing](lab3-virtual_memory/testing.md) page for details.
