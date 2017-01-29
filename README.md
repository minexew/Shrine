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

Setting up with networking
==========================
- To enable networking through Snail:
  - configure your VM: COM2 - TCP, server, 7777
  - start the VM
  - run ./snail.py
  - you will now be able to access the Internet, try for example `pkg-list`
  
- To enable file access through Mfa, configure the VM as follows:
  - configure your VM: COM1 - TCP, server, 7770
  - start `/Apps/Mfa.HC.Z` in the VM
  - on the host, use ./mfa.py to transfer commands and files
  - for example: `./mfa.py list /Apps/Mfa.HC.Z Mfa.HC`

Both of these can be used simultaneously.

Building from source
====================

- make sure you have `qemu-img`, `qemu-system-x86_64` and Python
- get TempleOSCD-v502.ISO
- use the following commands

```
# This only needs to be done once
git submodule update --init --recursive
git apply isoparser.patch

# Some files are provided as diffs against stock TempleOS, this applies them
cd Shrine
./apply-patches.sh
cd ..

# Finally run the machinery
qemu-img create -f qcow2 ~/shrine.img 2G
mkdir PkgBin
./make-dist.py TempleOSCD-v502.ISO Shrine ~/shrine.img 
```

The output will be `Shrine-HEAD.iso`.
