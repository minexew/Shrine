#!/usr/bin/env bash

PURE_DIR=../TempleOS/TempleOSCD
PATCHED_DIR=Patched

FLAGS="--no-index"

git diff $FLAGS "$PURE_DIR/Adam/ADefine.HC" "$PATCHED_DIR/Adam/ADefine.HC" >Branding/ADefine.diff
git diff $FLAGS "$PURE_DIR/Doc/Start.DD" "$PATCHED_DIR/Doc/Start.DD" >Branding/Start.diff

git diff $FLAGS "$PURE_DIR/Adam/MakeAdam.HC" "$PATCHED_DIR/Adam/MakeAdam.HC" >Distro/MakeAdam.diff
git diff $FLAGS "$PURE_DIR/Doc/Comm.HC" "$PATCHED_DIR/Doc/Comm.HC" >Distro/Comm.diff
git diff $FLAGS -U0 "$PURE_DIR/Kernel/KGlbls.HC" "$PATCHED_DIR/Kernel/KGlbls.HC" >Distro/KGlbls.diff
git diff $FLAGS "$PURE_DIR/Misc/DoDistro.HC" "$PATCHED_DIR/Misc/DoDistro.HC" >Distro/DoDistro.diff
git diff $FLAGS "$PURE_DIR/Once.HC" "$PATCHED_DIR/Once.HC" >Distro/Once.diff
