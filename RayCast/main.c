#include <stdbool.h>		// C standard needed for bool
#include <stdint.h>			// C standard for uint8_t, uint16_t, uint32_t etc
#include <stdio.h>				// Needed for printf
#include <string.h>
#include <math.h>
#include "rpi-smartstart.h"		
#include "rpi-BasicHardware.h"

static bool lit = false;
void c_irq_handler (void) {
	if (lit) lit = false; else lit = true;							// Flip lit flag
	set_Activity_LED(lit);											// Turn LED on/off as per new flag
}

void c_irq_identify_and_clear_source (void) {
	/* Clear the ARM Timer interrupt - it's the only interrupt we have enabled, 
	   so we want don't have to work out which interrupt source caused us to interrupt */
	ARMTIMER->Clear = 1;											// Write any value to register to clear irq ... PAGE 198

	/* As we are running nested interrupts we must clear the Pi Irq controller,
	   the timer irq pending is bit 0 of pending register 1 as it's irq 0 */
	IRQ->IRQPending1 &= ~0x1;										// Clear timer pending irq bit 0
}

typedef struct __attribute__((__packed__)) structRGBA {
	union {
		struct {
			uint8_t B;
			uint8_t G;
			uint8_t R;
			uint8_t A;
		};
		RGBA rawRGBA;
		uint32_t raw32;
	};
} RGBACOLOR;

/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{              DEFINE THE 16 BASIC VGA GRAPHICS COLORS AS RBGA              }
{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
#define RGBA_Black  (RGBACOLOR){.R=0x00, .G=0x00, .B=0x00, .A=0xFF}		// 0 = Black
#define RGBA_Blue	(RGBACOLOR){.R=0x00, .G=0x00, .B=0x7F, .A=0xFF}		// 1 = Blue
#define RGBA_Green	(RGBACOLOR){.R=0x00, .G=0x7F, .B=0x00, .A=0xFF}		// 2 = Green 
#define RGBA_Cyan	(RGBACOLOR){.R=0x00, .G=0x7F, .B=0x7F, .A=0xFF}		// 3 = Cyan
#define RGBA_Red	(RGBACOLOR){.R=0x7F, .G=0x00, .B=0x00, .A=0xFF}		// 4 = Red
#define RGBA_Magenta (RGBACOLOR){.R=0x7F, .G=0x00, .B=0x7F, .A=0xFF}		// 5 = Magenta
#define RGBA_Brown	(RGBACOLOR){.R=0x7F, .G=0x7F, .B=0x00, .A=0xFF}		// 6 = Brown
#define RGBA_LightGray (RGBACOLOR){.R=0xAF, .G=0xAF, .B=0xAF, .A=0xFF}	// 7 = LightGray
#define RGBA_DarkGray (RGBACOLOR){.R=0x4F, .G=0x4F, .B=0x4F, .A=0xFF}	// 8 = DarkGray
#define RGBA_LightBlue (RGBACOLOR){.R=0x00, .G=0x00, .B=0xFF, .A=0xFF}	// 9 = Light Blue
#define RGBA_LightGreen (RGBACOLOR){.R=0x00, .G=0xFF, .B=0x00, .A=0xFF}	// 10 = Light Green
#define RGBA_LightCyan (RGBACOLOR){.R=0x00, .G=0xFF, .B=0xFF, .A=0xFF}	// 11 = Light Cyan
#define RGBA_LightRed (RGBACOLOR){.R=0xFF, .G=0x00, .B=0x00, .A=0xFF}	// 12 = Light Red
#define RGBA_LightMagenta (RGBACOLOR){.R=0xFF, .G=0x00, .B=0xFF, .A=0xFF}// 13 = Light Magenta
#define RGBA_Yellow	(RGBACOLOR){.R=0xFF, .G=0xFF, .B=0x00, .A=0xFF}		// 14 = Yellow
#define RGBA_White (RGBACOLOR){.R=0xFF, .G=0xFF, .B=0xFF, .A=0xFF}		// 15 = White

#define mapWidth 24
#define mapHeight 24

int worldMap[mapWidth][mapHeight]=
{
  {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,0,0,0,0,0,2,2,2,2,2,0,0,0,0,3,0,3,0,3,0,0,0,1},
  {1,0,0,0,0,0,2,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,0,0,0,0,0,2,0,0,0,2,0,0,0,0,3,0,0,0,3,0,0,0,1},
  {1,0,0,0,0,0,2,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,0,0,0,0,0,2,2,0,2,2,0,0,0,0,3,0,3,0,3,0,0,0,1},
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,4,4,4,4,4,4,4,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,4,0,4,0,0,0,0,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,4,0,0,0,0,5,0,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,4,0,4,0,0,0,0,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,4,0,4,4,4,4,4,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,4,4,4,4,4,4,4,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1}
};


