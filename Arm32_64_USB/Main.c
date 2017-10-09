#include <stdbool.h>			// C standard needed for bool
#include <stdint.h>				// C standard for uint8_t, uint16_t, uint32_t etc
#include <string.h>
#include <stdlib.h>
#include "emb-stdio.h"				// Needed for printf
#include "rpi-SmartStart.h"
#include "rpi-USB.h"

static bool lit = false;
void c_irq_handler(void) {
	if (lit) lit = false; else lit = true;							// Flip lit flag
	set_Activity_LED(lit);											// Turn LED on/off as per new flag
}

static uint8_t firstMouse = 0;
static uint8_t firstKbd = 0;
int main (void) {
	PiConsole_Init(0, 0, 0, printf);								// Auto resolution console, no message to screen
	displaySmartStart(printf);										// Display smart start details
	ARM_setmaxspeed(printf);										// ARM CPU to max speed no message to screen
	TimerIrqSetup(500000, c_irq_handler);							// Give me flashing LED so I can tell if I have locked irq pipe up 
	EnableInterrupts();												// Start interrupts rolling

	/* Initialize USB system we will want keyboard and mouse */
	UsbInitialise(printf, NULL);									// Start USB display only console messages

	printf("\n");
	UsbShowTree(UsbGetRootHub(), 1, '+');
	printf("\n");

	uint32_t x, y;
	WhereXY(&x, &y);
	uint8_t buf[128];

	for (int i = 1; i <= MaximumDevices; i++) {
		if (IsMouse(i)) {
			firstMouse = i;
			break;
		}
	}

	for (int i = 1; i <= MaximumDevices; i++) {
		if (IsKeyboard(i)) {
			firstKbd = i;
			break;
		}
	}

	printf("First Mouse id: %i, First KeyBoard id: %i\n", firstMouse, firstKbd);
	while (1) {
		timer_wait(50000);
		GotoXY(x, y);
		// Read first mouse, default Input report ... 4 bytes to buf
		if ((firstMouse != 0) && (HIDReadReport(firstMouse, 0, (uint16_t)USB_HID_REPORT_TYPE_INPUT << 8 | 0, &buf[0], 4) == OK)) {	
			//ClearArea(x, y, x + 600, y + BitFontHt, 0x0);
			printf("HID MOUSE REPORT: Buttons: 0x%02x  X move: 0x%02x, Y move: 0x%02x, Wheel: 0x%02x\n",
				buf[0], buf[1], buf[2], buf[3]);
		}
		// Read first mouse, default Input report ... 4 bytes to buf
		if ((firstKbd != 0) && (HIDReadReport(firstKbd, 0, (uint16_t)USB_HID_REPORT_TYPE_INPUT << 8 | 0, &buf[0], 8) == OK)) {
			printf("HID KEYBOARD REPORT: Modifier: 0x%02x Key Press: 0x%02x\n", buf[0], buf[2]);
		}

	}

	return(0);
}
