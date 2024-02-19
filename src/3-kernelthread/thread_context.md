# Support different tasks: Thread context

Now we are going to build data structures to support executing a specific task in a kernel thread! Tacos wasn't built in a day, as well as its thread module. Let's begin with the simplest scenario: support only the creation of a thread, in another word, we are going to implement following function:

```Rust
/// Create a new thread
pub fn spawn<F>(name: &'static str, f: F) -> Arc<Thread>
where
    F: FnOnce() + Send + 'static,
{
    ...
}
```

Running a thread has not yet been supported! We will discuss running a thread later.

> __Exercise__
>
> What is the meaning of the clause `where F: FnOnce() + Send + 'static`? Why do we need `F` to be `Send`? What is the meaning of `'static`?

## The `Thread` struct and its member

As mentioned in the previous part, the context of a kernel thread contains *address spaces*, *stack*, *PC*, and *registers*. To create a kernel thread, we must build a set of context. Address spaces are decided by the pagetable. Fortunately, kernel threads share the same address space, which means we do not need to create a new one. But for other parts of the context, we have to build datastructures to maintain them. We will discuss `Thread` struct first.

```Rust
// src/kernel/thread/imp.rs
#[repr(C)]
pub struct Thread {
    tid: isize,
    name: &'static str,
    stack: usize,
    context: Mutex<Context>,
    ...
}

impl Thread {
    pub fn new(
        name: &'static str,
        stack: usize,
        entry: usize,
        ...
    ) -> Self {
        /// The next thread's id
        static TID: AtomicIsize = AtomicIsize::new(0);

        Thread {
            tid: TID.fetch_add(1, SeqCst),
            name,
            stack,
            context: Mutex::new(Context::new(stack, entry)),
            ...
        }
    }

    pub fn context(&self) -> *mut Context {
        (&mut *self.context.lock()) as *mut _
    }
    ...
}
```

`Thread` is a *thread control block(TCB)*. Above code shows the definition of the `Thread` struct(We omit some fields for brevity. Those fields will be discussed in the following parts). Each `Thread` has a `tid`, which is used to identify a thread. `TID` is an incrementing static variable, we use it to assign distinct `tid`s for threads. `name` is set to help the debug process. The `stack` and `context` is used to record the context of the `Thread`. We will discuss them immediately.

## Maintain stack for kernel thread

To execute a task, a thread may allocate variables on stack, or call other functions. Either operation needs a runtime stack. As you may have remembered, in the [Hello World](../1-HELLOWORLD.md) section we manually allocated the stack for the first function in `src/main.rs`. After page allocator is ready, we are free to allocate dynamic memory and use it as a stack. In Tacos, we alloc 16KB for a thread stack(luxury!). Following code shows the allocation of stack:

```Rust
// src/kernel/thread.rs
pub fn spawn<F>(name: &'static str, f: F) -> Arc<Thread>
where
    F: FnOnce() + Send + 'static,
{
    ...
    let stack = kalloc(STACK_SIZE, STACK_ALIGN) as usize;
    ...

    // Return created thread:
    Arc::new(Thread::new(name, stack, ...))
}
```

We record that stack in `Thread` and use `kfree` to deallocate the stack as the thread terminates.

## Maintain registers for kernel thread

