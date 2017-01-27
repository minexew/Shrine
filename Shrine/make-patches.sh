#!/usr/bin/env bash

PURE_DIR=../TempleOS/TempleOSCD
PATCHED_DIR=Patched

FLAGS="-u"

diff $FLAGS "$PURE_DIR/Adam/ADefine.HC" "$PATCHED_DIR/Adam/ADefine.HC" >Branding/ADefine.diff
diff $FLAGS "$PURE_DIR/Doc/Start.DD" "$PATCHED_DIR/Doc/Start.DD" >Branding/Start.diff

diff $FLAGS "$PURE_DIR/Misc/DoDistro.HC" "$PATCHED_DIR/Misc/DoDistro.HC" >Distro/DoDistro.diff
diff $FLAGS "$PURE_DIR/Once.HC" "$PATCHED_DIR/Once.HC" >Distro/Once.diff
