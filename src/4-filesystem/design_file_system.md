# Design a file system

Finding and using the disk correctly is not the only requirement for running a file system. The disk and kernel must collaborate together to achieve this goal.

From a general view, a disk can be regarded as an array of bytes, which is accessed in sector granularity. The kernel must have the ability to recognize the format of these sectors and extract information from them correctly. Meanwhile, the sectors on the disk must be strictly arranged within the format. Such format is the file system we often refer to, but it will not form itself. We need to design a format before writing any file system code.

A typical size of sector is 512B, which is still widely used today. We will follow this configuration.

## Sector management

The first thing we concern about is the availability of each sector. Consider creating a new file. We want to place the file contents on some free sectors and don't want to overwrite the sectors that belong to other files. Thus, keep in track of the status of each sector is critical. 

Using a bitmap is a typical and sufficient way to achieve this. A bitmap is an array of bits, maintaining the status of an array of resources. Each bit records the 0-or-1 status of a individual resource. In our file system, we use a bitmap of sectors, where `0` means the sector is free, and `1` means the sector is occupied.

Since the smallest data type in Rust is not bit but byte (`u8/i8`), the manipulation will be kind of tricky. The bits is arranged in an array of bytes, namely `Box<[u8]>`. Thus, the `i`-th bit is located in the `floor(i / 8)`-th byte, where we write as `sector as usize / 8`. In the particular byte, the bit itself is at `i % 8`-th bit, where we write as `1 << (sector % 8)`, namely `1 << sector % 8` because of the higher priority of `%`. Remember that the sector number is the exact bit number because the mapping between sectors and bits is identical. Finally, the codes are as below:

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

## Forming files: inode and inumber

With free map, we can manage the sectors correctly. Our next concern is the management of files. Basically, fitting the contents into sectors is quite simple. By treating a file as a sequence of bytes, we just need to find some sectors, contiguous or not, and put the bytes into them. With the `FreeMap` it will be easy to find these sectors. The critical point of file management is how to locate all the files and its corresponding sectors, which the `FreeMap` can help little.

By convention, a data structure that locates sectors for a file is called "inode". An inode is responsible for one file, and may save many informations about this file (aka metadata), including its permissions, its create/modify timestamp, etc., but its most critical job is to record all the sectors belong to the file. Also, on cases the file changes its size so that it needs more sectors or discard some sectors, the inode is responsible to communicate with the sector manager for allocation and deallocation. 

There are many ways for an inode to meet the requirements. The sectors can be grouped together to form "chunks" for a more efficient management. The sectors or chunks can be arranged in either contiguous arrays, linked lists or trees. For structured files (and a specified FS), many other data structures may be used. In our example FS, we only employ the simplest way, namely arranging the individual sectors in contiguous arrays, and sectors cannot be shared between files. Thus, an inode only needs to record the start sector of a file and the length of a file. 

File: src/fs/disk/inode.rs
```rust
#[repr(C)]
struct DiskInodeInner {
    /// Start sector.
    start: u32,
    /// Length in bytes.
    len: u32,
    magic: u32,
}
```
A magic number is recorded at the last of the inode to detect any corruption. If an inode is corrupted, its file and itself are discarded. Also, you can notice the struct is annoted by `#[repr(C)]`. That's because we want the arrangement of these information keep unchanged whether in memory or on disk. The `FreeMap` struct is not annoted, because the only critical field is the `bits`, which is arranged in an ordered array. The size can be get from the disk info.

The next concern is how to manage between different inodes, i.e., files. Such a structure is called "directory" by convention. Here we first introduce the "inode number". To distinguish different inodes, many FS will gives a unique number to each inode. This number is alleviated as "inumber" or "inum", etc. Such a system introduces extra complexity into a FS, for it is now responsible to manage the allocation and dealocation of inumber. Inspired by pintos, in our example FS, this step is simplified by using sector number equally as inumber. That means, when we need to allocate an inumber, we allocate a new sector, give the whole sector to the inode, and uses the sector number as its inumber. Thus, we can reuse the `FreeMap` as inumber manager. In this design, an inode occupies a sector. As a result, we need to padding each inode to 512 bytes.

File: src/fs/disk.rs
```rust
pub type Inum = u32;
```

File: src/fs/disk/inode.rs
```rust
const INODE_PADDING: usize = SECTOR_SIZE - core::mem::size_of::<DiskInodeInner>();
#[repr(C)]
struct DiskInode {
    inner: DiskInodeInner,
    padding: [u8; INODE_PADDING],
}
```
Again, `#[repr(C)]` is annoted because we want to keep the padding bytes at last.

## File management: directory and path

We then go on to design how to manage between different files, i.e., inodes. Such a structure is called "directory". Essentially, a directory is used to record all the files. With the help of inodes, the directory does not need to record all the file contents, but only the locations of their inodes. The location may be recorded in inumber manager, which is `FreeMap` itself in our FS. Besides the inumbers, a directory also needs to record the "identity" of the files, which are typically their names. Thus, a directory can be treated as a key-value storage, where the keys are the names, and the values are the inumbers. Thus, a directory can be arranged as an array of KV-entry, which we called "direntry".

File: src/fs/disk/dir.rs
```rust
#[repr(C)]
pub struct DirEntry {
    name: [u8; FILE_NAME_LEN_MAX],
    inum: Inum,
}
```
The design choice of `FILE_NAME_LEN_MAX` is quite flexible and may even be configurable. In our FS, we set its value to 28, so that a `DirEntry` is aligned to 32 bytes (28 * `u8` + `u32`).

In most of the existing FS, directory is a special kind of file. The `DirEntry`s are sequentially recorded. We follow this design. However, since a directory is nore special than just byte sequences, we provide some special methods. By using the tuple-struct in Rust, we can add type-safety to these methods, i.e., files that are not regarded as directories will not be applied by thes methods.

File: src/fs/disk/dir.rs
```rust
pub struct RootDir(pub(super) File);
```
You can notice that the struct is called `RootDir`. In many FS, the directories are arranged in a tree-like structure. A directory can record another directory, and so on. For simplicity, we didn't implement this feature in our example FS. This can be sufficient when the total number of files is not that many, or when the files do not show any kind of hierarchy. Many domain specific FS didn't implement directory tree either (though we are not domain specific). As a result, our FS only has one global directory, which is called `RootDir`. As a global manager, we place it along with the `FreeMap`. In specific, the inumber of `FreeMap` is 0, and the inumber of `RootDir` is 1.

Although we didn't implement a directory tree, we still implement a `Path` for the integrity. In FS that employ directory tree, the (full) name of a file also records all the ancestor directories of it. For example, if the root directory is called "A", it records a directory called "B", and "B" records a file named "C", then the full name of the file can be "A/B/C". The "/" is typically used as delimiter between directories. Also, conventionally the name of root directory is omitted, so the name can be written as "/B/C". This is called a "path", which pathing from the root directory to a exact file. We implement a `Path` struct to form this function. In Rust std, `Path` is responsible for some other functions about file finding. We implement one of them, which tells whether a path specifies an existing file. 

File: src/fs/disk/path.rs
```rust
pub struct Path(alloc::string::String);

impl Path {
    pub fn exists(path: Self) -> bool {
        super::DISKFS.get().root_dir.lock().exists(&path)
    }
}
```
