Shrine
======

![Screenshot](http://imgur.com/xDC3hwx.png)

Shrine is a TempleOS distribution that aims to be more modern & approachable.

Shrine aims to improve upon TempleOS in several aspects:
- Approachability: Shrine ships with Lambda Shell, a more traditional Unix-like command interpreter
- Connectivity: Snail is a tunelled network interface that lets you connect to the internet
- Software access: Shrine includes a package downloader
- Versatility: unlike stock TempleOS, Shrine requires only 64MB RAM, making it feasible for cloud micro-instances and similar setups (note: this is planned, but currently not true)

Software included in Shrine:
- Mfa (minimalist file access)
- Lsh (Lambda Shell)
- Pkg (package downloader)
- Wget

Building from source
====================

- make sure you have `qemu-img`, `qemu-system-x86_64` and Python
- get TempleOSCD-v502.ISO
- use the following commands

```
git submodule update --init --recursive
cd Shrine
./apply-patches.sh
cd ..
qemu-img create -f qcow2 ~/shrine.img 2G
./make-dist.py TempleOSCD-v502.ISO Shrine ~/shrine.img 
```

The output will be `Shrine-HEAD.iso`.
