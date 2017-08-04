#include <stdbool.h>		// C standard needed for bool
#include <stdint.h>			// C standard for uint8_t, uint16_t, uint32_t etc
#include "rpi-smartstart.h"
#include "rpi-BasicHardware.h"
#include "rpi-usb.h"
#include "printf.h"


FRAMEBUFFER fb;							// Framebuffer variable

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
	uint32_t val = IRQ->IRQPending1;								// Read the pending state
	val &= ~0x1;													// Clear bit 0
	IRQ->IRQPending1 = val;											// Write the pending back
}


int main (void) {
	allocFrameBuffer(1280, 1024, 32, &fb);							// Allocate a framebuffer
	PiConsole_Init(&fb);
	printf("SmartStart compiled for Arm%d, AARCH%d with %d core s/w support\n",
		RPi_CompileMode.CodeType, RPi_CompileMode.AArchMode * 32 + 32,
		RPi_CompileMode.CoresSupported);							// Write text
	printf("Detected %s CPU, part id: 0x%03X, revision: %01x.%01x\n",
		RPi_CpuIdString(), RPi_CpuId.PartNumber, RPi_CpuId.Variant,
		RPi_CpuId.Revision);										// Write text
	printf("Pi IO base address %08X\n", RPi_IO_Base_Addr);			// Write text
	printf("Pi booted from address %08X\n", RPi_BootAddr);			// Write text

	IRQ->EnableBasicIRQs.Enable_Timer_IRQ = true;

	/* Setup the system timer interrupt */
	ARMTIMER->Load = 0x400;

	/* Setup the ARM Timer */
	ARMTIMER->Control.Counter32Bit = true;
	ARMTIMER->Control.Prescale = Clkdiv256;
	ARMTIMER->Control.TimerIrqEnable = true;
	ARMTIMER->Control.TimerEnable = true;

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

