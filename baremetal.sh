#!/bin/bash

set -e
export EXEC_DIR="$PWD"
export OUTPUT_DIR="$EXEC_DIR/sys"

function baremetal_clean {
	rm -rf src/Pure64
	rm -rf src/BareMetal-kernel
	rm -rf bin
	rm -f mcp
}

function baremetal_setup {
	baremetal_clean
	mkdir bin
	mkdir bin/os
	cd src
	echo "Pulling code from GitHub..."
	git clone https://github.com/ReturnInfinity/Pure64.git -q
	git clone https://github.com/ReturnInfinity/BareMetal-kernel.git -q
	cd ..
	baremetal_build
	echo "Done!"
}

function baremetal_build {
	echo "Building software..."
	cp src/interrupt.asm src/BareMetal-kernel/src/
	cp src/BareMetal-kernel/api/libBareMetal* src/
	cd src
	cd Pure64
	./build.sh
	cp bin/* ../../bin/os
	cd ..
	cd BareMetal-kernel
	./build.sh
	cp bin/* ../../bin/os
	cd ../../bin/os
	cat pxestart.sys pure64.sys kernel.sys > pxeboot.bin
	cd ../../src
	nasm test.asm -o ../bin/test.app
	gcc mcp.c -o mcp
	strip mcp
	mv mcp ../bin/
	cd ..
}

function baremetal_install {
	echo "Copying PXE boot file to TFTP..."
	cp pxeboot.bin /srv/tftp/
}

function baremetal_disk {
	echo "Creating disk image..."
	cd bin
	dd if=/dev/zero of=disk.img count=128 bs=1048576 > /dev/null 2>&1
	dd if=/dev/zero of=null.bin count=8 bs=1 > /dev/null 2>&1
	cat pure64.sys kernel.sys > software.sys
	dd if=mbr.sys of=disk.img conv=notrunc > /dev/null 2>&1
	dd if=software.sys of=disk.img bs=4096 seek=2 conv=notrunc > /dev/null 2>&1
	qemu-img convert -O vdi "disk.img" "BareMetal_Node.vdi"
}

function baremetal_help {
	echo "BareMetal-Node Script"
	echo "Available commands:"
	echo "clean    - Clean the src and bin folders"
	echo "setup    - Clean and setup"
	echo "build    - Build source code"
	echo "install  - Copy the PXE boot file to the TFTP folder"
	echo "disk     - Create a disk image for local boot"
}

if [ $# -eq 0 ]; then
	baremetal_help
elif [ $# -eq 1 ]; then
	if [ "$1" == "setup" ]; then
		baremetal_setup
	elif [ "$1" == "clean" ]; then
		baremetal_clean
	elif [ "$1" == "build" ]; then
		baremetal_build
	elif [ "$1" == "install" ]; then
		baremetal_install
	elif [ "$1" == "disk" ]; then
		baremetal_disk
	elif [ "$1" == "help" ]; then
		baremetal_help
	else
		echo "Invalid argument '$1'"
	fi
fi

