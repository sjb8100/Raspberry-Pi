#!/bin/bash
gcc-6 -Wall -O2 -mfpu=neon-vfpv4 -mfloat-abi=hard -march=armv8-a -mtune=cortex-a53 -nostdlib -nostartfiles -ffreestanding -fno-common -Wl,-gc-sections -Wl,--build-id=none -Wl,-T,rpi32.ld main.c  SmartStart32.S rpi-BasicHardware.c printf.c -o kernel.elf -lc -lm -lgcc
objcopy kernel.elf -O binary kernel8-32.img
