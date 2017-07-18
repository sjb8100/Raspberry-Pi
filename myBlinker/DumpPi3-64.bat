@REM COMPILER COMMAND LINE
g:\pi\gcc_linaro_6_3\bin\aarch64-elf-gcc.exe -Wall -O2 -march=armv8-a -mtune=cortex-a53 -nostartfiles -specs=nosys.specs -ffunction-sections -Wl,-gc-sections -Wl,-T,rpi64.ld main.c SmartStart64.S rpi-BasicHardware.c -o kernel.elf -lc -lm -Wa,-a >list.txt
@echo off
if %errorlevel% EQU 1 (goto build_fail)

@REM LINKER COMMAND LINE
@echo on
g:\pi\gcc_linaro_6_3\bin\aarch64-elf-objcopy kernel.elf -O binary kernel8.img
@echo off
if %errorlevel% EQU 1 (goto build_fail) 
echo BUILD COMPLETED NORMALLY
pause
exit /b 0

:build_fail
echo ********** BUILD FAILURE **********
Pause
exit /b 1