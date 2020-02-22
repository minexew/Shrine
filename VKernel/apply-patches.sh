#!/usr/bin/env bash

PURE_DIR=../TempleOS/TempleOSCD
PATCHED_DIR=Patched

FLAGS="-u -p1"

rm -rf $PATCHED_DIR
cp -rp $PURE_DIR $PATCHED_DIR

patch $FLAGS -i Display.diff
patch $FLAGS -i KDate.diff
patch $FLAGS -i KMisc.diff
patch $FLAGS -i KUtils.diff
patch $FLAGS -i BlkPool.diff
patch $FLAGS -i MemPhysical.diff
