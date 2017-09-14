#include <stdbool.h>			// Neede for bool
#include <stdint.h>				// Needed for uint32_t, uint16_t etc
#include <string.h>				// Needed for memcpy
#include "emb-stdio.h"			// Needed for printf
#include "rpi-smartstart.h"		// Needed for smart start API 
#include "rpi-GLES.h"
#include "SDCard.h"


struct obj_model_t model = { 0 };
int main (void) {
	InitV3D();														// Start 3D graphics
	ARM_setmaxspeed(NULL);											// ARM CPU to max speed no message to screen
	PiConsole_Init(0, 0, 32, NULL);									// Auto resolution console, no message to screen

	sdInitCard(printf, printf, true);
	CreateVertexData("\\spacecraft\\runner\\spacecraft.obj", &model, &printf);
	DoRotate(0.0f);													// Preset rotation matrix

	// Render a triangle to screen.
	// In this simple example we are using live screen framebuffer
	// Usually you would do to an off screen buffer or memory
	// I strongly suggest you don't do this when we start animation or you will see screen tearing
	RenderModel(GetConsole_Width()/2, GetConsole_Height()/2, 
		ARMaddrToGPUaddr((void*)(uintptr_t)GetConsole_FrameBuffer()), &model,
		printf);

	while (1){
		DoRotate(0.1f);
		RenderModel(GetConsole_Width()/2, GetConsole_Height()/2,
			ARMaddrToGPUaddr((void*)(uintptr_t)GetConsole_FrameBuffer()), &model,
			printf);
    }
	return(0);
}
