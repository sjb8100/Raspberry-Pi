#include <stdbool.h>		// C standard needed for bool
#include <stdint.h>			// C standard for uint8_t, uint16_t, uint32_t etc
#include <stdlib.h>			// Needed for rand
#include "SmartStart/rpi-SmartStart.h"
#include "SmartStart/emb-stdio.h"

void core1_main (void) {
	while (1) {
		set_Activity_LED(true);
		for (int i = 0; i < 1000000; i++){ asm("nop"); };
		set_Activity_LED(false);
		for (int i = 0; i < 1000000; i++) { asm("nop"); };
	}

}

static const char Spin[4] = { '|', '/', '-', '\\' };

int main (void) {
	Init_EmbStdio(Embedded_Console_WriteChar);						// Initialize embedded stdio
	PiConsole_Init(0, 0, 0, printf);								// Auto resolution console, message to screen
	displaySmartStart(printf);										// Display smart start details
	ARM_setmaxspeed(printf);										// ARM CPU to max speed no message to screen

	printf("okay bringing core1 online to start flashing LED\n");
	// So start core1 at 0x80000 .. AKA your start
	asm("mov	x1, #0xe0\n"\
		"mov	x2, #0x80000\n" \
		"str	x2, [x1]\n"\
		"sev");

	
	int i = 0;
	while (1) {
		printf("Deadloop %c\r", Spin[i]);
		timer_wait(50000);
		i++;
		i %= 4;
	}

	return(0);
}
