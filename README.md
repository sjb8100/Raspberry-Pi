# BareMetal Raspberry-Pi (Linux free zone)
My public baremetal workings with the Raspberry Pi in Assembler and C. Much of the code here was done for and covered by articles on CodeProject.com.

>/*+++++++++++++++[ ALL CODE IN THE REPOSITORY IS FREEWARE ]+++++++++++++++++}
>                                                               
>  This sourcecode is released for the purpose to promote programming on the Raspberry Pi. You may redistribute it and/or modify with the following disclaimer.
>
>  The SOURCE CODE is distributed "AS IS" WITHOUT WARRANTIES AS TO PERFORMANCE OF MERCHANTABILITY WHETHER EXPRESSED OR IMPLIED. Redistributions of source code must retain the copyright notices for verification of origin.               	
>
>+++++++++++++++++++++[ COMPILING REPOSITORY CODE ]++++++++++++++++++++++
>
>There are no make files for the repo's as I am a commercial embedded developer and I use Windows and Visual Studio as my IDE. So I am cross compiling to the PI which comes out thru a commercial toolchain. Rather than waste time with rather complex make files I provide a batch file which contains the compile and link commands as they need to be executed. The path to the compiler executables will need to be changed if you want to use them. My path will look like "g:\pi\gcc_pi_6_3\bin\arm-none-eabi-gcc" and "g:\pi\gcc_pi_6_3\bin\arm-none-eabi-objcopy" you will need to change it to the path of arm-none-eabi-gcc.exe and arm-none-eabi-objcopy.exe on your system"
>
>I write a lot of 64bit as well as 32Bit code on the Pi so when I am accessing 32bit registers I will always use the C/C++ standard "uin32_t" as the type. If I used "int" then in 64 bit mode my registers would suddenly go to 64bit wide which is obviously wrong and fatal. So most of my files will have #include <stdint.h> and use "unit32_t" type. If you don't know "int" width is compiler implementation defined and it is wrong to use for access to a fixed hardware register width. 
>
>The files are intended as teaching excercise so the files are not broken up into library arrangements they tend to be clumped together by funcionality. I am not a great fan of using structs to represent hardware but firstly the DesignWare USB reference files were that way to start with, and Secondly it does make them easier to read as a teaching excercise. So expect it and don't complain, you are free to change it if you don't like. Where a struct represent hardware there are volatiles on every way you access the register because GCC historically had a number of bugs. Technically they don't need it but I don't have time to chase compiler bugs if they occur.
>
>My assembler bootstub called Smartstart.S autodetects Pi version and provides the base address via the variable RPi_IO_Base_Addr in both assembler and C. All hardware pointers I use simply add the offset to the detected address so there is no need to specify Pi model. Would stringly suggest you use the same technique with something like.
>
>#define PiReg ((volatile __attribute__((aligned(4))) uint32_t PiRegister*) (RPi_IO_Base_Addr + ????????))
>{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/

# USB-HID
Complete redux of CSUD (Chadderz's Simple USB Driver) by Alex Chadwick. All the memory allocation is gone and compacted to a single file (usb.c). It provides the Control channel functionality for a USB which enables enumeration. The HID support is very very basic and operates in the control channel. Later versions will add the full channels and full HID implementation. It works on Pi1, Pi2 & Pi3. If you want to just see what it does format an SD card and place the files in the diskimg directory onto it, place in Pi and turn power on. All being equal you should see something like this.
![](https://github.com/LdB-ECM/Raspberry-Pi/blob/master/Images/USB_HID.jpg)
