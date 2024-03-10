#!/bin/bash

set -e
export EXEC_DIR="$PWD"
export OUTPUT_DIR="$EXEC_DIR/sys"

function baremetal_clean {
	rm -rf src
	rm -rf bin
}

function baremetal_setup {
	baremetal_clean
	mkdir src
	mkdir bin
	cd src
	git clone https://github.com/ReturnInfinity/Pure64.git
	git clone https://github.com/ReturnInfinity/BareMetal-kernel.git
	cd ..
	baremetal_build
}

function baremetal_build {
	cp interrupt.asm src/BareMetal-kernel/src/
	cd src
	cd Pure64
	./build.sh
	cp bin/* ../../bin
	cd ..
	cd BareMetal-kernel
	./build.sh
	cp bin/* ../../bin
	cd ../../bin
	cat pxestart.sys pure64.sys kernel.sys > pxeboot.bin
	cd ..
	gcc mcp.c -o mcp
	strip mcp
}

function baremetal_install {
	cp pxeboot.bin /srv/tftp/
}

function baremetal_help {
	echo "BareMetal-Node Script"
	echo "Available commands:"
	echo "clean    - Clean the src and bin folders"
	echo "setup    - Clean and setup"
	echo "build    - Build source code"
	echo "install  - Copy the PXE boot file to the TFTP folder"
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
	elif [ "$1" == "help" ]; then
		baremetal_help
	else
		echo "Invalid argument '$1'"
	fi
fi

