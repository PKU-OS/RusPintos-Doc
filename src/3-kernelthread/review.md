# Review: Thread in user space

The term _thread_ always refers to the smallest sequence of programmed instructions that can be managed independently by a scheduler. In a specific thread, instructions are executed sequentially, while instructions in different threads run concurrently, potentially out of order unless explicitly synchronized. Modern CPUs are usually equipped with multiple cores, therefore running distinct tasks in separate threads often improves performance.

## Thread and Thread API in rust std library

Readers may be familiar with [pthreads](https://man7.org/linux/man-pages/man7/pthreads.7.html), the POSIX thread programming interface. While in rust, thread APIs are neater. Call `thread::spawn` will create a new thread, and call `thread::join` will wait until it terminates. Passing arguments to a thread is easy by using `move` closures. Following example uses those APIs to compute the sum of a `Vec<i32>` in another thread. Feel free to check out the details of [Rust Thread API](https://doc.rust-lang.org/book/ch16-01-threads.html) and [Rust `move` closure](https://doc.rust-lang.org/book/ch13-01-closures.html#capturing-references-or-moving-ownership) if you want to learn more.

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

## A rusty way to avoid data race: The `Send` and `Sync` trait

According to a [study of concurrency bugs in open source software](https://inria.hal.science/hal-01369048/file/426535_1_En_2_Chapter.pdf), nearly half of the concurrency bugs are data races. In the rust programming language, ownership together with the `Send` and `Sync` trait provide another way to avoid data races.

A type that implements the `Sync` trait means that it is safe to be referenced by multiple threads. Only one mutable reference to a value can exist at a time. This implies that only one thread will be able to modify the value at any given moment unless the value is interior mutable. Therefore, many types are `Sync`. For interior mutable types, the `Cell` family is not `Sync` because it doesn't guarantee mutually exclusive access to the inner value. If needed, [use `Mutex` instead](https://doc.rust-lang.org/book/ch16-03-shared-state.html#sharing-a-mutext-between-multiple-threads).

A type that implements `Send` trait can be sent to another thread safely. Many types implements `Send` trait. `Cell` family is not `Sync`, but it is `Send`.

Some types, such as `Rc<T>` and raw pointers, are neither `Sync` nor `Send`.

The [`Sync` and `Send`](https://doc.rust-lang.org/nomicon/send-and-sync.html) is helpful if you want to learn more about it.

## Back to Pintos: Thread in user space v.s. Kernel Thread in Pintos

In Pintos, kernel threads are designed to support background operations as well as user processes. Determined by the way you `spawn`, in another word, __create__ a kernel thread, it __may or may not__ be a user process. Following table compares thread in user space with kernel thread in Pintos.

|   |Thread in user space(on arbitrary OS)   |Kernel Thread in Pintos   |
|---|---|---|
|Executes in|User Mode|Kernel Mode|
|Address space|User address space|Kernel address space|
|APIs|pthread, rust std::thread, etc.|crate::thread|
|Stack|Managed by OS|Manually acquired from palloc|

Since Pintos is running on a single-core processor, we do not support multiple user threads in a process. Throughout the rest of this documentation, when we use the term _thread_, we are specifically referring to a _kernel thread_.
