Building from source
====================

Building Shrine requires an x86-64 Linux machine with Docker/Podman.

Then the process is as easy as

	cd $SHRINE_DIR
	mkdir out
	podman run -it -v .:/usr/src/shrine -v ./out:/build/shrine/out --rm minexew/shrine-build:1

The output will be `out/Shrine.ISO`.

The resultant build can be tested by running

	qemu-system-x86_64 \
		-cdrom out/Shrine.ISO \
		-boot d \
		-machine kernel_irqchip=off \
		-smp cores=4 \
		-m 2048 \
		-rtc base=localtime \
		-soundhw pcspk \
		-netdev user,id=u1 -device pcnet,netdev=u1
