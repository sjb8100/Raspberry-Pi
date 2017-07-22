#include "rpi-Hardware.h"

/***************************************************************************}
{					      PUBLIC INTERFACE ROUTINES			                }
****************************************************************************/

/*--------------------------------------------------------------------------}
{						   PUBLIC GPIO ROUTINES								}
{--------------------------------------------------------------------------*/

/*-[gpio_setup]-------------------------------------------------------------}
 Given a valid GPIO port number and mode sets GPIO to given mode
 RETURN: true for success, false for any failure
 30Jun17 LdB
---------------------------------------------------------------------------*/
bool gpio_setup (int gpio, GPIOMODE mode) {
	if (gpio < 0 || gpio > 54) return false;						// Check GPIO pin number valid, return false if invalid
	if (mode < 0 || mode > FS_ALTFUNC3) return false;				// Check requested mode is valid, return false if invalid
	uint32_t bit = 1 << ((gpio % 10) * 3);							// Create bit mask
	uint32_t mem = GPIO->GPFSEL[gpio / 10];							// Read register
	mem &= ~(7 << bit);												// Clear GPIO mode bits for that port
	mem |= (mode << bit);											// Logical OR GPIO mode bits
	GPIO->GPFSEL[gpio / 10] = mem;									// Write value to register
	return true;													// Return true
}

/*-[gpio_output]------------------------------------------------------------}
 Given a valid GPIO port number the output is set high(true) or Low (false)
 RETURN: true for success, false for any failure
 30Jun17 LdB
---------------------------------------------------------------------------*/
bool gpio_output (int gpio, bool on) {
	if (gpio < 0 || gpio > 54) return false;						// Check GPIO pin number valid, return false if invalid
	uint32_t bit = 1 << (gpio % 32);								// Create mask bit
	if (on) {														// ON request
		GPIO->GPSET[gpio / 32] = bit;								// Set bit to make GPIO high output
	} else {
		GPIO->GPCLR[gpio / 32] = bit;								// Set bit to make GPIO low output
	}
	return true;													// Return true
}

/*-[gpio_input]-------------------------------------------------------------}
 Reads the actual level of the GPIO port number
 RETURN: true = GPIO input high, false = GPIO input low
 30Jun17 LdB
---------------------------------------------------------------------------*/
bool gpio_input (int gpio) {
	if (gpio < 0 || gpio > 54) return false;						// Check GPIO pin number valid, return false if invalid
	uint32_t bit = 1 << (gpio % 32);								// Create mask bit
	uint32_t mem = GPIO->GPLEV[gpio / 32];							// Read port level
	if (mem & bit) return true;										// Return true if bit set
	return false;													// Return false
}

/*-[gpio_checkEvent]-------------------------------------------------------}
 Checks the given GPIO port number for an event/irq flag.
 RETURN: true for event occured, false for no event
 30Jun17 LdB
--------------------------------------------------------------------------*/
bool gpio_checkEvent (int gpio) {
	if (gpio < 0 || gpio > 54) return false;						// Check GPIO pin number valid, return false if invalid
	uint32_t bit = 1 << (gpio % 32);								// Create mask bit
	uint32_t mem = GPIO->GPEDS[gpio / 32];							// Read event detect status register
	if (mem & bit) return true;										// Return true if bit set
	return false;													// Return false
}

/*-[gpio_clearEvent]-------------------------------------------------------}
 Clears the given GPIO port number event/irq flag.
 RETURN: true for success, false for any failure
 30Jun17 LdB
--------------------------------------------------------------------------*/
bool gpio_clearEvent (int gpio) {
	if (gpio < 0 || gpio > 54) return false;						// Check GPIO pin number valid, return false if invalid
	uint32_t bit = 1 << (gpio % 32);								// Create mask bit
	GPIO->GPEDS[gpio / 32] = bit;									// Clear the event from GPIO register
	return true;													// Return true
}

/*-[gpio_edgeDetect]-------------------------------------------------------}
 Sets GPIO port number edge detection to lifting/falling in Async/Sync mode
 RETURN: true for success, false for any failure
 30Jun17 LdB
--------------------------------------------------------------------------*/
bool gpio_edgeDetect (int gpio, bool lifting, bool Async) {
	if (gpio < 0 || gpio > 54) return false;						// Check GPIO pin number valid, return false if invalid
	uint32_t bit = 1 << (gpio % 32);								// Create mask bit
	if (lifting) {													// Lifting edge detect
		if (Async) GPIO->GPAREN[gpio / 32] = bit;					// Asynchronous lifting edge detect register bit set
			else GPIO->GPREN[gpio / 32] = bit;						// Synchronous lifting edge detect register bit set
	} else {														// Falling edge detect
		if (Async) GPIO->GPAFEN[gpio / 32] = bit;					// Asynchronous falling edge detect register bit set
			else GPIO->GPFEN[gpio / 32] = bit;						// Synchronous falling edge detect register bit set
	}
	return true;													// Return true
}

/*-[gpio_fixResistor]------------------------------------------------------}
 Set the GPIO port number with fix resistors to pull up/pull down.
 RETURN: true for success, false for any failure
 30Jun17 LdB
--------------------------------------------------------------------------*/
bool gpio_fixResistor (int gpio, GPIO_FIX_RESISTOR resistor) {
	uint64_t endTime;
	if (gpio < 0 || gpio > 54) return false;						// Check GPIO pin number valid, return false if invalid
	if (resistor < 0 || resistor > PULLDOWN) return false;			// Check requested resistor is valid, return false if invalid
	GPIO->GPPUD = resistor;											// Set fixed resistor request to PUD register
	endTime = timer_getTickCount() + 2;								// We want a 2 usec delay					
	while (timer_getTickCount() < endTime) {}						// Wait for the timeout
	uint32_t bit = 1 << (gpio % 32);								// Create mask bit
	GPIO->GPPUDCLK[gpio / 32] = bit;								// Set the PUD clock bit register
	endTime = timer_getTickCount() + 2;								// We want a 2 usec delay					
	while (timer_getTickCount() < endTime) {}						// Wait for the timeout
	GPIO->GPPUD = 0;												// Clear GPIO resister setting
	GPIO->GPPUDCLK[gpio / 32] = 0;									// Clear PUDCLK from GPIO
	return true;													// Return true
}

/*--------------------------------------------------------------------------}
{						   PUBLIC TIMER ROUTINES							}
{--------------------------------------------------------------------------*/

/*-[timer_getTickCount]-----------------------------------------------------}
 Get 1Mhz ARM system timer tick count in full 64 bit.
 The timer read is as per the Broadcom specification of two 32bit reads
 RETURN: tickcount value as an unsigned 64bit value
 30Jun17 LdB
---------------------------------------------------------------------------*/
uint64_t timer_getTickCount (void) {
	uint64_t resVal;
	uint32_t lowCount;
	do {
		resVal = SYSTEMTIMER->TimerHi; 								// Read Arm system timer high count
		lowCount = SYSTEMTIMER->TimerLo;							// Read Arm system timer low count
	} while (resVal != (uint64_t)SYSTEMTIMER->TimerHi);				// Check hi counter hasn't rolled in that time
	resVal = (uint64_t)resVal << 32 | lowCount;						// Join the 32 bit values to a full 64 bit
	return(resVal);													// Return the uint64_t timer tick count
}

