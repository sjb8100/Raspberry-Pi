#!/bin/sh
echo "Building for ARM8 AARCH32"
gcc-6 -Wall -O3 -mfpu=neon -mfloat-abi=hard -march=armv7ve -mtune=cortex-a7 -mno-unaligned-access -nostdlib -nodefaultlibs -nostartfiles -ffreestanding -fno-asynchronous-unwind-tables -fomit-frame-pointer -Wa,-a>list.txt -Wl,-gc-sections -Wl,--build-id=none -Wl,-Bdynamic -Wl,-Map,kernel.map -Wl,-T,rpi32.ld Main.c SmartStart32.S rpi-SmartStart.c emb-stdio.c rpi-USB.c -o kernel.elf -lc -lm -lgcc
if [ $? != "0" ]; then
   echo "*** Compiler command failed"
   exit 1
fi
objcopy kernel.elf -O binary DiskImg/kernel8-32.img
if [ $? != "0" ]; then
   echo "*** Linker command failed"
   exit 1
fi
echo "Kernel8-32.img successfuilly created"