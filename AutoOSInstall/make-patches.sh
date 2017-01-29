#!/usr/bin/env bash

PURE_DIR=../TempleOS/TempleOSCD

FLAGS="-u"

diff $FLAGS "$PURE_DIR/Misc/OSInstall.HC" "AutoOSInstall.HC" >AutoOSInstall.diff
