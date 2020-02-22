#!/usr/bin/env bash

PURE_DIR=../TempleOS/TempleOSCD
PATCHED_DIR=Patched

FLAGS="--no-index"

git diff $FLAGS "$PURE_DIR/Kernel/Display.HC" "$PATCHED_DIR/Kernel/Display.HC" >Display.diff
git diff $FLAGS "$PURE_DIR/Kernel/KDate.HC" "$PATCHED_DIR/Kernel/KDate.HC" >KDate.diff
git diff $FLAGS "$PURE_DIR/Kernel/KMisc.HC" "$PATCHED_DIR/Kernel/KMisc.HC" >KMisc.diff
git diff $FLAGS "$PURE_DIR/Kernel/KUtils.HC" "$PATCHED_DIR/Kernel/KUtils.HC" >KUtils.diff
git diff $FLAGS "$PURE_DIR/Kernel/Mem/BlkPool.HC" "$PATCHED_DIR/Kernel/Mem/BlkPool.HC" >BlkPool.diff
git diff $FLAGS "$PURE_DIR/Kernel/Mem/MemPhysical.HC" "$PATCHED_DIR/Kernel/Mem/MemPhysical.HC" >MemPhysical.diff
