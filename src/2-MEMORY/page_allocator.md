# Page allocator

Our kernel is currently static for now: all data structure's lifetime is determined at compile time. While the standard library allows `rustc` to compile code with dynamic memory allocation, we now need to implement this interface ourselves. But we haven't gone that far yet: we need to first define an interface that can manage *physical pages* - `4kb` segments in RAM.

## In-memory lists

We need single-linked lists to manage page allocation, and as usual, we have to implement them on our own.

For someone who is new to Rust, this blog post [Learn Rust With Entirely Too Many Linked Lists](https://rust-unofficial.github.io/too-many-lists) is among the "must read" articles that explain the Rust memory system. It talks about how (hard) linked lists - probably the most basic data structure - can be implemented in Rust. But here we need something different: examples in that article rely on existing memory allocators. In our case, a large RAM segment is all we have. We need to directly read and write unstructured memory to build our lists.

File: src/mem/palloc.rs
```rust
#[derive(Clone, Copy)]
struct List(*mut usize);
```

The list is simply a raw pointer to the head node. Each node, not explicitly defined, is a `usize` in memory. Its content is also a memory address pointing to the next node. Now we implement how a memory address can be appended to and removed from the list:

File: src/mem/palloc.rs
```rust
impl List {

    const fn new() -> Self { List(core::ptr::null_mut()) }

    unsafe fn push(&mut self, item: *mut usize) {
        *item = self.0 as usize;
        self.0 = item;
    }

    unsafe fn pop(&mut self) -> Option<*mut usize> {
        match self.0.is_null() {
            true => None,
            false => {

                let item = self.0;
                self.0 = *item as *mut usize;

                Some(popped_item)
            }
        }
    }

}
```

To help us traverse the list in a easy way, let's define a mutable iterator which remembers the previous node:

File: src/mem/palloc.rs
```rust
struct IterMut<'list> {
    _: PhantomData<&'list mut List>,

    prev: *mut usize,
    curr: *mut usize,
}

struct ListNode {
    prev: *mut usize,
    curr: *mut usize,
}

impl ListNode {

    unsafe fn remove(self) {
        *(self.prev) = *(self.curr);
    }

}

impl<'list> Iterator for IterMut<'list> {
    type Item = ListNode;

    fn next(&mut self) -> Option<Self::Item> {
        match self.curr.is_null() {
            true => None,
            false => {

                let node = ListNode {
                    prev: self.prev,
                    curr: self.curr,
                };

                self.prev = self.curr;
                self.curr = unsafe { *self.curr as *mut usize };

                Some(node)
            }
        }
    }
}
```

## Buddy allocation

We use the [buddy memory allocation scheme](https://wikipedia.org/wiki/Buddy_memory_allocation) to manage free and used pages.

File: src/mem/palloc.rs
```rust
pub const PG_SHIFT: usize = 12;
pub const PG_SIZE: usize = 1 << PG_SHIFT;

struct Allocator {
    /// The i-th free list is in charge of memory chunks of 2^i pages
    free_lists: [InMemList; Self::MAX_ORDER + 1],
}

impl Allocator {
    const MAX_ORDER: usize = 10;

    /// This struct can not be moved due to self reference.
    /// So, construct it and then call `init`.
    const fn empty() -> Self {
        Self {
            free_lists: [List::new(); Self::MAX_ORDER + 1],
        }
    }

    /// Take the memory segmant from `start` to `end` into page allocator's record
    unsafe fn insert_range(&mut self, start: usize, end: usize) {
        let start = round_up(start, PG_SIZE);
        let end = round_down(end, PG_SIZE);

        let prev_power_of_two = |n: usize| -> usize {
            if n.is_power_of_two() {
                n
            } else {
                n.next_power_of_two() / 2
            }
        };

        let mut current_start = start;
        while current_start < end {
            // find the biggest possible size of the next block, which must
            // align to its size (start_address % size == 0).
            let size = min(
                1 << current_start.trailing_zeros(),
                prev_power_of_two(end - current_start),
            );
            // The order we found cannot exceed the preset maximun order
            let order = min(size.trailing_zeros() as usize - PG_SHIFT, Self::MAX_ORDER);
            self.free_lists[order].push(current_start as *mut usize);
            current_start += (1 << order) * PG_SIZE;
        }
    }

    /// Allocate n pages and returns the virtual address.
    ///
    /// Buddy allocator guarantees that an allocated block
    /// of 2^n pages will align to 2^n pages.
    unsafe fn alloc(&mut self, n: usize) -> *mut u8 {
        assert!(n <= 1 << Self::MAX_ORDER, "request is too large");

        let order = n.next_power_of_two().trailing_zeros() as usize;
        for i in order..self.free_lists.len() {
            // Find the first non-empty list
            if !self.free_lists[i].is_empty() {
                // Split buffers (from large to small groups)
                for j in (order..i).rev() {
                    // Try to find a large block of group j+1 and then
                    // split it into two blocks of group j
                    if let Some(block) = self.free_lists[j + 1].pop() {
                        let half = (block as usize + (1 << j) * PG_SIZE) as *mut usize;
                        self.free_lists[j].push(half);
                        self.free_lists[j].push(block);
                    }
                }
                return self.free_lists[order].pop().unwrap().cast();
            }
        }

        panic!("memory exhausted");
    }

    /// Deallocate a chunk of pages
    unsafe fn dealloc(&mut self, ptr: *mut u8, n: usize) {
        // fill the freed memory with trash to detect use-after-free
        core::ptr::write_bytes(ptr, 0x1c, n * PG_SIZE);

        let order = n.next_power_of_two().trailing_zeros() as usize;
        self.free_lists[order].push(ptr.cast());

        // Merge free lists
        let mut curr_ptr = ptr as usize;
        let mut curr_order = order;

        while curr_order < self.free_lists.len() {
            // Find the buddy block of the current block
            let buddy = curr_ptr ^ (1 << curr_order);
            // Try to find and merge blocks
            if let Some(blk) = self.free_lists[curr_order].iter_mut()
                                   .find(|blk| blk.curr as usize == buddy)
            {
                blk.pop();
                // Merge two blocks into a bigger one
                self.free_lists[curr_order].pop();
                self.free_lists[curr_order + 1].push(curr_ptr as *mut _);
                // Attempt to form a even bigger block in the next iteration
                curr_order += 1;
                curr_ptr = min(curr_ptr, buddy);
            } else {
                break;
            }
        }
    }
}
```
