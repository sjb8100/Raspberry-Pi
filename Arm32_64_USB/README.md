
# USB alpha ... PI3 only AARCH64 and AARCH32
My redux of CSUD (Chadderz's Simple USB Driver) by Alex Chadwick was converted to 64 bit. I also merged nested interrupt code which blinks the LED while the USB runs. Finally the 32 bit version also had the multicore operation merged from the multicore code.

Having got the interrupts nested and running I will now complete the USB channels and implement a complete interrupt driven USB system.

I have yet to port the whole of the standards library in 64bit so the printf is currently produced by a printf.c implementation. The graphics text support is very basic it supports only 32 bit color depth. It's all a bit rough but this is simply a snapshot of a work in progress and as a sample of a fairly complex AARCH64 code running.

If you just want to see it just put the files in the firmware directory on a formatted SD card and place in Pi3.
>
![](https://github.com/LdB-ECM/Raspberry-Pi/blob/master/Images/USB64_alpha.jpg)
