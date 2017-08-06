#include <stdbool.h>		// C standard needed for bool
#include <stdint.h>			// C standard for uint8_t, uint16_t, uint32_t etc
#include <stdlib.h>			// Needed for rand
#include "rpi-smartstart.h"
#include "rpi-BasicHardware.h"
#include "printf.h"

static int idx = 0;
static int core = 0;
void somerand(void)
{
    idx++;
	printf("idx = %d call by core:%d\n", idx, core);
}

void marco(void)
{
     printf("Core 1 says marco\n");
}

void polo(void)
{
     printf("Core 2 says polo\n");
}

void caught(void)
{
     printf("Core 3 says caught\n");
}


static bool lit = false;
void c_irq_handler (void) {
	if (lit) lit = false; else lit = true;							// Flip lit flag
	set_Activity_LED(lit);											// Turn LED on/off as per new flag
	if (lit) {
		core = (rand() % 3) + 1;
		CoreExecute(core, somerand);
	}
}

void c_irq_identify_and_clear_source (void) {
	/* Clear the ARM Timer interrupt - it's the only interrupt we have enabled, 
	   so we want don't have to work out which interrupt source caused us to interrupt */
	ARMTIMER->Clear = 1;											// Write any value to register to clear irq ... PAGE 198

	/* As we are running nested interrupts we must clear the Pi Irq controller,
	   the timer irq pending is bit 0 of pending register 1 as it's irq 0 */
	IRQ->IRQPending1 &= ~0x1;										// Clear timer pending irq bit 0
}

CORECALLFUNC test;

int main (void) {

	PiConsole_Init(1280, 1024, 16);
	printf("SmartStart compiled for Arm%d, AARCH%d with %d core s/w support\n",
		RPi_CompileMode.CodeType, RPi_CompileMode.AArchMode * 32 + 32,
		RPi_CompileMode.CoresSupported);							// Write text
	printf("Detected %s CPU, part id: 0x%03X, Cores made ready for use: %d\n",
		RPi_CpuIdString(), RPi_CpuId.PartNumber, RPi_CoresReady);	// Write text
	printf("Pi IO base address %08X\n", RPi_IO_Base_Addr);			// Write text
	printf("Pi booted from address %08X\n", RPi_BootAddr);			// Write text

	volatile int i = 0;
	while (i < 100000) i++;   // My printf is not re-entrant so small delay
	CoreExecute(1, marco);
	i = 0;
	while (i < 100000) i++;   // My printf is not re-entrant so small delay
	CoreExecute(2, polo);
	i = 0;
	while (i < 100000) i++;   // My printf is not re-entrant so small delay
	CoreExecute(3, caught);
	i = 0;
	while (i < 100000) i++;   // My printf is not re-entrant so small delay


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

	}

	return(0);
}