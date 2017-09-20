#include <stdbool.h>		// C standard needed for bool
#include <stdint.h>			// C standard for uint8_t, uint16_t, uint32_t etc
#include "emb-stdio.h"		// Needed for printf
#include "rpi-smartstart.h"		


static bool lit = false;
void c_irq_handler(void) {
	if (lit) lit = false; else lit = true;							// Flip lit flag
	set_Activity_LED(lit);											// Turn LED on/off as per new flag
}



static const char Spin[4] = { '|', '/', '-', '\\' };
static int i = 0;
int main (void) {
	PiConsole_Init(0, 0, 0, &printf);								// Auto resolution console, show resolution to screen
	displaySmartStart(&printf);										// Display smart start details
	ARM_setmaxspeed(&printf);										// ARM CPU to max speed and confirm to screen

	/* Setup irq function and period between irq's 500000 us */
	TimerIrqSetup(500000, c_irq_handler);

	/* Enable interrupts! */
	EnableInterrupts();


	while (1) {
		printf("Deadloop %c\r", Spin[i]);
		timer_wait(50000);
		i++;
		i %= 4;
	}

	return(0);
}