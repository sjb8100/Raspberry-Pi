#include <stdbool.h>							// Needed for bool and true/false
#include <stdint.h>								// Needed for uint8_t, uint32_t, uint64_t etc
#include "rpi-BasicHardware.h"					// This units header
#include <string.h>

/***************************************************************************}
{        PRIVATE INTERNAL RASPBERRY PI REGISTER STRUCTURE CHECKS            }
****************************************************************************/

/*--------------------------------------------------------------------------}
{					 INTERNAL STRUCTURE COMPILE TIME CHECKS		            }
{--------------------------------------------------------------------------*/
/* GIVEN THE AMOUNT OF PRECISE PACKING OF THESE STRUCTURES .. IT'S PRUDENT */
/* TO CHECK THEM AT COMPILE TIME. USE IS POINTLESS IF THE SIZES ARE WRONG. */
/*-------------------------------------------------------------------------*/
/* If you have never seen compile time assertions it's worth google search */
/* on "Compile Time Assertions". It is part of the C11++ specification and */
/* all compilers that support the standard will have them (GCC, MSC inc)   */
/*-------------------------------------------------------------------------*/
#include <assert.h>								// Need for compile time static_assert

/* Check the main register section group sizes */
static_assert(sizeof(struct BSCRegisters) == 0x20, "Register/Structure should be 0x20 bytes in size");
static_assert(sizeof(struct GPIORegisters) == 0xA0, "Register/Structure should be 0xA0 bytes in size");
static_assert(sizeof(struct SystemTimerRegisters) == 0x1C, "Register/Structure should be 0x1C bytes in size");
static_assert(sizeof(struct IrqControlRegisters) == 0x28, "Register/Structure should be 0x28 bytes in size");
static_assert(sizeof(struct ArmTimerRegisters) == 0x1C, "Register/Structure should be 0x1C bytes in size");

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
	if (mode < 0 || mode > ALTFUNC3) return false;					// Check requested mode is valid, return false if invalid
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
bool gpio_output(int gpio, bool on) {
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
	while (timer_getTickCount() < endTime) { }						// Wait for the timeout
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
 --------------------------------------------------------------------------*/
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

/*-[timer_Wait]-------------------------------------------------------------}
 This will simply wait the requested number of microseconds before return.
 02Jul17 LdB
 --------------------------------------------------------------------------*/
void timer_wait (uint64_t us) {
	us += timer_getTickCount();										// Add current tickcount onto delay
	while (timer_getTickCount() < us) {};							// Loop on timeout function until timeout
}

/*--------------------------------------------------------------------------}
{						    PI MAILBOX ROUTINES								}
{--------------------------------------------------------------------------*/

#define MAIL_EMPTY	0x40000000		/* Mailbox Status Register: Mailbox Empty */
#define MAIL_FULL	0x80000000		/* Mailbox Status Register: Mailbox Full  */

/*-[mailbox_write]----------------------------------------------------------}
 This will execute the sending of the given data block message thru the
 mailbox system on the given channel.
 RETURN: True for success, False for failure.
 04Jul17 LdB
 --------------------------------------------------------------------------*/
bool mailbox_write (MAILBOX_CHANNEL channel, uint32_t message) {
	uint32_t value;													// Temporary read value
	if (channel > MB_CHANNEL_GPU)  return false;					// Channel error
	message &= ~(0xF);												// Make sure 4 low channel bits are clear 
	message |= channel;												// OR the channel bits to the value							
	do {
		value = MAILBOX->Status1;									// Read mailbox1 status from GPU	
	} while ((value & MAIL_FULL) != 0);								// Make sure arm mailbox is not full
	MAILBOX->Write1 = message;										// Write value to mailbox
	return true;													// Write success
}

/*-[mailbox_read]-----------------------------------------------------------}
 This will read any pending data on the mailbox system on the given channel.
 RETURN: The read value for success, 0xFEEDDEAD for failure.
 04Jul17 LdB
 --------------------------------------------------------------------------*/
uint32_t mailbox_read (MAILBOX_CHANNEL channel) {
	uint32_t value;													// Temporary read value
	if (channel > MB_CHANNEL_GPU)  return 0xFEEDDEAD;				// Channel error
	do {
		do {
			value = MAILBOX->Status0;								// Read mailbox0 status
		} while ((value & MAIL_EMPTY) != 0);						// Wait for data in mailbox
		value = MAILBOX->Read0;										// Read the mailbox	
	} while ((value & 0xF) != channel);								// We have response back
	value &= ~(0xF);												// Lower 4 low channel bits are not part of message
	return value;													// Return the value
}

uint32_t mailbox_ARM_to_VC (void* ptr) {
	return ((uint64_t)ptr | 0xC0000000);
}

uint32_t mailbox_VC_to_ARM (uint32_t ptr) {
	return (ptr & (~0xC0000000));
}


/*-WriteChar-----------------------------------------------------------------
Draws given BitFont character in the colour specified starting at (X1,Y1)
This can be done better ... just right for now LdB
25Nov16 LdB
--------------------------------------------------------------------------*/
void WriteChar32 (FRAMEBUFFER* Fb, int X1, int Y1, char Ch) {
	uint32_t* video_wr_ptr = (uint32_t*)(intptr_t)(Fb->buffer + (Y1 * Fb->width * 4) + (X1 * 4));
	uint32_t wr_ptr_yoffs = 0;
	int fu32pc = (Fb->fontHt * Fb->fontWth) / 32;					// Font uin32_t per character
	for (int y = 0; y < (32/Fb->fontWth); y++) {
		uint32_t b = Fb->bitfont[(Ch * fu32pc) + y];	
		for (int i = 0; i < 32; i++) {
			uint32_t col;
			int xoffs = i % Fb->fontWth;
			if ((b & 0x80000000) != 0) col = Fb->TxtColor;
				else col = Fb->BkColor;
			video_wr_ptr[wr_ptr_yoffs + xoffs] = col; 
			b <<= 1;
			if (xoffs == Fb->fontWth-1) wr_ptr_yoffs += Fb->width;
		}
	}
}

/*-WriteText-----------------------------------------------------------------
Draws given string in BitFont Characters in the colour specified starting at
(X,Y) on the screen. It just redirects each character write to WriteChar.
25Nov16 LdB
--------------------------------------------------------------------------*/
void WriteText (int X, int Y, char* Txt, FRAMEBUFFER* Fb) {
	if (Txt) {														// Check pointer valid
		size_t count = strlen(Txt);									// Fetch string length
		while (count) {												// For each character
			Fb->WriteChar(Fb, X, Y, Txt[0]);						// Write the character
			count--;												// Decrement count
			Txt++;													// Next text character
			X += Fb->fontWth;										// Advance x text position
		}
	}
}

#include "Font8x16.h"
bool allocFrameBuffer (int width, int height, int depth, FRAMEBUFFER* fb) {
	uint32_t __attribute__((aligned(16))) mailbox_message[22];
	if (!fb) return false;											// No framebuffer provided fail out
	mailbox_message[0] = sizeof(mailbox_message);
	mailbox_message[1] = 0;

	mailbox_message[2] = MAILBOX_TAG_SET_PHYSICAL_WIDTH_HEIGHT;
	mailbox_message[3] = 8;
	mailbox_message[4] = 8;
	mailbox_message[5] = width;
	mailbox_message[6] = height;

	mailbox_message[7] = MAILBOX_TAG_SET_VIRTUAL_WIDTH_HEIGHT;
	mailbox_message[8] = 8;
	mailbox_message[9] = 8;
	mailbox_message[10] = width;
	mailbox_message[11] = height;

	mailbox_message[12] = MAILBOX_TAG_SET_COLOUR_DEPTH;
	mailbox_message[13] = 4;
	mailbox_message[14] = 4;
	mailbox_message[15] = depth;

	mailbox_message[16] = MAILBOX_TAG_ALLOCATE_FRAMEBUFFER;
	mailbox_message[17] = 8;
	mailbox_message[18] = 4;
	mailbox_message[19] = 16;
	mailbox_message[20] = 0;

	mailbox_message[21] = 0;

	mailbox_write(MB_CHANNEL_TAGS, mailbox_ARM_to_VC(&mailbox_message[0]));
	mailbox_read(MB_CHANNEL_TAGS);

	fb->buffer = mailbox_VC_to_ARM(mailbox_message[19]);
	fb->width = width;
	fb->height = height;
	fb->depth = depth;
	fb->bitfont = &BitFont[0];
	fb->fontWth = 8;
	fb->fontHt = 16;


	fb->TxtColor = 0xFFFFFFFF;
	fb->BkColor = 0x00000000;

	fb->clipMinX = 0;
	fb->clipMaxX = width;
	fb->clipMinY = 0;
	fb->clipMaxY = height;

	fb->WriteChar = WriteChar32;

	return true;
}



