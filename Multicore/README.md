# MULTICORE Pi 1,2,3 AARCH 32, *NEW* Pi3 AARCH64 
>
>The SmartStartxx.S assembler boot stub was extended to setup cores 1,2,3 for hyperthreading. A new spinlock was created which mimics the bootloaders but is C compiler safe. To do that registers that would be trashed by C routines where restored when the core process is called. In addition to that each core has its own stack the size of which is controlled by the new matching linker file (rpixx.ld).
>
>The demo uses printf to screen which is very dangerous because printf is not re-entrant so I took a bit of care to avoid clashes using it. Please don't try and take using printf too far what is expected is you setup proper thread safe C code. The random core hyperthread calls are cause by the interrupt timer.
>
> rpi-SmartStart.h provides the C 
function bool CoreExecute (uint8_t coreNum, CORECALLFUNC func);
Where CORECALLFUNC is defined as
typedef void (*CORECALLFUNC) (void);
>
So CoreExecute can assign any "void function (void)" to be execute by the given core (1..3).
>
> As per usual you can simply copy the files in the firmware onto a format SD card and place in Pi to test
>
![](https://github.com/LdB-ECM/Raspberry-Pi/blob/master/Images/Multicore.jpg)