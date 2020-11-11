#!/bin/bash
set -e

rm -rf .build
mkdir .build
cd .build

BIN=templeoskernel-pre6
curl -O https://shrine.systems/download/templeos-loader/$BIN
chmod +x $BIN

mkdir Shrine.out

# workaround fs bug in HolyCRT (fails to create necessary directories)
mkdir -p Shrine.out/Compiler Shrine.out/Kernel

env STARTOS=Build/BuildShrine ./$BIN --drive=C,..,Shrine.out

ISO_FILE=Shrine.out/Shrine.ISO
ISO_SIZE=$(wc -c <$ISO_FILE)
MIN_SIZE=100000
if [ $ISO_SIZE -le $MIN_SIZE ]; then
    echo error: $ISO_FILE is $ISO_SIZE bytes in size, less than the expected minimum of $MIN_SIZE >&2
    exit 1
fi
