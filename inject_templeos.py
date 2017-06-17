#!/usr/bin/env python3

import sys
sys.path.append('redseafs')

from isoc import RedSea

ISO_FILE = sys.argv[1]
PATH_TO_REPLACE = sys.argv[2]
REPLACEMENT_FILE = sys.argv[3]

iso = RedSea(ISO_FILE)

with open(REPLACEMENT_FILE, 'rb') as f:
    data = f.read()

patches = iso.generate_patchset('/' + PATH_TO_REPLACE, data)

del(iso)

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
