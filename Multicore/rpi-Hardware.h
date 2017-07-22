#ifndef _RPI_HARDWARE_							// Check RPI_HARDWARE guard
#define _RPI_HARDWARE_

#ifdef __cplusplus								// If we are including to a C++
extern "C" {									// Put extern C directive wrapper around
#endif

#if (__STDC_VERSION__ >= 201112L)					// it is c11, static_assert is defined when assert.h is included
#include <assert.h>								// Needed for STATIC_ASSERT										
#endif
#include <stdbool.h>							// Needed for bool and true/false
#include <stdint.h>								// Needed for uint8_t, uint32_t, etc
#include "rpi-smartstart.h"						// Needed for RPi_IO_Base_Addr 

/***************************************************************************}
{					     PUBLIC ENUMERATION CONSTANTS			            }
****************************************************************************/

/*--------------------------------------------------------------------------}
;{	      ENUMERATED FSEL REGISTERS ... BCM2835.PDF MANUAL see page 92		}
;{-------------------------------------------------------------------------*/
/* In binary so any error is obvious */
typedef enum {
	FS_INPUT = 0b000,			// 0
	FS_OUTPUT = 0b001,			// 1
	FS_ALTFUNC0 = 0b100,		// 4
	FS_ALTFUNC1 = 0b101,		// 5
	FS_ALTFUNC2 = 0b110,		// 6
	FS_ALTFUNC3 = 0b111,		// 7
	FS_ALTFUNC4 = 0b011,		// 3
	FS_ALTFUNC5 = 0b010,		// 2
} GPIOMODE;

/*--------------------------------------------------------------------------}
;{	    ENUMERATED GPIO FIX RESISTOR ... BCM2835.PDF MANUAL see page 101	}
;{-------------------------------------------------------------------------*/
/* In binary so any error is obvious */
typedef enum {
	NO_RESISTOR = 0b00,			// 0
	PULLUP = 0b01,				// 1
	PULLDOWN = 0b10,			// 2
} GPIO_FIX_RESISTOR;

/*--------------------------------------------------------------------------}
{	ENUMERATED TIMER CONTROL PRESCALE ... BCM2835.PDF MANUAL see page 197	}
{--------------------------------------------------------------------------*/
/* In binary so any error is obvious */
typedef enum {
	Clkdiv1 = 0b00,				// 0
	Clkdiv16 = 0b01,			// 1
	Clkdiv256 = 0b10,			// 2
	Clkdiv_undefined = 0b11,	// 3 
} TIMER_PRESCALE;

/***************************************************************************}
{		 	      PUBLIC REGISTER DEFINITION STRUCTURES			            }
****************************************************************************/

/*==========================================================================}
{			     INDIVIDUAL HARDWARE REGISTER DEFINITIONS		            }
===========================================================================*/

/*--------------------------------------------------------------------------}
{ 	  IRQ BASIC PENDING (READ-ONLY ) REGISTER - BCM2835.PDF page 113/114	}
{--------------------------------------------------------------------------*/
struct __attribute__((__packed__, aligned(4))) IrqBasicPendingReg {
	union {
		struct __attribute__((__packed__, aligned(1))) {
			const volatile bool Timer_IRQ_pending : 1;				// @0 Timer Irq pending
			const volatile bool Mailbox_IRQ_pending : 1;			// @1 Mailbox Irq pending
			const volatile bool Doorbell0_IRQ_pending : 1;			// @2 Arm Doorbell0 Irq pending
			const volatile bool Doorbell1_IRQ_pending : 1;			// @3 Arm Doorbell0 Irq pending
			const volatile bool GPU0_halted_IRQ_pending : 1;		// @4 GPU0 halted IRQ pending
			const volatile bool GPU1_halted_IRQ_pending : 1;		// @5 GPU1 halted IRQ pending
			const volatile bool Illegal_access_type1_pending : 1;	// @6 Illegal access type 1 IRQ pending
			const volatile bool Illegal_access_type0_pending : 1;	// @7 Illegal access type 0 IRQ pending
			const volatile bool Bits_set_in_pending_register_1 : 1;	// @8 One or more bits set in pending register 1
			const volatile bool Bits_set_in_pending_register_2 : 1;	// @9 One or more bits set in pending register 2
			const volatile bool GPU_IRQ_7_pending : 1;				// @10 GPU irq 7 pending
			const volatile bool GPU_IRQ_9_pending : 1;				// @11 GPU irq 9 pending
			const volatile bool GPU_IRQ_10_pending : 1;				// @12 GPU irq 10 pending
			const volatile bool GPU_IRQ_18_pending : 1;				// @13 GPU irq 18 pending
			const volatile bool GPU_IRQ_19_pending : 1;				// @14 GPU irq 19 pending
			const volatile bool GPU_IRQ_53_pending : 1;				// @15 GPU irq 53 pending
			const volatile bool GPU_IRQ_54_pending : 1;				// @16 GPU irq 54 pending
			const volatile bool GPU_IRQ_55_pending : 1;				// @17 GPU irq 55 pending
			const volatile bool GPU_IRQ_56_pending : 1;				// @18 GPU irq 56 pending
			const volatile bool GPU_IRQ_57_pending : 1;				// @19 GPU irq 57 pending
			const volatile bool GPU_IRQ_62_pending : 1;				// @20 GPU irq 62 pending
			unsigned reserved : 10;									// @21-31 reserved
		};
		const volatile uint32_t __attribute__((aligned(4))) Raw32;	// Union to access all 32 bits as a uint32_t
	};
};

/*--------------------------------------------------------------------------}
{				  FIQ CONTROL REGISTER - BCM2835.PDF page 116				}
{--------------------------------------------------------------------------*/
struct __attribute__((__packed__, aligned(4))) FiqControlReg {
	union {
		struct __attribute__((__packed__, aligned(1))) {
			volatile unsigned SelectFIQSource : 7;					// @0-6 Select FIQ source
			volatile bool EnableFIQ : 1;							// @7 enable FIQ
			unsigned reserved : 24;									// @8-31 reserved
		};
		volatile uint32_t __attribute__((aligned(4))) Raw32;		// Union to access all 32 bits as a uint32_t
	};
};

/*--------------------------------------------------------------------------}
{			   ENABLE BASIC IRQ REGISTER - BCM2835.PDF page 117				}
{--------------------------------------------------------------------------*/
struct __attribute__((__packed__, aligned(4))) EnableBasicIrqReg {
	union {
		struct __attribute__((__packed__, aligned(1))) {
			volatile bool Enable_Timer_IRQ : 1;						// @0 Timer Irq enable
			volatile bool Enable_Mailbox_IRQ : 1;					// @1 Mailbox Irq enable
			volatile bool Enable_Doorbell0_IRQ : 1;					// @2 Arm Doorbell0 Irq enable
			volatile bool Enable_Doorbell1_IRQ : 1;					// @3 Arm Doorbell0 Irq enable
			volatile bool Enable_GPU0_halted_IRQ : 1;				// @4 GPU0 halted IRQ enable
			volatile bool Enable_GPU1_halted_IRQ : 1;				// @5 GPU1 halted IRQ enable
			volatile bool Enable_Illegal_access_type1 : 1;			// @6 Illegal access type 1 IRQ enable
			volatile bool Enable_Illegal_access_type0 : 1;			// @7 Illegal access type 0 IRQ enable
			unsigned reserved : 24;									// @8-31 reserved
		};
		volatile uint32_t __attribute__((aligned(4))) Raw32;		// Union to access all 32 bits as a uint32_t
	};
};

/*--------------------------------------------------------------------------}
{			 DISABLE_BASIC_IRQ REGISTER - BCM2835.PDF page 117				}
{--------------------------------------------------------------------------*/
struct __attribute__((__packed__, aligned(4))) DisableBasicIrqReg {
	union {
		struct __attribute__((__packed__, aligned(1))) {
			volatile bool Disable_Timer_IRQ : 1;					// @0 Timer Irq disable
			volatile bool Disable_Mailbox_IRQ : 1;					// @1 Mailbox Irq disable
			volatile bool Disable_Doorbell0_IRQ : 1;				// @2 Arm Doorbell0 Irq disable
			volatile bool Disable_Doorbell1_IRQ : 1;				// @3 Arm Doorbell0 Irq disable
			volatile bool Disable_GPU0_halted_IRQ : 1;				// @4 GPU0 halted IRQ disable
			volatile bool Disable_GPU1_halted_IRQ : 1;				// @5 GPU1 halted IRQ disable
			volatile bool Disable_Illegal_access_type1 : 1;			// @6 Illegal access type 1 IRQ disable
			volatile bool Disable_Illegal_access_type0 : 1;			// @7 Illegal access type 0 IRQ disable
			unsigned reserved : 24;									// @8-31 reserved
		};
		volatile uint32_t __attribute__((aligned(4))) Raw32;		// Union to access all 32 bits as a uint32_t
	};
};


/*--------------------------------------------------------------------------}
{			 SYSTEM TIMER CONTROL REGISTER BCM2835.PDF page 173				}
{--------------------------------------------------------------------------*/
struct __attribute__((__packed__, aligned(4))) SystemTimerControlReg {
	union {
		struct __attribute__((__packed__, aligned(1))) {
			volatile bool SysTimer0Match : 1;						// @0 System timer 0 match
			volatile bool SysTimer1Match : 1;						// @1 System timer 1 match
			volatile bool SysTimer2Match : 1;						// @2 System timer 2 match
			volatile bool SysTimer3Match : 1;						// @3 System timer 3 match
			unsigned reserved : 28;									// @4-31 reserved
		};
		volatile uint32_t __attribute__((aligned(4))) Raw32;		// Union to access all 32 bits as a uint32_t
	};
};


/*--------------------------------------------------------------------------}
{			  TIMER CONTROL REGISTER - BCM2835.PDF page 197					}
{--------------------------------------------------------------------------*/
struct __attribute__((__packed__, aligned(4))) TimerControlReg {
	union {
		struct __attribute__((__packed__, aligned(1))) {
			unsigned unused : 1;									// @0 Unused bit
			volatile bool Counter32Bit : 1;							// @1 Counter32 bit (16bit if false)
			volatile TIMER_PRESCALE Prescale : 2;					// @2-3 Prescale  
			unsigned unused1 : 1;									// @4 Unused bit
			volatile bool TimerIrqEnable : 1;						// @5 Timer irq enable
			unsigned unused2 : 1;									// @6 Unused bit
			volatile bool TimerEnable : 1;							// @7 Timer enable
			unsigned reserved : 24;									// @8-31 reserved 
		};
		volatile uint32_t __attribute__((aligned(4))) Raw32;		// Union to access all 32 bits as a uint32_t
	};
};

/*==========================================================================}
{		 HARDWARE REGISTERS BANKED UP IN GROUPS AS PER MANUAL SECTIONS	    }
===========================================================================*/

/*--------------------------------------------------------------------------}
{    RASPBERRY PI GPIO HARDWARE REGISTERS - BCM2835.PDF Manual Section 6	}
{--------------------------------------------------------------------------*/
struct __attribute__((__packed__, aligned(4))) GPIORegisters {
	volatile uint32_t GPFSEL[6];									// 0x00  GPFSEL0 - GPFSEL[5]
	uint32_t reserved1;												// 0x18  reserved
	volatile uint32_t GPSET[2];										// 0x1C  GPSET0 - GPSET1;
	uint32_t reserved2;												// 0x24  reserved
	volatile uint32_t GPCLR[2];										// 0x28  GPCLR0 - GPCLR1
	uint32_t reserved3;												// 0x30  reserved
	const volatile uint32_t GPLEV[2];								// 0x34  GPLEV0 - GPLEV1   ** Read only hence const
	uint32_t reserved4;												// 0x3C  reserved
	volatile uint32_t GPEDS[2];										// 0x40  GPEDS0 - GPEDS1 
	uint32_t reserved5;												// 0x48  reserved
	volatile uint32_t GPREN[2];										// 0x4C  GPREN0 - GPREN1;	 
	uint32_t reserved6;												// 0x54  reserved
	volatile uint32_t GPFEN[2];										// 0x58  GPFEN0 - GPFEN1;
	uint32_t reserved7;												// 0x60  reserved
	volatile uint32_t GPHEN[2];										// 0x64  GPHEN0 - GPHEN1;
	uint32_t reserved8;												// 0x6c  reserved
	volatile uint32_t GPLEN[2];										// 0x70  GPLEN0 - GPLEN1;
	uint32_t reserved9;												// 0x78  reserved
	volatile uint32_t GPAREN[2];									// 0x7C  GPAREN0 - GPAREN1;
	uint32_t reserved10;											// 0x84  reserved
	volatile uint32_t GPAFEN[2]; 									// 0x88  GPAFEN0 - GPAFEN1;
	uint32_t reserved11;											// 0x90  reserved
	volatile uint32_t GPPUD; 										// 0x94  GPPUD 
	volatile uint32_t GPPUDCLK[2]; 									// 0x98  GPPUDCLK0 - GPPUDCLK1;
};

/*--------------------------------------------------------------------------}
{	   RASPBERRY PI IRQ HARDWARE REGISTERS - BCM2835 Manual Section 7	    }
{--------------------------------------------------------------------------*/
struct __attribute__((__packed__, aligned(1))) IrqControlRegisters {
	const volatile struct IrqBasicPendingReg IRQBasicPending;		// 0x200   ** Read only hence const
	const volatile uint32_t IRQPending1;							// 0x204   ** Read only hence const
	const volatile uint32_t IRQPending2;							// 0x208   ** Read only hence const
	volatile struct FiqControlReg FIQControl;						// 0x20C
	volatile uint32_t EnableIRQs1;									// 0x210
	volatile uint32_t EnableIRQs2;									// 0x214
	volatile struct EnableBasicIrqReg EnableBasicIRQs;				// 0x218
	volatile uint32_t DisableIRQs1;									// 0x21C
	volatile uint32_t DisableIRQs2;									// 0x220
	volatile struct DisableBasicIrqReg DisableBasicIRQs;			// 0x224
};

/*--------------------------------------------------------------------------}
{  RASPBERRY PI SYSTEM TIMER HARDWARE REGISTERS - BCM2835 Manual Section 12	}
{--------------------------------------------------------------------------*/
struct __attribute__((__packed__, aligned(4))) SystemTimerRegisters {
	volatile struct SystemTimerControlReg Control;					// 0x00
	volatile uint32_t TimerLo;										// 0x04
	volatile uint32_t TimerHi;										// 0x08
	volatile uint32_t Compare0;										// 0x0C
	volatile uint32_t Compare1;										// 0x10
	volatile uint32_t Compare2;										// 0x14
	volatile uint32_t Compare3;										// 0x18
};

/*--------------------------------------------------------------------------}
{   RASPBERRY PI ARM TIMER HARDWARE REGISTERS - BCM2835 Manual Section 14	}
{--------------------------------------------------------------------------*/
struct __attribute__((__packed__, aligned(4))) ArmTimerRegisters {
	volatile uint32_t Load;											// 0x00
	const volatile uint32_t Value;									// 0x04  ** Read only hence const
	volatile struct TimerControlReg Control;						// 0x08
	volatile uint32_t Clear;										// 0x0C
	const volatile uint32_t RawIRQ;									// 0x10  ** Read only hence const
	const volatile uint32_t MaskedIRQ;								// 0x14  ** Read only hence const
	volatile uint32_t Reload;										// 0x18
};

/***************************************************************************}
{     PUBLIC POINTERS TO ALL OUR RASPBERRY PI REGISTER BANK STRUCTURES	    }
****************************************************************************/
#define GPIO ((volatile __attribute__((aligned(4))) struct GPIORegisters*) (RPi_IO_Base_Addr + 0x200000))
#define SYSTEMTIMER ((volatile __attribute__((aligned(4))) struct SystemTimerRegisters*)(RPi_IO_Base_Addr + 0x3000))
#define IRQ ((volatile __attribute__((aligned(4))) struct IrqControlRegisters*)(RPi_IO_Base_Addr + 0xB200))
#define ARMTIMER ((__attribute__((aligned(4))) struct  ArmTimerRegisters*)(RPi_IO_Base_Addr + 0xB400))


#if (__STDC_VERSION__ >= 201112L)					// it is c11, static_assert is defined and we can run compiletime checks
/*--------------------------------------------------------------------------}
{					 INTERNAL STRUCTURE COMPILE TIME CHECKS		            }
{--------------------------------------------------------------------------*/
/* All the register structures must match or else this code is completely  */
/* useless and so we run compile time checks on them. No code is produced  */
/* from the process here it is strictly compile time checking.             */
/*-------------------------------------------------------------------------*/
/* Check the each register is 32 bits */
_Static_assert(sizeof(struct IrqBasicPendingReg) == 0x4, "Register should be 0x4 bytes (32 bits) in size");
_Static_assert(sizeof(struct FiqControlReg) == 0x4, "Register should be 0x4 bytes (32 bits) in size");
_Static_assert(sizeof(struct EnableBasicIrqReg) == 0x4, "Register should be 0x4 bytes (32 bits) in size");
_Static_assert(sizeof(struct DisableBasicIrqReg) == 0x4, "Register should be 0x4 bytes (32 bits) in size");
_Static_assert(sizeof(struct SystemTimerControlReg) == 0x4, "Register should be 0x4 bytes (32 bits) in size");
_Static_assert(sizeof(struct TimerControlReg) == 0x4, "Register should be 0x4 bytes (32 bits) in size");

/* Check the structure group sizes */
_Static_assert(sizeof(struct GPIORegisters) == 0xA0, "Register group should be 0xA0 bytes in size");
_Static_assert(sizeof(struct IrqControlRegisters) == 0x28, "Register group should be 0x28 bytes in size");
_Static_assert(sizeof(struct SystemTimerRegisters) == 0x1C, "Register group should be 0x1C bytes in size");
_Static_assert(sizeof(struct ArmTimerRegisters) == 0x1C, "Register group should be 0x1C bytes in size");
#endif

/***************************************************************************}
{					      PUBLIC INTERFACE ROUTINES			                }
****************************************************************************/

/*--------------------------------------------------------------------------}
{						   PUBLIC TIMER ROUTINES							}
{--------------------------------------------------------------------------*/

/*-[timer_getTickCount]-----------------------------------------------------}
 Get 1Mhz ARM system timer tick count in full 64 bit.
 The timer read is as per the Broadcom specification of two 32bit reads
 RETURN: tickcount value as an unsigned 64bit value
 30Jun17 LdB
---------------------------------------------------------------------------*/
uint64_t timer_getTickCount (void);

#ifdef __cplusplus								// If we are including to a C++ file
}												// Close the extern C directive wrapper
#endif

#endif											// _RPI_HARDWARE_ Guard