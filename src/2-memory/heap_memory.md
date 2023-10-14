# Heap memory

In the previous section, we implemented a page allocator that can manage physical pages. Now we are ready to implement fine-grained dynamic allocation, and make full use of the Rust memory system.

## Arena allocation

We use arena memory allocation for fine-grained memory management. We will not cover the details for now. In the end, we have defined a struct that does similar job as the page allocator, except that the allocation unit is byte instead of physical page:

File: src/mem/heap.rs
```rust
pub struct Allocator {
    fields omitted...
}

impl Allocator {
    pub const fn new() -> Self;

    /// Allocates a memory block that is in align with the layout.
    pub unsafe fn alloc(&mut self, layout: Layout) -> *mut u8;

    /// Deallocates a memory block
    pub unsafe fn dealloc(&mut self, ptr: *mut u8, layout: Layout);
}
```

## Rust global allocator

We want to make use of Rust built-in data structures: `Box`, `Vec`, etc. This is made possible by implementing the [GlobalAllocator](https://doc.rust-lang.org/stable/std/alloc/trait.GlobalAlloc.html) trait, provided by the standard library. This is an interface that `std` will make use of to implement downstream data structures as mentioned before. One could of course go implement them from scratch, but why not go with an easier way:

File: src/mem.rs
```rust
pub static HEAP: heap::Allocator = heap::Allocator::new();

pub struct Malloc;
unsafe impl GlobalAlloc for Malloc {
    unsafe fn alloc(&self, layout: Layout) -> *mut u8 {
        HEAP.alloc(layout)
    }

    unsafe fn dealloc(&self, ptr: *mut u8, layout: Layout) {
        HEAP.dealloc(ptr, layout)
    }
}

#[global_allocator]
static MALLOC: Malloc = Malloc;
```
