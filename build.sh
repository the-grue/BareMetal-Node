#!/bin/bash

cp interrupt.asm src/BareMetal-kernel/src/
cd src
cd Pure64
./build.sh
cp bin/* ..
cd ..
cd BareMetal-kernel
./build.sh
cp bin/* ..
cd ..
cat pxestart.sys pure64.sys kernel.sys > pxeboot.bin
cp pxeboot.bin ..
cd ..
gcc mcp.c -o mcp
strip mcp
