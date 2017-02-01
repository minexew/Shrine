Building from source
====================

The build process is rather quirky, because it needs to be done within QEMU. (mostly due to the way how TOS builds its bootloader)

During the process, the TOS ISO is first patched to enable an unattended install. After installing stock TOS, the VM is restarted and Shrine packages are put in place. Finally, the generated packages as well a Shrine ISO are extracted from the VM.

- make sure you have `qemu-img`, `qemu-system-x86_64` and Python
- get [TempleOSCD-v502.ISO](https://github.com/minexew/TempleOS/releases/download/v5.02/TempleOSCD-v502.ISO) if building the release branch, or latest [TempleOSCD.ISO](http://www.templeos.org/TempleOSCD.ISO) if building the develop branch
- use the following commands

```
# This only needs to be done once
git submodule update --init --recursive
git apply isoparser.patch

# Some files are provided as diffs against stock TempleOS, this generates the full files
cd AutoOSInstall && ./apply-patches.sh && cd ..
cd Shrine && ./apply-patches.sh && cd ..

# Finally run the machinery
qemu-img create -f qcow2 ~/shrine.img 2G
mkdir PkgBin
./make-dist.py TempleOSCD.ISO Shrine ~/shrine.img 
```

The output will be `Shrine-HEAD.iso` and a bunch of files under `PkgBin/`.
