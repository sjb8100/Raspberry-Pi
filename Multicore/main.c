#include <stdbool.h>		// C standard needed for bool
#include <stdint.h>			// C standard for uint8_t, uint16_t, uint32_t etc
#include <stdio.h>			// Needed for printf
#include <stdlib.h>			// Needed for rand
#include "rpi-smartstart.h"
#include "rpi-Hardware.h"

/*-Enable_Interrupts---------------------------------------------------------
 Self explanatory enables ARM core processor interrupts
 --------------------------------------------------------------------------*/
void Enable_Interrupts (void) {
	asm("mrs     r0, cpsr		\n\t"
		"bic     r0, r0, #0x80	\n\t"
		"msr     cpsr_c, r0");
}




static int idx = 0;
static int core = 0;
void somerand(void)
{
    idx++;
	printf("idx = %d call by core:%d\n", idx, core+1);
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


#define CORE1_MAILBOX ((volatile __attribute__((aligned(4))) uint32_t*) (0x4000009C))
#define CORE2_MAILBOX ((volatile __attribute__((aligned(4))) uint32_t*) (0x400000AC))
#define CORE3_MAILBOX ((volatile __attribute__((aligned(4))) uint32_t*) (0x400000BC))

/*-C_Irq_Handler------------------------------------------------------------
 Our interrupt we will handle in C
 --------------------------------------------------------------------------*/
void __attribute__((interrupt("IRQ"))) c_irq_handler (void) {

	static int lit = 0;

	/* Clear the ARM Timer interrupt - it's the only interrupt we have
	enabled, so we want don't have to work out which interrupt source
	caused us to interrupt */
	ARMTIMER->Clear = 0;				// Write any value to register to clear irq ... PAGE 198
	

	/* Flip the LED */
	if (lit) {
		RPI_Activity_Led(0);			// Turn Led off
		lit = 0;
		
	}
	else {
		RPI_Activity_Led(1);			// Turn LED on
		lit = 1;

		core = rand() % 3;
		switch (core) {
			case 0:
				*CORE1_MAILBOX = (uintptr_t)&somerand;
				break;
			case 1:
				*CORE2_MAILBOX = (uintptr_t)&somerand;
				break;
			case 2:
				*CORE3_MAILBOX = (uintptr_t)&somerand;
				break;
		}

	}
}

int main (void) {
	RPI_InitGraph(1280, 1024, 32);

	printf("\n\nRunning\n");

	volatile int i = 0;
	while (i < 100000) i++;   // My printf is not re-entrant so small delay
	*CORE1_MAILBOX = (uintptr_t)&marco;
	i = 0;
	while (i < 100000) i++;   // My printf is not re-entrant so small delay
	*CORE2_MAILBOX = (uintptr_t)&polo;
	i = 0;
	while (i < 100000) i++;   // My printf is not re-entrant so small delay
	*CORE3_MAILBOX = (uintptr_t)&caught;
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
    Enable_Interrupts();

	
	while (1) {

	}

	return(0);
}