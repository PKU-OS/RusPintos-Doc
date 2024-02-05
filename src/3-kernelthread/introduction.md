# Introduction

In this section, we will implement kernel thread in Tacos. Before delving into the details, let's take a look at the abstractions we're going to build. Thread API in Rust is neater than pthread, and we will support similar interfaces in Tacos. Understand `Send` and `Sync` traits will avoid a large proportion of concurrent bugs. Kernel thread and user thread are similar in many ways, so we will review the property of user threads and compare kernel threads and user threads. Finally, we will compare kernel threads and user threads as a conclusion to this section.

## Thread API in Rust

Now let's have a review of the how Rust models thread and relavent concepts, because we will implement similar APIs in the kernel(in `crate::thread`).

In Rust `std`, the thread creation function, `thread::spawn`, accepts a closure as it's main function. In contrast to POSIX, argument passing is made easy by using the [move](https://doc.rust-lang.org/book/ch13-01-closures.html#capturing-references-or-moving-ownership) keyword to capture the ownership of arguments that are carried along with the thread itself. The example shows a simple example of summing a vector in another thread.

```rust
use std::thread;

fn main() {
    let v: Vec<i32> = vec![1, 2, 3];

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

A type `T` is `Sync` if and only if `&T` is `Send`.

## Synchronization in Rust

Two primary methods exist for synchronization are message passing and shared memory. In Rust `std`, `channel`s are designed for message passing, while `Mutex`s are designed for accessing shared memory. Following example shows the usage of `Mutex` and `channel`.

```Rust
use std::sync::{Mutex, mpsc};
use std::thread;

static COUNTER: Mutex<i32> = Mutex::new(0);

fn main() {
    let (sx, rx) = mpsc::channel();
    sx.send(&COUNTER).unwrap();
    
    let handle = thread::spawn(move || {
        let counter = rx.recv().unwrap();
        for _ in 0..10 {
            let mut num = counter.lock().unwrap();
            *num += 1;
        }
    });
    
    for _ in 0..10 {
        let mut num = COUNTER.lock().unwrap();
        *num += 1;
    }
    
    handle.join().unwrap();
    
    println!("num: {}", COUNTER.lock().unwrap());
}
```

The type of the global variable `COUNTER` is `Mutex<i32>`, which implements the `Sync` trait. A global variable can be referenced by multiple threads, therefore we need `Sync` trait to avoid data races.

We use `channel` to pass a reference of `COUNTER` to another thread (remember that `&Mutex<i32>` is `Send`, allowing us to safely send it to another thread).

We use `Mutex` to ensure exclusive access. To access the data inside the mutex, we use the lock method to acquire the _lock_, which is a part of the `Mutex` struct. This call will block the current thread so it can’t do any work until it’s our turn to have the _lock_. The call to the `lock` method returns a smart pointer called `MutexGuard`, which implements `Deref` to point at our inner data, and implements `Drop` to release the lock automatically when a `MutexGuard` goes out of scope.

## User Threads v.s. kernel space

In this document, *user threads* refers to threads inside a user program. *User threads* are:

* in a same *program*, thus share the same *address space*
* running different tasks concurrently, thus each thread has an individual *stack*, *PC*, and *registers*

Similarly, *kernel threads* refers to threads inside the OS kernel. Like *user threads*, *kernel threads* are:

* in the same *kernel*, thus share the *kernel address space*
* running different tasks concurrently, thus each kernel thread has an individual *stack*, *PC*, and *registers*

Multi-threaded programming in user spaces uses APIs provided by the OS, such as [pthreads](https://man7.org/linux/man-pages/man7/pthreads.7.html)(You should be familar with it! You may have learned it in ICS. You should consider drop this course if you haven't learned it...). By using those APIs, the OS maintains the *address space*, *stack*, *PC* and *registers* for user. However, as we are implementing an OS, we have to build it from scratch and maintain those states manually. In the following parts of this chapter, we will build it step by step.

The table below compares the standard thread in modern OS and the kernel thread introduced in the section:

|               | Thread in modern OS | Kernel thread        |
| ------------- | ------------------- | -------------------- |
| Executes in   | user mode           | privileged mode      |
| Address space | user address space  | kernel address space |
| APIs          | pthread, etc.       | `crate::thread`      |
| States        | managed by OS       | managed by yourself  |

Currently Tacos does not support user threads. In this document, for the sake of brevity, when we use the term _thread_, it refers to to a _kernel thread_.
