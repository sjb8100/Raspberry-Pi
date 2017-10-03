#include <stdbool.h>			// Neede for bool
#include <stdint.h>				// Needed for uint32_t, uint16_t etc
#include <string.h>				// Needed for memcpy
#include <stdlib.h>
#include "rpi-smartstart.h"		// Needed for smart start API 
#include "emb-stdio.h"			// Needed for printf
#include "rpi-usb.h"


static bool lit = false;
void c_irq_handler(void) {
	if (lit) lit = false; else lit = true;							// Flip lit flag
	set_Activity_LED(lit);											// Turn LED on/off as per new flag
}


int main (void) {
	PiConsole_Init(0, 0, 0, printf);								// Auto resolution console, no message to screen
	displaySmartStart(printf);										// Display smart start details
	ARM_setmaxspeed(printf);										// ARM CPU to max speed no message to screen
	TimerIrqSetup(500000, c_irq_handler);							// Give me flashing LED so I can tell if I have locked irq pipe up 
	EnableInterrupts();												// Start interrupts rolling

	/* Initialize USB system we will want keyboard and mouse */
	UsbInitialise();

	printf("\n");
	UsbShowTree(UsbGetRootHub(), 1, '+');
	printf("\n");

	while (1){

    }

	return(0);
}
