
# USB ... PI3 AARCH64, PI 1,2,3 AARCH32
>#New version coming with USB drive and Ethernet
>
My redux of CSUD (Chadderz's Simple USB Driver) by Alex Chadwick was converted to 32/64 bit compatible code. I merged SmartStart 2.0.3 code to bring the Alpha USB up to my latest bootstub.

I have new GLES code which requires access to ethernet which means having the LAN9512/LAN9514 running. This is a small step to merge the existing code onto the newer smartstart bootstub. 

If you just want to just test it to see what does, just put the files in the DiskImg directory on a formatted SD card and place in Pi.
>
![](https://github.com/LdB-ECM/Docs_and_Images/blob/master/Images/USB64_alpha.jpg)
