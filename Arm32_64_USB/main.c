#include <stdbool.h>		// C standard needed for bool
#include <stdint.h>			// C standard for uint8_t, uint16_t, uint32_t etc
#include "rpi-smartstart.h"
#include "emb-stdio.h"
#include "rpi-usb.h"

static bool lit = false;
void c_irq_handler (void) {
	if (lit) lit = false; else lit = true;							// Flip lit flag
	set_Activity_LED(lit);											// Turn LED on/off as per new flag
	ClearTimerIrq();												// Clear the timer interrupt
}

/***************************************************************************}
{		 		    PUBLIC STRUCTURE DEFINITIONS				            }
****************************************************************************/
int main (void) {
	Init_EmbStdio(Embedded_Console_WriteChar);						// Initialize embedded stdio
	PiConsole_Init(0, 0, 0, printf);								// Auto resolution console, message to screen
	displaySmartStart(printf);										// Display smart start details
	ARM_setmaxspeed(printf);										// ARM CPU to max speed

	TimerIrqSetup(500000, c_irq_handler);
	EnableInterrupts();

	/* Initialize USB system we will want keyboard and mouse */
	UsbInitialise();

	printf("\n");
	UsbShowTree(UsbGetRootHub(), 1, '+');
	printf("\n");

	while (1) {

	}

	return(0);
}

