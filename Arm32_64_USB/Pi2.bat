@REM COMPILER COMMAND LINE
g:\pi\gcc_pi_6_3\bin\arm-none-eabi-gcc -Wall -O2 -mfpu=neon -mfloat-abi=hard -march=armv7-a -mtune=cortex-a7 -nostdlib -nostartfiles -specs=nosys.specs -ffreestanding -fno-common -Wl,-gc-sections -Wl,--build-id=none -Wl,-T,rpi32.ld main.c smartstart32.S rpi-BasicHardware.c printf.c rpi-usb.c -o kernel.elf -lc -lm -lgcc
@echo off
if %errorlevel% EQU 1 (goto build_fail)

@REM LINKER COMMAND LINE
@echo on
g:\pi\gcc_pi_6_3\bin\arm-none-eabi-objcopy kernel.elf -O binary kernel7.img
@echo off
if %errorlevel% EQU 1 (goto build_fail) 
echo BUILD COMPLETED NORMALLY
pause
exit /b 0

:build_fail
echo ********** BUILD FAILURE **********
Pause
exit /b 1