Shrine is right at home in QEMU. (In fact, for many years QEMU was needed to build Shrine itself!)

First, you should create a virtual disk (you can adjust the size to your preference):

	qemu-img create -f qcow2 Shrine.HDD 2G

Then, to boot the Live CD and install to the disk:

	qemu-system-x86_64 \
		-cdrom Shrine.ISO -boot d \
		-drive format=qcow2,file=Shrine.HDD \
		-machine kernel_irqchip=off \
		-smp cores=4 \
		-m 2048 \
		-rtc base=localtime \
		-soundhw pcspk \
		-netdev user,id=u1 -device pcnet,netdev=u1

Follow the on-screen instructions. When the installer finishes and prompts for a reboot,
simply close the VM and restart it by repeating the previous command, omitting the `-cdrom Shrine.ISO -boot d`.
