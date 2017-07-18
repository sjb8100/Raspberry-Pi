#include <stdbool.h>		// C standard needed for bool
#include <stdint.h>			// C standard for uint8_t, uint16_t, uint32_t etc
#include <stdio.h>				// Needed for printf
#include "rpi-BasicHardware.h"
FRAMEBUFFER fb;							// Framebuffer variable

void set_LED(bool on) {
	uint32_t __attribute__((aligned(16))) mailbox_message[8];
	mailbox_message[0] = sizeof(mailbox_message);
	mailbox_message[1] = 0;
	mailbox_message[2] = 0x38041;
	mailbox_message[3] = 8;
	mailbox_message[4] = 8;
	mailbox_message[5] = 130;
	mailbox_message[6] = (uint32_t)on;
	mailbox_message[7] = 0;
	mailbox_write(MB_CHANNEL_TAGS, mailbox_ARM_to_VC(&mailbox_message[0]));
	mailbox_read(MB_CHANNEL_TAGS);
}

static int lit = 0;
void c_irq_handler (void)
{


	/* Clear the ARM Timer interrupt - it's the only interrupt we have
	enabled, so we want don't have to work out which interrupt source
	caused us to interrupt */
	ARMTIMER->Clear = 0;				// Write any value to register to clear irq ... PAGE 198

										/* Flip the LED */
	if (lit) {
		set_LED(false);					// Turn Led off
		lit = 0;
	}
	else {
		set_LED(true);					// Turn LED on
		lit = 1;
	}

}

int main (void) {
	allocFrameBuffer(800, 600, 32, &fb);							// Allocate a framebuffer
	WriteText(100, 100, "Setting up Interrupts", &fb);				// Write text
																	/* Enable the timer interrupt IRQ */
	IRQ->EnableBasicIRQs.Enable_Timer_IRQ = true;


	/* Setup the system timer interrupt */
	ARMTIMER->Load = 0x400;

	/* Setup the ARM Timer */
	ARMTIMER->Control.Counter32Bit = true;
	ARMTIMER->Control.Prescale = Clkdiv256;
	ARMTIMER->Control.TimerIrqEnable = true;
	ARMTIMER->Control.TimerEnable = true;

	WriteText(100, 120, "Setup complete", &fb);						// Write text

	/* Enable interrupts to IRQ */
	asm("msr daifclr,#2");

	while (1) {

		if (lit) WriteText(100, 160, "LED on ", &fb);				// Write text
			else WriteText(100, 160, "LED off", &fb);				// Write text
	}

	return(0);
}

