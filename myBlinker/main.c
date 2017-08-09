#include <stdbool.h>		// C standard needed for bool
#include <stdint.h>			// C standard for uint8_t, uint16_t, uint32_t etc
#include <stdio.h>				// Needed for printf
#include "rpi-smartstart.h"		
#include "rpi-BasicHardware.h"


static bool lit = false;
void c_irq_handler(void) {
	if (lit) lit = false; else lit = true;							// Flip lit flag
	set_Activity_LED(lit);											// Turn LED on/off as per new flag
}

void c_irq_identify_and_clear_source(void) {

	ARMTIMER->Clear = 1;											// Write any value to register to clear irq ... PAGE 198

	/* As we are running nested interrupts we must clear the Pi Irq controller,
	the timer irq pending is bit 0 of pending register 1 as it's irq 0 */
	IRQ->IRQPending1 &= ~0x1;										// Clear timer pending irq bit 0
}

static const char Spin[4] = { '|', '/', '-', '\\' };
static int i = 0;
int main (void) {
	if (PiConsole_Init(1280, 1024, 16)) {
		printf("SmartStart compiled for Arm%d, AARCH%d with %u core s/w support\n",
			RPi_CompileMode.CodeType, RPi_CompileMode.AArchMode * 32 + 32,
			(unsigned int)RPi_CompileMode.CoresSupported);							// Write text
		printf("Detected %s CPU, part id: 0x%03X, Cores made ready for use: %u\n",
			RPi_CpuIdString(), RPi_CpuId.PartNumber, (unsigned int)RPi_CoresReady);	// Write text
		printf("Pi IO base address %08X\n", (unsigned int)RPi_IO_Base_Addr);			// Write text
		printf("Pi booted from address %08X\n", (unsigned int)RPi_BootAddr);			// Write text
	}

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

	while (1) {
		printf("Deadloop %c\r", Spin[i]);
		timer_wait(50000);
		i++;
		i %= 4;
	}

	return(0);
}