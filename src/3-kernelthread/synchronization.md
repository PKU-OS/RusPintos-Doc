# Synchronization

The implementation of the thread `Manager` need change after interrupts are enabled, we need to explicitly synchronize the `schedule` part. Kernel threads are running concurrently, synchronization enables them to cooperate. Therefore, synchronization primitives, such as `Mutex`s, should be implemented to help the kernel development.

## Update `Manager`: Synchronize by turning on/off the interrupts

After interrupts are turned on, timer interrupts could happen at any time. Interrupts happen in some critical sections may cause unexpected behaviors. For example, the `schedule` method will modify the global `Manager`'s states. We clearly do not want be interrupted when the kernel is changing those states (e.g. in `Manager.schedule()`). Therefore, we could disable the interrupt before the critical section, and restore the interrupt setting when the thread is scheduled again:

```Rust
// src/kernel/thread/manager.rs
impl Manager {
    pub fn schedule(&self) {
        let old = interrupt::set(false);

        ... // original implementation

        // Back to this location indicating that the running thread has been shceudled.
        interrupt::set(old);
    }
}
```

All threads should enable interrupt before entering:

```Rust
// src/kernel/thread/imp.rs
#[no_mangle]
extern "C" fn kernel_thread(main: *mut Box<dyn FnOnce()>) -> ! {
    interrupt::set(true);
    ...
}
```

## Implement `Semaphore`: Synchronize by blocking waiter threads

The implementation of `Semaphore` needs the `block` function, which will block the current thread and yield the CPU. The blocked thread can be waken by another thread:

```Rust
/// Mark the current thread as [`Blocked`](Status::Blocked) and
/// yield the control to another thread
pub fn block() {
    let current = current();
    current.set_status(Status::Blocked);

    schedule();
}

/// Wake up a previously blocked thread, mark it as [`Ready`](Status::Ready),
/// and register it into the scheduler.
pub fn wake_up(thread: Arc<Thread>) {
    assert_eq!(thread.status(), Status::Blocked);
    thread.set_status(Status::Ready);

    Manager::get().scheduler.lock().register(thread);
}
```

With `block` and `wake_up`, `Semaphore` could be implemented in this way:

```Rust
// src/kernel/sync/sema.rs
pub struct Semaphore {
    value: Cell<usize>,
    waiters: RefCell<VecDeque<Arc<Thread>>>,
}

unsafe impl Sync for Semaphore {}
unsafe impl Send for Semaphore {}

impl Semaphore {
    /// Creates a new semaphore of initial value n.
    pub const fn new(n: usize) -> Self {
        Semaphore {
            value: Cell::new(n),
            waiters: RefCell::new(VecDeque::new()),
        }
    }

    /// P operation
    pub fn down(&self) {
        let old = sbi::interrupt::set(false);

        // Is semaphore available?
        while self.value() == 0 {
            // `push_front` ensures to wake up threads in a fifo manner
            self.waiters.borrow_mut().push_front(thread::current());

            // Block the current thread until it's awakened by an `up` operation
            thread::block();
        }
        self.value.set(self.value() - 1);

        sbi::interrupt::set(old);
    }

    /// V operation
    pub fn up(&self) {
        let old = sbi::interrupt::set(false);
        let count = self.value.replace(self.value() + 1);

        // Check if we need to wake up a sleeping waiter
        if let Some(thread) = self.waiters.borrow_mut().pop_back() {
            assert_eq!(count, 0);

            thread::wake_up(thread.clone());
        }

        sbi::interrupt::set(old);
    }

    /// Get the current value of a semaphore
    pub fn value(&self) -> usize {
        self.value.get()
    }
}
```

`Semaphore` contains a value and a vector of waiters. The down operation may cause a thread to block, if so, the following up operations are responsible to wake it up. To use the `Semaphore` in different threads, we need it to be `Sync` and `Send`. It is obvious `Send`, because `Cell` and `Refcell` are `Send`. What about `Sync`? Fortunately it is indeed `Sync`, because we disable interrupts when modifying the cells -- otherwise a struct contains a cell is not, in most cases, `Sync`.

## Implement locks and `Mutex`: Synchronize by disabling interrupt, spining or blocking waiter threads

We uses `Mutex` very frequently in Tacos, but we haven't implemented it yet. To build `Mutex`, we need to take a look at locks first. Locks support two types of operations: acquire and release. When a lock is initialized, it is free (i.e. could be acquired). A lock will be held until it explicitly releases it. Following trait illustrates the interface of lock:

```Rust
pub trait Lock: Default + Sync + 'static {
    fn acquire(&self);
    fn release(&self);
}
```

There are three different ways to implement this trait, the first (and the simplest) way is to change the interrupt status. The `Intr` struct implements the `Lock` trait:

```Rust
// src/kernel/sync/intr.rs
#[derive(Debug, Default)]
pub struct Intr(Cell<Option<bool>>);

impl Intr {
    pub const fn new() -> Self {
        Self(Cell::new(None))
    }
}

impl Lock for Intr {
    fn acquire(&self) {
        assert!(self.0.get().is_none());

        // Record the old timer status. Here setting the immutable `self` is safe
        // because the interrupt is already turned off.
        self.0.set(Some(sbi::interrupt::set(false)));
    }

    fn release(&self) {
        sbi::interrupt::set(self.0.take().expect("release before acquire"));
    }
}

unsafe impl Sync for Intr {}
```

