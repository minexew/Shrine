#!/usr/bin/env bash

PURE_DIR=../TempleOS/TempleOSCD
PATCHED_DIR=Patched

FLAGS=""

rm -rf $PATCHED_DIR
cp -rp $PURE_DIR $PATCHED_DIR

git apply $FLAGS Branding/ADefine.diff
git apply $FLAGS Branding/Start.diff
git apply $FLAGS Distro/Comm.diff
git apply $FLAGS Distro/DoDistro.diff
git apply $FLAGS Distro/Once.diff
