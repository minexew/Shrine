#!/usr/bin/env bash

PURE_DIR=../TempleOS/TempleOSCD
PATCHED_DIR=Patched

FLAGS="-d $PATCHED_DIR -p1 -u -Z"

rm -rf $PATCHED_DIR
cp -rp $PURE_DIR $PATCHED_DIR

patch $FLAGS -i ../Branding/ADefine.diff
patch $FLAGS -i ../Branding/Start.diff
patch $FLAGS -i ../Distro/Comm.diff
patch $FLAGS -i ../Distro/DoDistro.diff
patch $FLAGS -i ../Distro/Once.diff
