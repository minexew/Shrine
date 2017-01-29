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
