# Design a file system

Finding and using the disk correctly is not the only requirement for running a file system. The disk and kernel must collaborate together to achieve this goal.

From a general view, a disk can be regarded as an array of bytes, which is accessed in sector granularity. The kernel must have the ability to recognize the format of these sectors and extract information from them correctly. Meanwhile, the sectors on the disk must be strictly arranged within the format. Such format is the file system we often refer to, but it will not form itself. We need to design a format before writing any file system code.

A typical size of sector is 512B, which is still widely used today. We will follow this configuration.

## Sector management

The first thing we concern about is the availability of each sector. Consider creating a new file. We want to place the file contents on some free sectors and don't want to overwrite the sectors that belong to other files. Thus, keep in track of the status of each sector is critical. 

Using a bitmap is a typical and sufficient way to achieve this. A bitmap is an array of bit, maintaining the status of an array of resources. Each bit records the 0-or-1 status of a individual resource. In our file system, we use a bitmap of sectors, where `0` means the sector is free, and `1` means the sector is occupied.

File: src/fs/disk/free_map.rs
```rust
struct FreeMap {
    size: u32,
    bits: Box<[u8]>,
}

impl FreeMap {
    fn get(&self, sector: u32) -> bool {
        assert!(sector < self.size);
        self.bits[sector as usize / 8] & (1 << sector % 8) != 0
    }

    fn set(&mut self, sector: u32) {
        assert!(sector < self.size);
        self.bits[sector as usize / 8] |= 1 << sector % 8;
    }

    fn reset(&mut self, sector: u32) {
        assert!(sector < self.size);
        self.bits[sector as usize / 8] &= !(1 << sector % 8);
    }
}
```

## Directory

With free map, we can manage the sectors correctly. Our next concern is to manage the files. 

TODO:???