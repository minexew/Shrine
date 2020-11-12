<p align="center"><strong>Shrine</strong> is a TempleOS distribution full of sin.</p>
<p align="center"><img alt="Screenshot" src="http://imgur.com/1yYsUHI.png"></p>
<hr>

Shrine aims to be 99% compatible with TempleOS programs, but also to improve OS in several ways:

- Ease of use: Shrine ships with Lambda Shell, which feels a bit like a classic Unix command interpreter
- Connectivity: TCP/IP stack & internet access out of the box
- Software discovery: Shrine includes a package downloader

You can run Shrine in a virtual machine such as VirtualBox or [QEMU](QEMU.md), or on a machine compatible with standard TempleOS. Improvements in hardware support are planned and contributions are welcome.

Software included in Shrine:
- Mfa (minimalist file access)
- Lsh (Lambda Shell)
- Pkg (package downloader)
- Wget

Networking & host-VM communication
==================================

- With a virtual AMD PCNet adapter (recommended)
  - configure your VM networking: *Adapter Type: PCnet-PCI II* (in QEMU: `-netdev user,id=u1 -device pcnet,netdev=u1`)
  - *Attached to: NAT* seems to be the most reliable setting, Bridged Mode also works somewhat
  - On boot, Shrine will automatically attempt to acquire an IP address. If you don't see a message about "Configuring network", the adapter was not detected.

- Tunelled through serial port (Snail):
  - configure your VM: COM3 - TCP, server, 7777 (in VirtualBox, server = UNCHECK *Connect to existing*)
  - (make sure to *disable* networking for the VM, otherwise Native Stack will get precedence)
  - start the VM
  - run ./snail.py
  - you will now be able to access the Internet, try for example `pkg-list`

- File access through Mfa:
  - configure your VM: COM1 - TCP, server, 7770
  - start `/Apps/Mfa.HC.Z` in the VM
  - on the host, use ./mfa.py to transfer commands and files
  - for example: `./mfa.py list /Apps/Mfa.HC.Z Mfa.HC`

Networking and Mfa can be used simultaneously.

Package management functions
============================

Note: In Lsh, use `pkg-install xyz` in place of `PkgInstall("xyz")` etc.

- `PkgList;`

  List all packages available in the repository.

- `PkgInstall(U8* package_name);`

  Download & install a specific package.

- `PkgInstallFromFile(U8* manifest_path);`

  Manually install a downloaded package. Manifest must reference an existing .ISO.C path.

- `PkgMakeFromDir(U8* manifest_path, U8* src_dir);`

  Build a package from directory contents. For an example manifest, check [here](https://github.com/minexew/Lsh/blob/master/Lsh.MF). Manifest must reference a valid .ISO.C path which will be used as **output**!

- `PkgMakeFromFile(U8* manifest_path, U8* file_path);`

  Build a package from a single file. See above for details.

[See here](PACKAGES.md) for more information about how packages work.

Building from source
====================

[See here](BUILDING.md)
