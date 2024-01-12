# Page allocator

Our kernel is currently "static": all data structure's lifetime is determined at compile time. While the standard library allows `rustc` to compile code with dynamic memory allocation, we now need to implement this interface ourselves. But we haven't gone that far yet: we need to first define an interface that can manage *physical pages* - `4kb` segments in RAM.

File: src/mem/page.rs
```rust
pub const PGBITS: usize = 12;
pub const PGSIZE: usize = 1 << PGBITS;
pub const PGMASK: usize = PGSIZE - 1;

/// Page number of virtual address `va`.
pub fn number<T>(va: *const T) -> usize {
    va as usize >> PGBITS
}

/// Page offset of virtual address `va`.
pub fn offset<T>(va: *const T) -> usize {
    va as usize & PGMASK
}

/// Base address of the next page.
pub fn round_up<T>(va: *const T) -> usize {
    (va as usize + PGSIZE - 1) & !PGMASK
}

/// Base address of current page.
pub fn round_down<T>(va: *const T) -> usize {
    va as usize & !PGMASK
}
```

## In-memory lists

We need single-linked lists to manage page allocation, and as usual, we have to implement them on our own.

For someone who is new to Rust, this blog post [Learn Rust With Entirely Too Many Linked Lists](https://rust-unofficial.github.io/too-many-lists) is among the "must read" articles that explain the Rust memory system. It talks about how (hard) linked lists - probably the most basic data structure - can be implemented in Rust. But here we need something different: examples in that article rely on existing memory allocators. In our case, a large RAM segment is all we have. We need to directly read and write unstructured memory to build our lists.

File: src/mem/list.rs
```rust
#[derive(Clone, Copy)]
pub struct List {
    pub head: *mut usize,
}
```

The list is simply a raw pointer to the head node. Each node, not explicitly defined, is a `usize` in memory. Its content, interpreted as `*mut usize`, is also a memory address pointing to the next node. Now we implement how a memory address can be appended to and removed from the list:

File: src/mem/list.rs
```rust
impl List {
    pub const fn new() -> Self {
        List {
            head: core::ptr::null_mut(),
        }
    }

    pub unsafe fn push(&mut self, item: *mut usize) {
        *item = self.head as usize;
        self.head = item;
    }

    pub unsafe fn pop(&mut self) -> Option<*mut usize> {
        match self.head.is_null() {
            true => None,
            false => {
                let item = self.head;
                self.head = *item as *mut usize;

                Some(item)
            }
        }
    }

    pub fn iter_mut<'a>(&'a mut self) -> IterMut<'a> {
        IterMut {
            list: core::marker::PhantomData,
            node: Node {
                prev: core::ptr::addr_of_mut!(self.head) as *mut usize,
                curr: self.head,
            },
        }
    }
}
```

To help us traverse the list in an easy way, we also define a mutable iterator `struct IterMut` which remembers the previous node. The implementation is standard and the code is omitted for simplicity.

## Buddy allocation

We use the [buddy memory allocation scheme](https://wikipedia.org/wiki/Buddy_memory_allocation) to manage free and used pages.

File: src/mem/page.rs
```rust
use crate::mem::list::List;
const MAX_ORDER: usize = 10;

/// Buddy memory allocator.
pub struct Allocator([List; MAX_ORDER + 1]);

impl Allocator {
    pub const fn new() -> Self {
        Self([List::new(); MAX_ORDER + 1])
    }

    /// Register the memory segmant from `start` to `end` into the free list.
    pub unsafe fn insert_range(&mut self, start: *mut u8, end: *mut u8) {
        let (mut start, end) = (round_up(start), round_down(end));

        while start < end {
            let level = (end - start).next_power_of_two().trailing_zeros();
            let order = MAX_ORDER.min(level as usize - PGBITS);

            self.0[order].push(start as *mut usize);
            start += PGSIZE << order;
        }
    }

    /// Allocate `n` pages and return virtual address.
    pub unsafe fn alloc(&mut self, n: usize) -> *mut u8 {
        let order = n.next_power_of_two().trailing_zeros() as usize;

        for i in order..=MAX_ORDER {
            // Find a block of great order
            if !self.0[i].head.is_null() {
                for j in (order..i).rev() {
                    // Split the block into two sub-blocks
                    if let Some(full) = self.0[j + 1].pop() {
                        let half = full as usize + (PGSIZE << j);
                        self.0[j].push(half as *mut usize);
                        self.0[j].push(full);
                    }
                }

                return self.0[order].pop().unwrap().cast();
            }
        }

        panic!("memory exhausted");
    }

    /// Free `n` previously allocated physical pages.
    pub unsafe fn dealloc(&mut self, ptr: *mut u8, n: usize) {
        let order = n.next_power_of_two().trailing_zeros() as usize;

        // Fill it with trash to detect use-after-free
        core::ptr::write_bytes(ptr, 0x1C, n * PGSIZE);

        self.0[order].push(ptr.cast());
        let mut curr_ptr = ptr as usize;

        for i in order..=MAX_ORDER {
            let buddy = curr_ptr ^ (1 << i);

            // Try to find and merge blocks
            if let Some(block) = self.0[i].iter_mut().find(|blk| blk.curr as usize == buddy) {
                block.remove();

                // Merge two blocks into a larger one
                self.0[i + 1].push(curr_ptr as *mut _);
                self.0[i].pop();

                // Merged block of order + 1
                curr_ptr = curr_ptr.min(buddy);
            } else {
                break;
            }
        }
    }
}
```
