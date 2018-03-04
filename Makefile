build: prepare patch
	if `which qemu-img > /dev/null 2>&1`; then \
		qemu-img create -f qcow2 shrine.img 2G; \
		mkdir PkgBin; \
		python make-dist.py TOS_Distro.ISO Shrine shrine.img; \
	fi;
prepare:
	if  `which git > /dev/null 2>&1`; then \
		git submodule init; \
		git submodule update; \
	fi
patch:
	if [ ! -f "patch_applied" ]; then \
		cd AutoOSInstall && ./apply-patches.sh && cd ..; \
		cd Shrine && ./apply-patches.sh && cd ..; \
		touch patch_applied; \
	fi 
clean:
	rm -rf shrine.img PkgBin/ Shrine-HEAD.iso TempleSlave.iso
reset: clean
	rm -rf patch_applied TempleOS Lsh
	mkdir TempleOS Lsh
