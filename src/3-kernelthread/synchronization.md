# Synchronization

The implementation of the thread `Manager` need change after interrupts are enabled, we need to explicitly synchronize the `schedule` part. Kernel threads are running concurrently, synchronization enables them to cooperate. Therefore, synchronization primitives, such as `Mutex`s, should be implemented to help the kernel development.

## Update `Manager`: Synchronize by turning on/off the interrupts

After interrupts are turned on, timer interrupts could happen at any time. Interrupts happen in some critical sections may cause unexpected behaviors. For example, if a timer interrupt happens in `mem::replace` function in the `Manager.schedule()`, 

```Rust
// src/kernel/thread/manager.rs
// 
impl Manager {
    ...
    pub fn schedule(&self) {
        let next = self.scheduler.lock().schedule();

        if let Some(next) = next {
            assert_eq!(next.status(), Status::Ready);
            next.set_status(Status::Running);

            // If a timer interrupt happens here...
            let previous = mem::replace(self.current.lock().deref_mut(), next);

            let old_ctx = previous.context();
            let new_ctx = self.current.lock().context();

            unsafe { switch::switch(Arc::into_raw(previous).cast(), old_ctx, new_ctx) }
        }
    }
}
```