RGBACOLOR Buffer[2000 * 1400];


int grWth = 1280;
int grHt = 1024;
int main (void) {
	PiConsole_Init(grWth, grHt, 32);
	printf("SmartStart compiled for Arm%d, AARCH%d with %u core s/w support\n",
		RPi_CompileMode.CodeType, RPi_CompileMode.AArchMode * 32 + 32,
		(unsigned int)RPi_CompileMode.CoresSupported);							// Write text
	double posX = 22, posY = 12;  //x and y start position
	double dirX = -1, dirY = 0; //initial direction vector
	double planeX = 0, planeY = 0.66; //the 2d raycaster version of camera plane

	//double time = 0; //time of current frame
	//double oldTime = 0; //time of previous frame

    /* Enable the timer interrupt IRQ */
	IRQ->EnableBasicIRQs.Enable_Timer_IRQ = true;


    /* Setup the system timer interrupt */
	ARMTIMER->Load = 0x400;

    /* Setup the ARM Timer */
	ARMTIMER->Control.Counter32Bit = true;
	ARMTIMER->Control.Prescale = Clkdiv256;
	ARMTIMER->Control.TimerIrqEnable = true;
	ARMTIMER->Control.TimerEnable = true;

    /* Enable interrupts! */
    EnableInterrupts();

	int w = 1280; //800;
	int h = 600;  //400;
	while (1) {

		for(int x = 0; x < w; x++) {
			//calculate ray position and direction
			double cameraX = 2 * x / (double)w - 1; //x-coordinate in camera space
			double rayPosX = posX;
			double rayPosY = posY;
			double rayDirX = dirX + planeX * cameraX;
			double rayDirY = dirY + planeY * cameraX;
			//which box of the map we're in
			int mapX = (int)rayPosX;
			int mapY = (int)rayPosY;

			//length of ray from current position to next x or y-side
			double sideDistX;
			double sideDistY;

			//length of ray from one x or y-side to next x or y-side
			double deltaDistX = sqrt(1 + (rayDirY * rayDirY) / (rayDirX * rayDirX));
			double deltaDistY = sqrt(1 + (rayDirX * rayDirX) / (rayDirY * rayDirY));
			double perpWallDist;

			//what direction to step in x or y-direction (either +1 or -1)
			int stepX;
			int stepY;

			int hit = 0; //was there a wall hit?
			int side; //was a NS or a EW wall hit?
			//calculate step and initial sideDist
			if (rayDirX < 0){
				stepX = -1;
				sideDistX = (rayPosX - mapX) * deltaDistX;
			} else {
				stepX = 1;
				sideDistX = (mapX + 1.0 - rayPosX) * deltaDistX;
			}
			if (rayDirY < 0) {
				stepY = -1;
				sideDistY = (rayPosY - mapY) * deltaDistY;
			} else {
				stepY = 1;
				sideDistY = (mapY + 1.0 - rayPosY) * deltaDistY;
			}
			//perform DDA
			while (hit == 0) {
				//jump to next map square, OR in x-direction, OR in y-direction
				if (sideDistX < sideDistY) {
					sideDistX += deltaDistX;
					mapX += stepX;
					side = 0;
				} else {
					sideDistY += deltaDistY;
					mapY += stepY;
					side = 1;
				}
				//Check if ray has hit a wall
				if (worldMap[mapX][mapY] > 0) hit = 1;
			}
			//Calculate distance projected on camera direction (oblique distance will give fisheye effect!)
			if (side == 0) perpWallDist = (mapX - rayPosX + (1 - stepX) / 2) / rayDirX;
			else           perpWallDist = (mapY - rayPosY + (1 - stepY) / 2) / rayDirY;

			//Calculate height of line to draw on screen
			int lineHeight = (int)(h / perpWallDist);

			//calculate lowest and highest pixel to fill in current stripe
			int drawStart = -lineHeight / 2 + h / 2;
			if(drawStart < 0)drawStart = 0;
			int drawEnd = lineHeight / 2 + h / 2;
			if(drawEnd >= h)drawEnd = h - 1;

			//choose wall color
			RGBACOLOR color;
			switch(worldMap[mapX][mapY]) {
				case 1:  color = RGBA_Red;  break; //red
				case 2:  color = RGBA_Green;  break; //green
				case 3:  color = RGBA_Blue;   break; //blue
				case 4:  color = RGBA_White;  break; //white
				default: color = RGBA_Yellow; break; //yellow
			}

			//give x and y sides different brightness
			if (side == 1) {color.R = color.R / 2; color.G = color.G / 2; color.B = color.B / 2; }

			//draw the pixels of the stripe as a vertical line
			//verLine(x, drawStart, drawEnd, color);
			PiConsole_VertLine(x, 0, drawStart, 0x0);
			PiConsole_VertLine(x, drawStart, drawEnd, color.raw32);
			PiConsole_VertLine(x, drawEnd, grHt, 0x0);

		}
		//timing for input and FPS counter
		//oldTime = time;
		//time = getTicks();
		//double frameTime = (time - oldTime) / 1000.0; //frameTime is the time this frame has taken, in seconds
		//printf(1.0 / frameTime); //FPS counter
		//redraw();

		/*for (int y = 0; y < grHt; y++) {
			uint32_t lineOffs = y * grWth;
			for (int x = 0; x < grWth; x++) {
				PiConsole_VertLine(x, y, y, Buffer[lineOffs + x].raw32);
			}
		}

		memset(&Buffer[0], 0, sizeof(Buffer));*/
		

		//speed modifiers
		//double moveSpeed = frameTime * 5.0; //the constant value is in squares/second
		double rotSpeed = 0.02; // frameTime * 3.0; //the constant value is in radians/second
		

		//readKeys();
		//move forward if no wall in front of you
		//if (keyDown(SDLK_UP))
		//{
		//	if(worldMap[int(posX + dirX * moveSpeed)][int(posY)] == false) posX += dirX * moveSpeed;
		//	if(worldMap[int(posX)][int(posY + dirY * moveSpeed)] == false) posY += dirY * moveSpeed;
		//}
		//move backwards if no wall behind you
		//if (keyDown(SDLK_DOWN))
		//{
		//	if(worldMap[int(posX - dirX * moveSpeed)][int(posY)] == false) posX -= dirX * moveSpeed;
		//	if(worldMap[int(posX)][int(posY - dirY * moveSpeed)] == false) posY -= dirY * moveSpeed;
		//}
		//rotate to the right
		//if (keyDown(SDLK_RIGHT))
		//{
			//both camera direction and camera plane must be rotated
			double oldDirX = dirX;
			dirX = dirX * cos(-rotSpeed) - dirY * sin(-rotSpeed);
			dirY = oldDirX * sin(-rotSpeed) + dirY * cos(-rotSpeed);
			double oldPlaneX = planeX;
			planeX = planeX * cos(-rotSpeed) - planeY * sin(-rotSpeed);
			planeY = oldPlaneX * sin(-rotSpeed) + planeY * cos(-rotSpeed);
		//}
		//rotate to the left
		//if (keyDown(SDLK_LEFT))
		//{
			//both camera direction and camera plane must be rotated
		//	double oldDirX = dirX;
		//	dirX = dirX * cos(rotSpeed) - dirY * sin(rotSpeed);
		//	dirY = oldDirX * sin(rotSpeed) + dirY * cos(rotSpeed);
		//	double oldPlaneX = planeX;
		//	planeX = planeX * cos(rotSpeed) - planeY * sin(rotSpeed);
		//	planeY = oldPlaneX * sin(rotSpeed) + planeY * cos(rotSpeed);
		//}

	}

	return(0);
}