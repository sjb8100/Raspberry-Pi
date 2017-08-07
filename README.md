# BareMetal Raspberry-Pi (Linux free zone)
>
Code background: 
https://github.com/LdB-ECM/Raspberry-Pi/blob/master/Documentation/Code_Background.md
>
There are no make files for the repo's as I am a commercial embedded developer and I use Windows and Visual Studio as my IDE. So I am cross compiling to the PI which comes out thru a commercial toolchain. Rather than waste time with rather complex make files I provide a batch file which contains the compile and link commands as they need to be executed. The path to the compiler executables will need to be changed if you want to use them. My path will look like "g:\pi\gcc_pi_6_3\bin\arm-none-eabi-gcc" and "g:\pi\gcc_pi_6_3\bin\arm-none-eabi-objcopy" you will need to change it to the path of arm-none-eabi-gcc.exe and arm-none-eabi-objcopy.exe on your system. The files have only 2 active lines and easy enough to convert to bash scripts for linux users.

32 Bit Toolchain I use (Multiple O/S are supported):
>https://developer.arm.com/open-source/gnu-toolchain/gnu-rm/downloads
>
To compile on the Pi itself: https://github.com/LdB-ECM/Raspberry-Pi/blob/master/Documentation/GCC6_On_Pi.md
>
64 Bit Toolchain I use (Multiple O/S are supported):
>https://releases.linaro.org/components/toolchain/binaries/latest/aarch64-elf/


# USB-HID (Pi1,2,3 32Bit .. new** AARCH64 alpha up)
>AARCH64 Alpha: https://github.com/LdB-ECM/Raspberry-Pi/tree/master/Arm32_64_USB
>
Complete redux of CSUD (Chadderz's Simple USB Driver) by Alex Chadwick. All the memory allocation is gone and compacted to a single file (usb.c). It provides the Control channel functionality for a USB which enables enumeration. The HID support is very very basic and operates in the control channel. Later versions will add the full channels and full HID implementation. It works on Pi1, Pi2 & Pi3. If you want to just see what it does format an SD card and place the files in the diskimg directory onto it, place in Pi and turn power on. All being equal you should see something like this.
![](https://github.com/LdB-ECM/Raspberry-Pi/blob/master/Images/USB_HID.jpg)
# MULTICORE (Pi1,2,3 32Bit .. new*** Pi3 AARCH64)
>https://github.com/LdB-ECM/Raspberry-Pi/tree/master/Multicore
>
Please remember the Pi1 is single processor. So while you can build code for a Pi1 it can't be used for hyperthreading unless used on a Pi2 or Pi3. The assembler and linker files are paired you use either the 32 bit or 64 bit together.
>
The SmartStartxx.S assembler boot stub was extended to setup cores 1,2,3 for hyperthreading. A new spinlock was created which mimics the bootloaders but is C compiler safe. To do that registers that would be trashed by C routines where restored when the core process is called. In addition to that each core has its own stack the size of which is controlled by the new matching linker file (rpixx.ld).
>
As per usual you can simply copy the files in the DiskImg directory onto a formatted SD card and place in Pi to test 
![](https://github.com/LdB-ECM/Raspberry-Pi/blob/master/Images/Multicore.jpg)
# MYBLINKER (AARCH64 Pi3 .. 64Bit only avail on Pi3)
Yes it's the boring old interrupt timer and blinking LED this time with the Pi3 in 64Bit mode. The technical background is the Pi3 is given to us in EL2 state. The timer interrupt is routed to EL1 where the interrupt service is established. It is obviously the first steps in how to route interrupt signals to services on the Pi3 in 64bit mode. 

