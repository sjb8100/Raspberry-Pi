@REM COMPILER COMMAND LINE
g:\pi\gcc_pi_6_3\bin\arm-none-eabi-gcc -Wall -O2 -mfpu=neon-vfpv4 -mfloat-abi=hard -march=armv8-a -mtune=cortex-a53 -nostdlib -nostartfiles -ffreestanding -fno-common -Wl,-gc-sections -Wl,--build-id=none -Wl,-T,rpi32.ld main.c  SmartStart32.S rpi-BasicHardware.c printf.c -o kernel.elf -lc -lm -lgcc
@echo off
if %errorlevel% EQU 1 (goto build_fail)

@REM LINKER COMMAND LINE
@echo on
g:\pi\gcc_pi_6_3\bin\arm-none-eabi-objcopy kernel.elf -O binary kernel8-32.img
@echo off
if %errorlevel% EQU 1 (goto build_fail) 
echo BUILD COMPLETED NORMALLY
pause
exit /b 0

:build_fail
echo ********** BUILD FAILURE **********
Pause
exit /b 1
