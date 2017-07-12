#include <stdbool.h>		// C standard needed for bool
#include <stdint.h>			// C standard for uint8_t, uint16_t, uint32_t etc
#include <string.h>
#include <stdlib.h>
#include <stdio.h>				// Needed for printf
#include "rpi-smartstart.h"
#include "usb.h"

int main (void) {
	printf("Pi Boot Address was: %8.8lX\r\n", RPi_BootAddr);
	printf("Pi Boot Mode was: %8.8lX\r\n", RPi_CPUBootMode);

	uint32_t result1, result2;
	if (RPI_MailtagExchange8(&result1, &result2, RPI_FIRMWARE_GET_MAX_CLOCK_RATE, TAG_CLOCK_ARM, 0)) {
		printf("Clock ID: %lu\r\n", result1);
		printf("Maximum ARM Clock Rate: %luHz\r\n", result2);
		if (RPI_MailtagExchange12(&result1, &result2, RPI_FIRMWARE_SET_CLOCK_RATE, TAG_CLOCK_ARM, result2, 1)) {
			printf("ARM Clock Rate set to: %luHz\r\n", result2);
		} else printf("Set max clock failed\n");
	} else printf("Get max clock failed\n");

	/* Initialize USB system we will want keyboard and mouse */
	UsbInitialise();

	printf("\n");
	UsbShowTree(UsbGetRootHub(), 1, '+');
	printf("\n");

	uint32_t x, y;
	RPI_GraphWhereXY(&x, &y);
	uint8_t buf[128];
	uint8_t firstMouse = 0;
	for (int i = 1; i <= MaximumDevices; i++) {
		if (IsMouse(i)) {
			firstMouse = i;
			break;
		}
	}


	while (1) {
		RPI_Activity_Led(1);			// Turn LED on
		RPI_WaitMicroSeconds(500000);	// 0.5 sec delay
		RPI_Activity_Led(0);			// Turn Led off
		RPI_WaitMicroSeconds(500000);   // 0.5 sec delay

		// Read first mouse, default Input report ... 4 bytes to buf
		if ((firstMouse != 0) && (HIDReadReport(firstMouse, 0, (uint16_t)USB_HID_REPORT_TYPE_INPUT << 8 | 0, &buf[0], 4) == OK)) {
			RPI_GraphGotoXY(x, y);
			RPI_ClearArea(x, y, x + 600, y + BitFontHt, 0x0);
			LOG("HID MOUSE REPORT: Buttons: 0x%02x  X move: 0x%02x, Y move: 0x%02x, Wheel: 0x%02x\n",
				buf[0], buf[1], buf[2], buf[3]);
		}

	}

	return(0);
}
