Building from source
====================

The build process is rather quirky, because it needs to be done within QEMU. (mostly due to the way how TOS builds its bootloader)

During the process, the TOS ISO is first patched to enable an unattended install. After installing stock TOS, the VM is restarted and Shrine packages are put in place. Finally, the generated packages as well as a Shrine ISO are extracted from the VM.

- make sure you have `qemu-img`, `qemu-system-x86_64` and Python
- TempleOSCD.ISO and the TempleOS git submodule need to be in sync -- if you update either, you need to update the other as well
- use the following commands

```
# Some files are provided as diffs against stock TempleOS, this generates the full files
cd AutoOSInstall && ./apply-patches.sh && cd ..
cd Shrine && ./apply-patches.sh && cd ..

# Finally run the machinery
qemu-img create -f qcow2 ~/shrine.img 2G
mkdir PkgBin
Install fuse libraries for your OS
Add Shrine/redseafs and Shrine/redseafs/fuse to your PYTHONPATH
./make-dist.py TOS_Distro.ISO Shrine ~/shrine.img
```

The output will be `Shrine-HEAD.iso`.
