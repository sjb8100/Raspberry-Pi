#!/bin/bash
gcc-6 -Wall -O2 -mfpu=vfp -mfloat-abi=hard -march=armv6zk -mtune=arm1176jzf-s -nostdlib -nostartfiles -ffreestanding -fno-common -Wl,-gc-sections -Wl,--build-id=none -Wl,-T,rpi32.ld main.c smartstart32.S rpi-BasicHardware.c printf.c -o kernel.elf -lc -lm -lgcc
objcopy kernel.elf -O binary kernel.img
