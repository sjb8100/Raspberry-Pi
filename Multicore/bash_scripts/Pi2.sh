#!/bin/bash
gcc-6 -Wall -O2 -mfpu=neon -mfloat-abi=hard -march=armv7-a -mtune=cortex-a7 -nostdlib -nostartfiles -ffreestanding -fno-common -Wl,-gc-sections -Wl,--build-id=none -Wl,-T,rpi32.ld main.c smartstart32.S rpi-BasicHardware.c printf.c -o kernel.elf -lc -lm -lgcc
objcopy kernel.elf -O binary kernel7.img
