# Raspberry-Pi
My public workings with the Raspberry Pi in Assembler and C. Much of the code here was done for and covered by articles on CodeProject.com.

>/*+++++++++++++++[ ALL CODE IN THE REPOSITORY IS FREEWARE ]+++++++++++++++++}
>                                                               
>  This sourcecode is released for the purpose to promote programming on the Raspberry Pi. You may redistribute it and/or modify with the following disclaimer.
>
>  The SOURCE CODE is distributed "AS IS" WITHOUT WARRANTIES AS TO PERFORMANCE OF MERCHANTABILITY WHETHER EXPRESSED OR IMPLIED. Redistributions of source code must retain the copyright notices for verification of origin.               	
>
>{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/

# USB-HID
Complete redux of CSUD (Chadderz's Simple USB Driver) by Alex Chadwick. All the memory allocation is gone and compacted to a single file (usb.c). It provides the Control channel functionality for a USB which enables enumeration. The HID support is very very basic and operates in the control channel. Later versions will add the full channels and full HID implementation. It works on Pi1, Pi2 & Pi3. If you want to just see what it does format an SD card and place the files in the diskimg directory onto it, place in Pi and turn power on.