Each thread holds a set of general purpose registers. In `riscv`, they are `x0~x31` (checkout this [link](https://five-embeddev.com/quickref/regs_abi.html) for more details). As we create a new thread in Tacos, we should set the initial value of `x0~x31`. When we are switching to another thread (we will cover the details in the next section), those values should also be saved properly. We use `Context` struct to represent recorded registers:

```Rust
// src/kernel/thread/imp.rs
/// Records a thread's running status when it switches to another thread,
/// and when switching back, restore its status from the context.
#[repr(C)]
#[derive(Debug)]
pub struct Context {
    /// return address
    ra: usize,
    /// kernel stack
    sp: usize,
    /// callee-saved
    s: [usize; 12],
}

impl Context {
    fn new(stack: usize, entry: usize) -> Self {
        Self {
            ra: kernel_thread_entry as usize,
            // calculate the address of stack top
            sp: stack + STACK_SIZE,
            // s0 stores a thread's entry point. For a new thread,
            // s0 will then be used as the first argument of `kernel_thread`.
            s: core::array::from_fn(|i| if i == 0 { entry } else { 0 }),
        }
    }
}
```

Let we skip the `kernel_thread_entry` and the argument `entry` for a while -- and focus on the fields of `Context` struct. The `sp` stores the stack pointer, the `ra` stores the return address, and the `s` array stores the callee saved registers in `riscv`, named `s0~s11` (In `riscv`, a register could be referenced by its alias. For example, `sp` is the alias of `x2`).

In the `Thread` struct, the type of the `context` field is `Mutex<Context>`, however the type `stack`, `name` and `tid` are just basic types. Why? That is because `stack`, `name` and `tid` is immutable after a `Thread` struct is constructed, they remains unchanged until it drops. But the `context` field is mutable, and we do need to change it when we are switching to another thread. `Mutex` is added to obtain *innter mutability* and we will implement it later (The interface is like `std::Mutex`). You will get a better understanding after we covered the context switching part.

You may want to ask: in the `Context` struct, only 1 + 1 + 12 = 14 registers are saved. What about other registers? Where should we save them? What should their initial values be set to? That is a good question! The short answer is: the initial value of any register is not important (In fact, you could pass an argument to the thread use some of the registers: for example, in Tacos we use `s0` to pass a pointer), and caller saved registers are saved on the stack during context switching. We will explain the details in the next section.

## Capture the closure as the main function

We have already allocated spaces for a thread's execution, now it is time to give it a task. The `spawn` accepts a closure, which is the main funtion of another thread, and belongs to the thread. Therefore, we must support *inter-thread communication* and pass the closure to another thread. Remember that kernel threads shares the same address space -- which means we could simply put the closure on the heap, and read it from another thread. Following code shows how we store it on the heap:

```Rust
// src/kernel/thread.rs
pub fn spawn<F>(name: &'static str, f: F) -> Arc<Thread>
where
    F: FnOnce() + Send + 'static,
{
    // `*mut dyn FnOnce()` is a fat pointer, box it again to ensure FFI-safety.
    let entry: *mut Box<dyn FnOnce()> = Box::into_raw(Box::new(Box::new(function)));
    let stack = kalloc(STACK_SIZE, STACK_ALIGN) as usize;
    ...

    Arc::new(Thread::new(name, stack, entry, ...))
}
```

Just to remind you, the `entry` passed to `Thread::new` will be passed to the `Context::new`, and then recorded in the initial `context`. Which means, when a thread is about to start, its `s0` register is an pointer to its main function, a boxed closure. (Of course we need some extra works to implement this! But please pretend that we could do this.)

In order to read the closure in another thread, we wrote two functions: `kernel_thread_entry` and `kernel_thread`:

```Rust
// src/kernel/thread/imp.rs
global_asm! {r#"
    .section .text
        .globl kernel_thread_entry
    kernel_thread_entry:
        mv a0, s0
        j kernel_thread
"#}

#[no_mangle]
extern "C" fn kernel_thread(main: *mut Box<dyn FnOnce()>) -> ! {
    let main = unsafe { Box::from_raw(main) };

    main();

    thread::exit();
}
```

`kernel_thread_entry` is a little bit tricky. It is the real entry point of spawned thread, reads the value in `s0` (the pointer), and move it to `a0` register (the first argument), and jump (call also works) to the `kernel_thread` function. The `kernel_thread` function reads the boxed closure and run the closure, and calls an exit function to terminate the thread.

## Put it together: the thread `Manager`

The kernel maintains a table of active threads. When a thread is created, the thread is added to the table. When a thread exits, the thread is removed from the table. In Tacos, we use `Manager` struct as that table. You can think of it as a singleton.

```Rust
// src/kernel/thread/manager.rs
pub struct Manager {
    /// All alive and not yet destroyed threads
    all: Mutex<VecDeque<Arc<Thread>>>,
    ...
}

impl Manager {
    /// Get the singleton.
    pub fn get() -> &'static Self { ... }

    pub fn resiter(&self, thread: Arc<Thread>) {
        // Store it in all list.
        self.all.lock().push_back(thread.clone());

        ...
    }
}
```

> __Exercise__
>
> The type of the `all` field is `Mutex<...>`. Why?

The `spawn` function should register the thread to the `Manager`.

```Rust
// src/kernel/thread.rs
pub fn spawn<F>(name: &'static str, f: F) -> Arc<Thread>
where
    F: FnOnce() + Send + 'static,
{
    // `*mut dyn FnOnce()` is a fat pointer, box it again to ensure FFI-safety.
    let entry: *mut Box<dyn FnOnce()> = Box::into_raw(Box::new(Box::new(function)));
    let stack = kalloc(STACK_SIZE, STACK_ALIGN) as usize;
    ...

    let new_thread = Arc::new(Thread::new(name, stack, entry, ...));
    Manager::get().register(new_thread.clone());

    new_thread
}
```

Congratulations! Now you could create a new thread in Tacos.
