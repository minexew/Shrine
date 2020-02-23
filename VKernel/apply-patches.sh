#!/usr/bin/env bash

PURE_DIR=../TempleOS/TempleOSCD
PATCHED_DIR=Patched

FLAGS="-u -p1"

rm -rf $PATCHED_DIR
cp -rp $PURE_DIR $PATCHED_DIR

patch $FLAGS -i BlkPool.diff
patch $FLAGS -i Display.diff
patch $FLAGS -i DskAddDev.diff
patch $FLAGS -i DskDrv.diff
patch $FLAGS -i DskFile.diff
patch $FLAGS -i DskStrB.diff
patch $FLAGS -i KDate.diff
patch $FLAGS -i KDbg.diff
patch $FLAGS -i KDefine.diff
patch $FLAGS -i KMisc.diff
patch $FLAGS -i KUtils.diff
patch $FLAGS -i KernelA.diff
patch $FLAGS -i MakeBlkDev.diff
patch $FLAGS -i MemPhysical.diff
patch $FLAGS -i MultiProc.diff
patch $FLAGS -i Sched.diff
