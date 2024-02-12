# Boot with device

Recall how we link and load our kernel in [Section-1](../1-helloworld/first_instruction.md). The kernel is manually passed to QEMU and loaded into QEMU's physical address space, starting with `0x80200000`. In real-world boot process, the kernel is loaded from disk drives by boot loader. To keep simple, we will not include a boot loader in our project. However, we will boot our kernel with a disk drive, and manage it through or hand-crafted file system.

## QEMU command line arguments for devices

QEMU provides a set of command line arguments that allows you to pass devices to you kernel. A plenty types of devices are supported. In our kernel, we mainly focuses on a small set of them:

- **Physical memory**: QEMU allows you to specify the total size of physical memory space via argument `-m <SIZE>`.
- **Bootargs**: QEMU allows you to pass arbitrary arguments to your kernel upon boot via `-append "ARGS"`.
- **Disk device**: QEMU allows you to attach multiple peripheral devices to the emulated system. The arguments may be more complex compared to above, since we need to connect the devices to kernel via interrupt buses. To be simple, a disk can be added with `--blockdev driver=file,node-name=disk,filename=disk.img` and connected with `-device virtio-blk-device,drive=disk,bus=virtio-mmio-bus.0`.

For more device types please refer to QEMU's official [documentation](TODO).

Eventually, booting our kernel with a 32M memory, a disk and some arguments can be done with command as follow:
```sh
qemu-system-riscv64 -nographic -machine virt \
-global virtio-mmio.force-legacy=false \
--blockdev driver=file,node-name=disk,filename=disk.img \
-device virtio-blk-device,drive=disk,bus=virtio-mmio-bus.0 \
-m 32M \
-append "arg" \
-kernel <kernel>
```

## Device tree

Conceptually, after booting the kernel with command above, the kernel is able to use the speficied devices. However, it requires some efforts to find these devices correctly.

By default, QEMU passes the device informations to the kernel in device tree format. To be more specific, the device tree is serialized into Device Tree Blob (DTB) format, and placed on a contiguous region on memory. Each node on the device tree records informations about a device, such as memory, and may contain some sub nodes. 

Please refer to the [documentation](https://devicetree-specification.readthedocs.io) about how exact the DTB are arranged, and what types of device are supported in DTB. We have provided a function (src/dtb/dtb.rs) that traverses the device tree and parses some basic informations.

## Virtio

After parsing the DTB, our kernel is able to find the devices and use them correctly.

You might have noticed that, in our QEMU boot command, we set our disk to be `virtio-blk-device`. 

TODO: wtf.

TODO: virtio actually does not use DTB info currently.

TODO: may use third-party DTB and Virtio.
