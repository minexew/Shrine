#!/usr/bin/env bash

PURE_DIR=../TempleOS/TempleOSCD

FLAGS="-p1 -u -Z"

cp -rp $PURE_DIR/Misc/OSInstall.HC AutoOSInstall.HC

patch -i AutoOSInstall.diff
