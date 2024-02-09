# Scalable interfaces

The implementations we mentioned in previous section, i.e., `FreeMap`, `DiskInode`, `RootDir` and `Path`, are sufficient to build an on-disk FS. Now, we are going to implement high-level interfaces. The interfaces are going to provide an abstract of the low-level resources, including files, inodes and directories.

When we talk about "abstract", we imply that we are going to group together a set of objects with similar features. Particularly, an OS kernel will facing multiple kinds of FSs, locate on disks or even in memory. The inodes, files and directories in these FSs may also have different formats. However, they still share several same concepts, which will decide our interfaces.

# FS interface

At the top, we provide a basic abstract of FS. As we mentioned, a FS is a format about the on-device informations. The first interface of a FS is to allow the OS to recognize this specific format, called `mount`. Second, the FS should provide a method to get access to the files, called `open`. Finally, the FS needs to rpovide a method to create new files, called `create`. The reverse version of these methods are called `unmount`, `close` and `remove`.

To support a management of different FSs, the interface is implemented as a trait. Considering different FS instances may have different basic device types, the `Device` is sepcified as a generic associated type. Moreover, to support synchronization, the interface are designed to receives immutable reference, i.e., `&self`, which gives an opportunity toward fine-grained locks.

File: src/kernel/fs.rs
```rust
trait FileSys: Sync + Send + Sized {
    type Path;
    type Device;

    fn mount(device: Self::Device) -> Result<Self>;
    fn unmount(&self);

    fn open(&self, id: Self::Path) -> Result<File>;
    fn close(&self, file: File);
    fn create(&self, id: Self::Path) -> Result<File>;
    fn remove(&self, id: Self::Path) -> Result<()>;
}
```

# Inode interface

Like the inode on devices, software inodes represent for the files. More than the on-device inodes, the software interface handles synchronization issues. Basically, different threads may access the same file synchronously. Thus, the inode interface should make sure these threads will not conflict with each other. By convention, the file interface is designed to be thread-local, and the inode interface, on contrast, is OS-global to handle this issue. That means, for one file, there can be multiple corresponding file structs at the same time, but there can be only one inode struct. 

To avoid confusion, we follow the naming in Linux, which calls the interface `Vnode`. Like the `FileSys`, the `Vnode` is designed as a trait, and receives immutable reference. The methods can be used to extract the informations of the file or directly manipulate it. 

File: src/kernel/fs.rs
```rust
trait Vnode: Sync + Send {
    fn read_at(&self, buf: &mut [u8], off: usize) -> Result<usize>;
    fn write_at(&self, buf: &[u8], off: usize) -> Result<usize>;
    fn deny_write(&self);
    fn allow_write(&self);

    fn len(&self) -> usize;
    fn resize(&self, size: usize) -> Result<()>;
    fn close(&self);
}
```

# File interface

It is surprising that with the help of `Vnode`, we can implement `File` as struct but not trait. That means we only need to write the codes once! Actually, the methods provided by `Vnode` is enough for `Read`, `Write` and `Seek`. With a thread-local cursor and `read_at/write_at`, these traits can be easily implemented.

Still, `File` needs to handle synchronization issues. Here, we rely on the inode implementations to guarantee the correctness, which means the `File` will not hold any lock (though this design is also acceptable). 

File: src/kernel/fs.rs
```rust
#[derive(Clone)]
struct File {
    vnode: Arc<dyn Vnode>,
    pos: usize,
    deny_write: bool,
}
```
With the help of `Arc`, the `File` can be implemented with `Clone`. We can also rely on `Drop` to help us manage these resources. The counter in `Arc` will record the number of corresponding `File`s. Once there is no `File`, the `Vnode` can be dropped automatically. 

In our on-disk FS, the `Vnode`, i.e., `DiskInode`, is managed in a inumber-inode map. In the Fs instance,  the inode is referenced in `Weak`, allowing automated drop of inode. 

File: src/kernel/fs/disk.rs
```rust
struct DiskFs {
    device: &'static Mutex<Virtio>,
    free_map: Mutex<FreeMap>,
    root_dir: Mutex<RootDir>,
    inode_table: Mutex<BTreeMap<Inum, Weak<Inode>>>,
}
```

# IO interface

As we mentioned, a file can be regarded as a byte sequence, on which we can perform input/output operations. In Rust std, these operations are designed as a set of traits, and can be implemented for many byte-sequence-like structs. In our OS, we follow the design in Rust std, and provide three basic traits: `Read`, `Write` and `Seek`. You can refer to src/kernel/io.rs for details.

Meanwhile, because these traits are oftenly used and are likely to be used together, we provide a `prelude` module for convenience.

File: src/kernel/io.rs
```rust
mod prelude {
    pub use super::{Read, Seek, SeekFrom, Write};
}
```
