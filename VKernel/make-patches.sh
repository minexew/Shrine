#!/usr/bin/env bash

PURE_DIR=../TempleOS/TempleOSCD
PATCHED_DIR=Patched

FLAGS="--no-index"

git diff $FLAGS "$PURE_DIR/Kernel/BlkDev/DskAddDev.HC" "$PATCHED_DIR/Kernel/BlkDev/DskAddDev.HC" >DskAddDev.diff
git diff $FLAGS "$PURE_DIR/Kernel/BlkDev/DskDrv.HC" "$PATCHED_DIR/Kernel/BlkDev/DskDrv.HC" >DskDrv.diff
git diff $FLAGS "$PURE_DIR/Kernel/BlkDev/DskFile.HC" "$PATCHED_DIR/Kernel/BlkDev/DskFile.HC" >DskFile.diff
git diff $FLAGS "$PURE_DIR/Kernel/BlkDev/DskStrB.HC" "$PATCHED_DIR/Kernel/BlkDev/DskStrB.HC" >DskStrB.diff
git diff $FLAGS "$PURE_DIR/Kernel/BlkDev/MakeBlkDev.HC" "$PATCHED_DIR/Kernel/BlkDev/MakeBlkDev.HC" >MakeBlkDev.diff
git diff $FLAGS "$PURE_DIR/Kernel/Display.HC" "$PATCHED_DIR/Kernel/Display.HC" >Display.diff
git diff $FLAGS "$PURE_DIR/Kernel/KDate.HC" "$PATCHED_DIR/Kernel/KDate.HC" >KDate.diff
git diff $FLAGS "$PURE_DIR/Kernel/KDbg.HC" "$PATCHED_DIR/Kernel/KDbg.HC" >KDbg.diff
git diff $FLAGS "$PURE_DIR/Kernel/KDefine.HC" "$PATCHED_DIR/Kernel/KDefine.HC" >KDefine.diff
git diff $FLAGS "$PURE_DIR/Kernel/KMisc.HC" "$PATCHED_DIR/Kernel/KMisc.HC" >KMisc.diff
git diff $FLAGS "$PURE_DIR/Kernel/KUtils.HC" "$PATCHED_DIR/Kernel/KUtils.HC" >KUtils.diff
git diff $FLAGS "$PURE_DIR/Kernel/KernelA.HH" "$PATCHED_DIR/Kernel/KernelA.HH" >KernelA.diff
git diff $FLAGS "$PURE_DIR/Kernel/Mem/BlkPool.HC" "$PATCHED_DIR/Kernel/Mem/BlkPool.HC" >BlkPool.diff
git diff $FLAGS "$PURE_DIR/Kernel/Mem/MemPhysical.HC" "$PATCHED_DIR/Kernel/Mem/MemPhysical.HC" >MemPhysical.diff
git diff $FLAGS "$PURE_DIR/Kernel/MultiProc.HC" "$PATCHED_DIR/Kernel/MultiProc.HC" >MultiProc.diff
git diff $FLAGS "$PURE_DIR/Kernel/Sched.HC" "$PATCHED_DIR/Kernel/Sched.HC" >Sched.diff
git diff $FLAGS "$PURE_DIR/Kernel/SerialDev/Message.HC" "$PATCHED_DIR/Kernel/SerialDev/Message.HC" >Message.diff
