# Introduction

Before getting to the design and implementation of thread in our OS, let's have a brief review of the how Rust models thread and relavent concepts.

## Thread API in Rust

Thread APIs in Rust are much neater than [pthreads](https://man7.org/linux/man-pages/man7/pthreads.7.html), the POSIX thread programming interface. In Rust `std`, the thread creation function, `thread::spawn`, accepts a closure as it's main function. In contrast to POSIX, argument passing is made easy by using the [move](https://doc.rust-lang.org/book/ch13-01-closures.html#capturing-references-or-moving-ownership) keyword to capture the ownership of arguments that are carried along with the thread itself. The example shows a simple example of summing a vector in another thread. Our goal is to implement a similar API in our kernel.

```rust
use std::thread;

fn main() {
    let v = vec![1, 2, 3];

    let handle = thread::spawn(move || {
        v.into_iter().sum()
    });

    let sum: i32 = handle.join().unwrap();
    println!("{}", sum);
}
```

## The `Send` and `Sync` traits

The `Send` and `Sync` traits, together with the ownerhip system, are extensively used in Rust to eliminate data race in concurrent programming. This [document](https://doc.rust-lang.org/nomicon/send-and-sync.html) discusses these traits in depth, and here we explains some essential concepts that will be relavent to our implementation:

- `Sync` trait represents the ability of be referenced by multiple threads; therefore, a global variable in Rust must be `Sync`. Many types that we encounter when writing general purpose Rust code are `Sync`. However, data structures that contain raw pointers, no matter if they are `const` or `mut`, are generally not `Sync`. Raw pointers have no ownership, and lack exclusive access guarentee to the underlying data. Therefore, in the context of concurrent programming, most of the data structures we have defined so far can not be directly put in the global scope.

- `Send` trait is in some sense a weaker constraint, representing the safetyness of moving a type to another thread. For example, the `Cell` family is not `Sync` since it has no synchronization, but it is `Send`. Other types, such as `Rc<T>`, are neither `Sync` nor `Send`.

## Thread in the user v.s. kernel space

In our kernel, threads are designed to support background operations as well as user processes. In this section, we implement *kernel threads* to enable concurrent execution in the kernel space. Some of these threads will be used to support user programs, and some not. The table below compares the standard thread in modern OS and the kernel thread introduced in the section:

|               | Thread in modern OS | Kernel thread        |
| ------------- | ------------------- | -------------------- |
| Executes in   | user mode           | privileged mode      |
| Address space | user address space  | kernel address space |
| APIs          | pthread, etc.       | `crate::thread`      |
| Stack         | managed by OS       | acquired from palloc |

Since our OS is designed to run on a single-core processor, we do not support multiple user threads in a user process. Throughout this documentation, when we use the term _thread_, we are specifically referring to a _kernel thread_.
