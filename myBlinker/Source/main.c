#include <stdbool.h>		// C standard needed for bool
#include <stdint.h>			// C standard for uint8_t, uint16_t, uint32_t etc
#include <stdlib.h>			// Needed for rand
#include "SmartStart/rpi-SmartStart.h"
#include "SmartStart/emb-stdio.h"

static bool lit = false;
void c_irq_handler (void) {
	if (lit) lit = false; else lit = true;							// Flip lit flag
	set_Activity_LED(lit);											// Turn LED on/off as per new flag
}

static const char Spin[4] = { '|', '/', '-', '\\' };

int main (void) {
	Init_EmbStdio(Embedded_Console_WriteChar);							// Initialize embedded stdio
	PiConsole_Init(0, 0, 0, printf);								// Auto resolution console, message to screen
	displaySmartStart(printf);										// Display smart start details
	ARM_setmaxspeed(printf);										// ARM CPU to max speed no message to screen



	TimerIrqSetup(500000, c_irq_handler);							// Give me flashing LED and timer based hyperthread launch 
	EnableInterrupts();												// Start interrupts rolling



	int i = 0;
	while (1) {
		printf("Deadloop %c\r", Spin[i]);
		timer_wait(50000);
		i++;
		i %= 4;
	}

	return(0);
}
