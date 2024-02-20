# User Programs

> __Deadline & Submission__
>
> __Code Due__: Thursday 04/11 11:59pm
>
> * Use `make submission` to tarball and compress your code as `submission.tar.bz2`
> * Change the name of submission.tar.bz2 to `submission_yourStudentID.tar.bz2`, e.g., `submission_20000xxxxx.tar.bz2`
> * Submit this file to the `Tacos Lab2: User Programs` on [PKU course website](https://course.pku.edu.cn/)
>
> __Design Doc Due__: Sunday 04/14 11:59pm
>
> * Submit your design document as a PDF to the `Tacos Lab2: Design Doc Assignment` on [PKU course website](https://course.pku.edu.cn/)


Welcome to Project User Programs! You've built great threading features into TacOS. Seriously, that's some great work. This project will have you implement essential syscalls, supporting user programs to run properly on TacOS.

At the moment, the kernel can only load and run simple user programs that do nothing. In order to run more powerful user programs, you are going to implement essential syscalls, for example, enpowering user programs to perform I/O actions, spawning and synchronizing with child processes, and managing files just like what you might do in Linux.

It's _not required_ to complete this assignment on top of the last one, which means you can start freshly from the skeleton code. However, it's still suggested to continue with your previous work so that you can end up having an almost full-featured OS.

<!-- Todo: Introduce kernel functionalities (fs, page table, ...) and how to use them in a stand-alone chapter. -->
