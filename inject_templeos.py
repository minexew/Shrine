#!/usr/bin/env python

from __future__ import print_function

import sys
sys.path.append('isoparser')

import errno
import isoparser
import os
import subprocess

ISO_FILE = sys.argv[1]
PATH_TO_REPLACE = sys.argv[2]
REPLACEMENT_FILE = sys.argv[3]

iso = isoparser.parse(ISO_FILE)

with open(REPLACEMENT_FILE, 'rb') as f:
    data = f.read()

record = iso.record(*[s.encode() for s in PATH_TO_REPLACE.split('/')])
patches = record.generate_patchset(data)

iso.close()

with open(ISO_FILE, 'rb+') as isof:
    for offset, orig, new in patches:
        #print(offset, orig, new)
        if len(orig) != len(new):
            raise Exception("Length mismatch for patch @ %d+%d" % (offset, len(new)))

        isof.seek(offset, 0)
        if isof.read(len(orig)) != orig:
            raise Exception("Verification error for patch @ %d+%d" % (offset, len(new)))

    for offset, orig, new in patches:
        isof.seek(offset, 0)
        isof.write(new)

print('Applied %d patches, %d bytes total' % (
        len(patches), sum([len(new) for _, _, new in patches])))
