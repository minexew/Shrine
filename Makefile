build: patch
	if `which qemu-img > /dev/null 2>&1`; then \
		qemu-img create -f qcow2 shrine.img 2G; \
		mkdir PkgBin; \
		python make-dist.py TOS_Distro.ISO Shrine shrine.img; \
	fi 	
patch:
	cd AutoOSInstall && ./apply-patches.sh         
	cd Shrine && ./apply-patches.sh 
clean:
	rm -rf shrine.img PkgBin/ Shrine-HEAD.iso TempleSlave.iso
