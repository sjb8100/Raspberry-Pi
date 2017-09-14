# ROTATE MODEL - (Pi1, 2, 3 - AARCH32)
>
So we continue to beat up the GL pipe inside the VC4 directly. Now we have add sdCard with FAT32 support and code to load a lightwave OBJ 3D mesh file. The DiskImg directory has a subdirectory \\SpaceCraft\\Runner which contains our model spacecraft.obj

The Model loader does 2 passes, first to determine the vetex and face count. From that it makes a GPU memory allocation and on the second pass stores all the vertex data. Finally we build a simple matrix scaffold to rotate the model. The we render a frame, rotate the model, render a frame etc over and over. Again I have not worried about double buffering which will probably be in next version.

Now we are starting to get something that ressembles a real OpenGL system and it's time to turn attention to the shaders.

Very hard to get a screen cap of this you might be better just trying it. Simply copy the files in the DiskImg directory onto a formatted SD card (make sure this includes the subdirectory "\\SpaceCraft\\Runner") and place in Pi to test 

As we get a bit further I will do more of a right feel free to ask questions on the Raspberry forum
https://www.raspberrypi.org/forums/viewtopic.php?f=72&p=1206923#p1206923

Streaming video of output:
>
https://streamable.com/yte1n