> __Exercise__
>
> `Intr` is a `Cell`. Is it safe to implement `Sync` for it?

The `Spin` struct shows a spinlock implementation. Since `AtomicBool` is `Sync` and `Send`, it could be automatically derived:

```Rust
#[derive(Debug, Default)]
pub struct Spin(AtomicBool);

impl Spin {
    pub const fn new() -> Self {
        Self(AtomicBool::new(false))
    }
}

impl Lock for Spin {
    fn acquire(&self) {
        while self.0.fetch_or(true, SeqCst) {
            assert!(interrupt::get(), "may block");
        }
    }

    fn release(&self) {
        self.0.store(false, SeqCst);
    }
}
```

We could also let the waiters block. In fact, we could just reuse `Semaphore`:

```Rust
#[derive(Clone)]
pub struct Sleep {
    inner: Semaphore,
}

impl Default for Sleep {
    fn default() -> Self {
        Self {
            inner: Semaphore::new(1),
        }
    }
}

impl Lock for Sleep {
    fn acquire(&self) {
        self.inner.down();
    }

    fn release(&self) {
        self.inner.up();
    }
}

unsafe impl Sync for Sleep {}
```

Based on `Lock`s, build a `Mutex` is easy. A `Mutex` contains the real data (encapsuled in a cell to gain innter mutability), and a lock. The `lock` method acquires the lock and returns the `MutexGuard`. The `MutexGuard` is a smart pointer, and could be auto-dereferenced to data's type. On drop, the `MutexGuard` releases the lock:

```Rust
// src/kernel/sync/mutex.rs
#[derive(Debug, Default)]
pub struct Mutex<T, L: Lock = sync::Primitive> {
    value: UnsafeCell<T>,
    lock: L,
}

// The only access to a Mutex's value is MutexGuard, so safety is guaranteed here.
// Requiring T to be Send-able prohibits implementing Sync for types like Mutex<*mut T>.
unsafe impl<T: Send, L: Lock> Sync for Mutex<T, L> {}
unsafe impl<T: Send, L: Lock> Send for Mutex<T, L> {}

impl<T, L: Lock> Mutex<T, L> {
    /// Creates a mutex in an unlocked state ready for use.
    pub fn new(value: T) -> Self {
        Self {
            value: UnsafeCell::new(value),
            lock: L::default(),
        }
    }

    /// Acquires a mutex, blocking the current thread until it is able to do so.
    pub fn lock(&self) -> MutexGuard<'_, T, L> {
        self.lock.acquire();
        MutexGuard(self)
    }
}

/// An RAII implementation of a “scoped lock” of a mutex.
/// When this structure is dropped (falls out of scope), the lock will be unlocked.
///
/// The data protected by the mutex can be accessed through
/// this guard via its Deref and DerefMut implementations.
pub struct MutexGuard<'a, T, L: Lock>(&'a Mutex<T, L>);

unsafe impl<T: Sync, L: Lock> Sync for MutexGuard<'_, T, L> {}

impl<T, L: Lock> Deref for MutexGuard<'_, T, L> {
    type Target = T;

    fn deref(&self) -> &T {
        unsafe { &*self.0.value.get() }
    }
}

impl<T, L: Lock> DerefMut for MutexGuard<'_, T, L> {
    fn deref_mut(&mut self) -> &mut T {
        unsafe { &mut *self.0.value.get() }
    }
}

impl<T, L: Lock> Drop for MutexGuard<'_, T, L> {
    fn drop(&mut self) {
        self.0.lock.release();
    }
}
```

## Implement condition variable

Rust std crate provides an implementation of conditional variable. Following implementation is heavily influenced by the std version:

```Rust
// src/kernel/sync/condvar.rs
pub struct Condvar(RefCell<VecDeque<Arc<Semaphore>>>);

unsafe impl Sync for Condvar {}
unsafe impl Send for Condvar {}

impl Condvar {
    pub fn new() -> Self {
        Condvar(Default::default())
    }

    pub fn wait<T, L: Lock>(&self, guard: &mut MutexGuard<'_, T, L>) {
        let sema = Arc::new(Semaphore::new(0));
        self.0.borrow_mut().push_front(sema.clone());

        guard.release();
        sema.down();
        guard.acquire();
    }

    /// Wake up one thread from the waiting list
    pub fn notify_one(&self) {
        self.0.borrow_mut().pop_back().unwrap().up();
    }

    /// Wake up all waiting threads
    pub fn notify_all(&self) {
        self.0.borrow().iter().for_each(|s| s.up());
        self.0.borrow_mut().clear();
    }
}
```

A tricky part is that we need to release and re-acquire the lock when we are using it to wait for a condition. The `wait` method takes a `MutexGuard` as the argument. Therefore, we implement `release` and `acquire` for `MutexGuard`:

```Rust
// Useful in Condvar
impl<T, L: Lock> MutexGuard<'_, T, L> {
    pub(super) fn release(&self) {
        self.0.lock.release();
    }

    pub(super) fn acquire(&self) {
        self.0.lock.acquire();
    }
}
```

## `OnceCell` and `Lazy`: Ensure global values are initialized once

Rust discourages global variables -- at least `Sync` trait is enforced. But we do need global variables, and we may need runtime information (e.g. DRAM size) to properly initialize it. `OnceCell` and `Lazy` is the solution. Like `Condvar`, they exist in std library, and the current implementation is influenced by std version. Because it is not highly related to the labs, we omit the details of the implementation. You are free to read it under the `sync/` directory.
