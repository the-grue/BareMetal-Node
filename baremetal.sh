#!/bin/bash

set -e
export EXEC_DIR="$PWD"
export OUTPUT_DIR="$EXEC_DIR/sys"

function baremetal_clean {
	rm -rf src/Pure64
	rm -rf src/BareMetal-kernel
	rm -rf src/libBareMetal.*
	rm -rf src/*.o
	rm -rf src/*.app
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
	sed -i '' 's/KERNELSIZE equ 8192/KERNELSIZE equ 16384/g' src/BareMetal-kernel/src/kernel.asm
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
	cd ../../src
	nasm console.asm -o ../bin/os/console.sys
	cd ../bin/os
	cat pxestart.sys pure64.sys kernel.sys console.sys > pxeboot.bin
	cd ../../src
	nasm test.asm -o ../bin/test.app
	if [ "$(uname)" != "Darwin" ]; then
		gcc mcp.c -o mcp
		strip mcp
		mv mcp ../bin/
		gcc -c -m64 -nostdlib -nostartfiles -nodefaultlibs -mno-red-zone -falign-functions=16 -o primesmp.o primesmp.c
		gcc -c -m64 -nostdlib -nostartfiles -nodefaultlibs -mno-red-zone -falign-functions=16 -o libBareMetal.o libBareMetal.c
		objcopy --remove-section .eh_frame --remove-section .rel.eh_frame --remove-section .rela.eh_frame primesmp.o
		objcopy --remove-section .eh_frame --remove-section .rel.eh_frame --remove-section .rela.eh_frame libBareMetal.o
		ld -T c.ld -o primesmp.app primesmp.o libBareMetal.o
		chmod -x primesmp.app
		mv primesmp.app ../bin/
	fi
	cd ..
}

function baremetal_install {
	echo "Copying PXE boot file to TFTP..."
	cp pxeboot.bin /srv/tftp/
}

function baremetal_disk {
	echo "Creating disk image..."
	cd bin/os
	dd if=/dev/zero of=disk.img count=128 bs=1048576 > /dev/null 2>&1
	cat pure64.sys kernel.sys console.sys > software.sys
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

