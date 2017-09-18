# ROTATE 3D MODEL - (Pi1, 2, 3 - AARCH32, Pi3 AARCH64)
>
Update: 64Bit version solved sscanf was bugged in the newlib, I had to rewrite the function. I am getting so fed up with stdio.h in newlib 64bit I might just complete the job and replace all the functions. I had already put up a partial for Printf which was also bugged on 64 bit. The change in integer size from 4 to 8 bit in AARCH64 had not been dealt with properly.
>
Update: All memory allocation now removed from render call and render speed now goes well over 800fps so I timed the rotation speed. You will notice rotation is alot smoother.
>
So we continue our GL pipe adventure slowly crawling towards something that ressembles minimal OpenGL.
>
So we work on rotating an actual LightWave OBJ 3D mesh model:
>
![](https://github.com/LdB-ECM/Docs_and_Images/blob/master/Images/spacecraft.jpg?raw=true)

Streaming video of output:
>
https://streamable.com/yte1n
>
As per usual you can simply copy the files in the DiskImg directory onto a formatted SD card and place in Pi to test 
