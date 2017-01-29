#!/usr/bin/env python

'''
Build a distribution ISO.

Typical usage:
    qemu-img create -f qcow2 ~/disk.img 2G
    ./make-dist.py ~/TempleOSCD-v502.ISO Shrine ~/disk.img


The process is mostly automated, though at one point it's necessary
to press "1" to select the boot drive.

This works by binary-patching the TempleOS dist ISO to enter a reduced
version of MFA immediately upon start-up. (see inject_templeos.py)
The OS installation script is also modified so no user input is required.

After booting into the installed OS, distribution install script is run,
which will typically include building and exporting a distribution ISO.
'''

from __future__ import print_function

import argparse
import os
import shutil
import subprocess
import sys
import time

parser = argparse.ArgumentParser()
parser.add_argument('install_iso')
parser.add_argument('distro_dir')
parser.add_argument('disk_img')
parser.add_argument('--skip-tos-install', dest='skip_tos_install',
        action='store_true')
args = parser.parse_args()

INSTALL_ISO = args.install_iso
DISTRO_DIR = args.distro_dir
DISK_IMG = args.disk_img

MEM_SIZE = 512
MFA_PORT = 7770
SNAIL_PORT = 7777
QEMU_START_DELAY = 3

SLAVE_HC_Z = 'SlaveOnce.HC.Z'

AUTO_INSTALL_PATH = 'AutoOSInstall'
AUTO_INSTALL_TIMEOUT = 300

PATCHED_ISO = 'TempleSlave.iso'

QEMU_COMMAND = [
        'qemu-system-x86_64',
        '-hda', DISK_IMG,
        '-machine', 'kernel_irqchip=off',
        '-smp', 'cores=1',
        '-m', str(MEM_SIZE),
        '-rtc', 'base=localtime',
        '-soundhw', 'pcspk',
        '-serial', 'tcp::%d,server' % MFA_PORT]

ENABLE_KVM = True

if ENABLE_KVM:
    QEMU_COMMAND += ['-enable-kvm', '-cpu', 'host']

SELF_DIR = os.path.dirname(os.path.abspath(__file__))
INJECT_BIN = os.path.join(SELF_DIR, 'inject_templeos.py')
MFA_BIN = os.path.join(SELF_DIR, 'mfa.py')
SNAIL_BIN = os.path.join(SELF_DIR, 'snail.py')

if not os.path.exists(PATCHED_ISO):
    shutil.copy(INSTALL_ISO, PATCHED_ISO)
    try:
        subprocess.check_call([INJECT_BIN, PATCHED_ISO, 'Once.HC.Z', SLAVE_HC_Z])
    except:
        os.remove(PATCHED_ISO)
        raise

def wait_for_subprocess(subpr, timeout):
    while timeout >= 0:
        if subpr.poll() is not None:
            return

        time.sleep(1)
        timeout -= 1

    raise Exception('Subprocess didn\'t finish in time')

def run_qemu_and_mfa(qemu_command, mfa_script, timeout, with_snail=False):
    if with_snail:
        qemu_command = qemu_command + ['-serial', 'null',
                                       '-serial', 'tcp::%d,server' % SNAIL_PORT]

    qemu = subprocess.Popen(qemu_command)
    time.sleep(QEMU_START_DELAY)

    if qemu.poll() is not None:
        raise Exception('QEMU failed to start')

    snail = None

    try:
        with open(mfa_script, 'rb') as script:
            mfa = subprocess.Popen([MFA_BIN], stdin=script)

            if with_snail:
                time.sleep(3)
                snail = subprocess.Popen([SNAIL_BIN])

            wait_for_subprocess(mfa, timeout)

            if mfa.returncode != 0:
                raise Exception('MFA script failed')
    finally:
        if snail: snail.kill()

        qemu.terminate()
        time.sleep(5)
        qemu.kill()

        wait_for_subprocess(qemu, 10)

if not args.skip_tos_install:
    run_qemu_and_mfa(QEMU_COMMAND + ['-cdrom', PATCHED_ISO, '-boot', 'd'],
            os.path.join(AUTO_INSTALL_PATH, 'install.script'), AUTO_INSTALL_TIMEOUT)

mkdist_script = os.path.join(DISTRO_DIR, 'mkdist.script')
mkdist_timeout = float(open(os.path.join(DISTRO_DIR, 'mkdist-timeout')).read())

print()
print('=====================================================')
print(' Ready to install %s. Press Enter to continue.' % DISTRO_DIR)
print(' As soon as the TempleOS boot menu appears, press 1.')
raw_input()

run_qemu_and_mfa(QEMU_COMMAND, mkdist_script, mkdist_timeout, with_snail=False)
