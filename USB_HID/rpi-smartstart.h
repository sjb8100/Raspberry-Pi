#ifndef _SMART_START_
#define _SMART_START_

#ifdef __cplusplus								// If we are including to a C++
extern "C" {									// Put extern C directive wrapper around
#endif

#ifndef __ASSEMBLER__							// Don't include standard headers for ASSEMBLER
#include <stdbool.h>							// Needed for bool and true/false
#include <stdint.h>								// Needed for uint8_t, uint32_t, etc
#endif
/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{       Filename: rpi-smartstart.h								}
{       Copyright(c): Leon de Boer(LdB) 2017					}
{       Version: 1.02											}
{***************************************************************}
{     This code is the C wrapper around smartstart.s assembler  }
{  code which is linked as external references by this header.  }
{******************[ THIS CODE IS FREEWARE ]********************}
{																}
{     This sourcecode is released for the purpose to promote	}
{   programming on the Raspberry Pi. You may redistribute it    }
{   and/or modify with the following disclaimer.                }
{																}
{   The SOURCE CODE is distributed "AS IS" WITHOUT WARRANTIES	}
{   AS TO PERFORMANCE OF MERCHANTABILITY WHETHER EXPRESSED OR   } 
{   IMPLIED. Redistributions of source code must retain the     }
{   copyright notices.                                          }	
{																}
{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/

/***************************************************************************}
{		  PUBLIC MACROS MUCH AS WE HATE THEM SOMETIMES YOU NEED THEM        }
{***************************************************************************/

/* Most versions of C don't have _countof macro so provide it if not available */
#if !defined(_countof)
#define _countof(_Array) (sizeof(_Array) / sizeof(_Array[0])) 
#endif

/* As we are compiling for Raspberry Pi if main, winmain make them kernel_main */
#define WinMain(...) kernel_main (uint32_t r0, uint32_t r1, uint32_t atags)
#define main(...) kernel_main (uint32_t r0, uint32_t r1, uint32_t atags)

/* System font is 8 wide and 16 height so these are preset for the moment */
#define BitFontHt 16
#define BitFontWth 8

/*==========================================================================}
;{				 	 ARM CPU ID CONSTANT DEFINITIONS					    }
;{=========================================================================*/
#define ARM6_CPU_ID 0x410FB767					// CPU id a BCM2835 reports
#define ARM7_CPU_ID 0x410FC073					// CPU id a BCM2836 reports
#define ARM8_CPU_ID 0x410FD034					// CPU id a BCM2837 reports

/*==========================================================================}
;{     FSEL REGISTER FUNCTIONS AS PER Table 6-2 OF BROADCOM DATA SHEET      }
;{=========================================================================*/
#ifdef __ASSEMBLER__
/*--------------------------------------------------------------------------}
;{        ASSEMBLER VERSION OF FSEL VALUES IS A SIMPLE DEFINED VALUE        }
;{-------------------------------------------------------------------------*/
#define FS_INPUT  0x00							// GPIO port is input
#define FS_OUTPUT 0x01							// GPIO port is output
#define FS_ALT5	  0x02							// GPIO alternate mode 5
#define FS_ALT4   0x03							// GPIO alternate mode 4
#define FS_ALT0   0x04							// GPIO alternate mode 0
#define FS_ALT1   0x05							// GPIO alternate mode 1
#define FS_ALT2   0x06							// GPIO alternate mode 2
#define FS_ALT3   0x07							// GPIO alternate mode 3
#else
/*--------------------------------------------------------------------------}
;{	SAME FSEL REGISTERS ENUMERATED FOR C - PROTECTS AGAINST ILLEGAL VALUES  }
;{-------------------------------------------------------------------------*/
typedef enum {
	FS_INPUT	= 0x00,							// GPIO port is input
	FS_OUTPUT	= 0x01,							// GPIO port is output
	FS_ALT5		= 0x02,							// GPIO alternate mode 5
	FS_ALT4		= 0x03,							// GPIO alternate mode 4
	FS_ALT0		= 0x04,							// GPIO alternate mode 0
	FS_ALT1		= 0x05,							// GPIO alternate mode 1
	FS_ALT2		= 0x06,							// GPIO alternate mode 2
	FS_ALT3		= 0x07							// GPIO alternate mode 3
} FSEL_GPIO_TYPE;
#endif


/*==========================================================================}
;{				BCM2835/6/7 IRQ CONTROLLER WRITABLE REGISTERS			    }
;{=========================================================================*/
#ifdef __ASSEMBLER__
/*--------------------------------------------------------------------------}
{	   BCM2835 IRQ CONTROLLER WRITABLE REGISTERS DEFINED FOR ASSEMBLER   	}
{--------------------------------------------------------------------------*/
#define IRQ_FIQ_WRITE		0x0C
#define IRQ_ENABLE1_WRITE	0x10
#define IRQ_ENABLE2_WRITE	0x14
#define IRQ_ENABLE0_WRITE   0x18
#define IRQ_DISABLE1_WRITE  0x1C
#define IRQ_DISABLE2_WRITE  0x20
#define IRQ_DISABLE0_WRITE  0x24
#else 
/*--------------------------------------------------------------------------}
{		   BCM2835 IRQ CONTROLLER WRITABLE REGISTERS ENUMERATED	FOR C   	}
{--------------------------------------------------------------------------*/
typedef enum IRQ_WRITE_REGISTER {
	IRQ_FIQ_WRITE		= 0x0C,
	IRQ_ENABLE1_WRITE	= 0x10,
	IRQ_ENABLE2_WRITE	= 0x14,
	IRQ_ENABLE0_WRITE	= 0x18,
	IRQ_DISABLE1_WRITE	= 0x1C,
	IRQ_DISABLE2_WRITE	= 0x20,
	IRQ_DISABLE0_WRITE	= 0x24
} IRQ_WRITE_REGISTER;
#endif


/*==========================================================================}
;{				BCM2835/6/7 IRQ CONTROLLER READABLE REGISTERS			    }
;{=========================================================================*/
#ifdef __ASSEMBLER__
/*--------------------------------------------------------------------------}
{	   BCM2835 IRQ CONTROLLER READABLE REGISTERS DEFINED FOR ASSEMBLER   	}
{--------------------------------------------------------------------------*/
#define IRQ_FIQ_READ		0x0C
#define IRQ_ENABLE1_READ	0x10
#define IRQ_ENABLE2_READ	0x14
#define IRQ_ENABLE0_READ	0x18
#define IRQ_DISABLE1_READ	0x1C
#define IRQ_DISABLE2_READ	0x20
#define IRQ_DISABLE0_READ   0x24
#define IRQ_PENDING0_READ   0x00
#define IRQ_PENDING1_READ   0x04
#define IRQ_PENDING2_READ   0x08
#else
/*--------------------------------------------------------------------------}
{		   BCM2835 IRQ CONTROL READABLE REGISTERS ENUMERATED FOR C 			}
{--------------------------------------------------------------------------*/
typedef enum IRQ_READ_REGISTER {
	IRQ_FIQ_READ	  = 0x0C,
	IRQ_ENABLE1_READ  = 0x10,
	IRQ_ENABLE2_READ  = 0x14,
	IRQ_ENABLE0_READ  = 0x18,
	IRQ_DISABLE1_READ = 0x1C,
	IRQ_DISABLE2_READ = 0x20,
	IRQ_DISABLE0_READ = 0x24,
	IRQ_PENDING0_READ = 0x00,
	IRQ_PENDING1_READ = 0x04,
	IRQ_PENDING2_READ = 0x08
} IRQ_READ_REGISTER;
#endif

/*==========================================================================}
;{				RASPBERRY PI MAILBOX CHANNEL CONSTANTS DEFINED			    }
;{=========================================================================*/
#ifdef __ASSEMBLER__
/*--------------------------------------------------------------------------}
{	               MAILBOX CHANNELS DEFINED FOR ASSEMBLER   				}
{--------------------------------------------------------------------------*/
#define MAIL_POWER		0x0			/* Mailbox Channel 0: Power Management Interface */
#define MAIL_FB			0x1			/* Mailbox Channel 1: Frame Buffer */
#define MAIL_VUART		0x2			/* Mailbox Channel 2: Virtual UART */
#define MAIL_VCHIQ		0x3			/* Mailbox Channel 3: VCHIQ Interface */
#define MAIL_LEDS		0x4			/* Mailbox Channel 4: LEDs Interface */
#define MAIL_BUTTONS	0x5			/* Mailbox Channel 5: Buttons Interface */
#define MAIL_TOUCH		0x6			/* Mailbox Channel 6: Touchscreen Interface */
#define MAIL_COUNT		0x7			/* Mailbox Channel 7: Counter */
#define MAIL_TAGS		0x8			/* Mailbox Channel 8: Tags (ARM to VC) */
#else
/*--------------------------------------------------------------------------}
{				   MAILBOX CHANNELS VALUES ENUMERATED FOR C   				}
{--------------------------------------------------------------------------*/
typedef enum {
	MAIL_POWER		= 0x0,			/* Mailbox Channel 0: Power Management Interface */
	MAIL_FB			= 0x1,			/* Mailbox Channel 1: Frame Buffer */
	MAIL_VUART		= 0x2,			/* Mailbox Channel 2: Virtual UART */
	MAIL_VCHIQ		= 0x3,			/* Mailbox Channel 3: VCHIQ Interface */
	MAIL_LEDS		= 0x4,			/* Mailbox Channel 4: LEDs Interface */
	MAIL_BUTTONS	= 0x5,			/* Mailbox Channel 5: Buttons Interface */
	MAIL_TOUCH		= 0x6,			/* Mailbox Channel 6: Touchscreen Interface */
	MAIL_COUNT		= 0x7,			/* Mailbox Channel 7: Counter */
	MAIL_TAGS		= 0x8			/* Mailbox Channel 8: Tags (ARM to VC) */
} MAILBOX_CHANNEL;
#endif

/*--------------------------------------------------------------------------}
;{						 MAILBOX TAG CLOCK ID VALUES					    }
;{-------------------------------------------------------------------------*/
#define TAG_CLOCK_RESERVED	0
#define TAG_CLOCK_EMMC		1
#define TAG_CLOCK_UART		2
#define TAG_CLOCK_ARM		3
#define TAG_CLOCK_CORE		4
#define TAG_CLOCK_V3D		5
#define TAG_CLOCK_H264		6
#define TAG_CLOCK_ISP		7
#define TAG_CLOCK_SDRAM		8
#define TAG_CLOCK_PIXEL		9
#define TAG_CLOCK_PWM		10

/*--------------------------------------------------------------------------}
;{						  MAILBOX OFFSET VALUES							    }
;{-------------------------------------------------------------------------*/
#define MAIL_BASE_OFFSET	0xB880	/* Mailbox Base Address offset from IO BASE ADDR */
#define MAIL_READ_OFFS		0x00	/* Mailbox Read Register */
#define MAIL_STATUS_OFFS	0x18	/* Mailbox Status Register */
#define MAIL_CONFIG_OFFS	0x1C	/* Mailbox Config Register */
#define MAIL_WRITE_OFFS		0x20	/* Mailbox Write Register */
/*--------------------------------------------------------------------------}
;{						  MAILBOX STATUS MASKS							    }
;{-------------------------------------------------------------------------*/
#define MAIL_EMPTY	0x40000000		/* Mailbox Status Register: Mailbox Empty */
#define MAIL_FULL	0x80000000		/* Mailbox Status Register: Mailbox Full  */

/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{				 RPI PROPERTY MAILBOX TAG CONSTANTS DEFINED		            }
{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
/* Videocore */
#define RPI_FIRMWARE_GET_VERSION					0x00000001

/* cursor */
#define RPI_FIRMWARE_SET_CURSOR_INFO				0x00008010
#define RPI_FIRMWARE_SET_CURSOR_STATE				0x00008011

/* Hardware */
#define RPI_FIRMWARE_GET_BOARD_MODEL				0x00010001
#define	RPI_FIRMWARE_GET_BOARD_REVISION				0x00010002
#define RPI_FIRMWARE_GET_BOARD_MAC_ADDRESS			0x00010003
#define	RPI_FIRMWARE_GET_BOARD_SERIAL				0x00010004
#define	RPI_FIRMWARE_GET_ARM_MEMORY					0x00010005
#define	RPI_FIRMWARE_GET_VC_MEMORY					0x00010006
#define	RPI_FIRMWARE_GET_CLOCKS						0x00010007

/* Power */
#define RPI_FIRMWARE_GET_POWER_STATE				0x00020001
#define	RPI_FIRMWARE_GET_TIMING						0x00020002
#define	RPI_FIRMWARE_SET_POWER_STATE				0x00028001

/* Clocks */
#define	RPI_FIRMWARE_GET_CLOCK_STATE				0x00030001
#define	RPI_FIRMWARE_GET_CLOCK_RATE					0x00030002
#define RPI_FIRMWARE_GET_MAX_CLOCK_RATE				0x00030004
#define	RPI_FIRMWARE_GET_MIN_CLOCK_RATE				0x00030007
#define RPI_FIRMWARE_GET_TURBO						0x00030009

#define	RPI_FIRMWARE_SET_CLOCK_STATE				0x00038001
#define	RPI_FIRMWARE_SET_CLOCK_RATE					0x00038002
#define RPI_FIRMWARE_SET_TURBO						0x00038009

/* system including voltage & temp */
#define	RPI_FIRMWARE_GET_VOLTAGE					0x00030003
#define	RPI_FIRMWARE_GET_MAX_VOLTAGE				0x00030005
#define	RPI_FIRMWARE_GET_TEMPERATURE				0x00030006
#define	RPI_FIRMWARE_GET_MIN_VOLTAGE				0x00030008
#define	RPI_FIRMWARE_GET_MAX_TEMPERATURE			0x0003000a
#define	RPI_FIRMWARE_ALLOCATE_MEMORY				0x0003000c
#define	RPI_FIRMWARE_LOCK_MEMORY					0x0003000d
#define	RPI_FIRMWARE_UNLOCK_MEMORY					0x0003000e
#define	RPI_FIRMWARE_RELEASE_MEMORY					0x0003000f
#define	RPI_FIRMWARE_EXECUTE_CODE					0x00030010
#define	RPI_FIRMWARE_EXECUTE_QPU					0x00030011
#define	RPI_FIRMWARE_SET_ENABLE_QPU					0x00030012
#define	RPI_FIRMWARE_GET_DISPMANX_HANDLE			0x00030014
#define	RPI_FIRMWARE_GET_EDID_BLOCK					0x00030020
#define	RPI_FIRMWARE_GET_CUSTOMER_OTP				0x00030021
#define	RPI_FIRMWARE_GET_DOMAIN_STATE				0x00030030
#define	RPI_FIRMWARE_GET_GPIO_STATE					0x00030041

#define	RPI_FIRMWARE_SET_VOLTAGE					0x00038003
#define	RPI_FIRMWARE_SET_CUSTOMER_OTP				0x00038021
#define	RPI_FIRMWARE_SET_DOMAIN_STATE				0x00038030
#define	RPI_FIRMWARE_SET_GPIO_STATE					0x00038041
#define	RPI_FIRMWARE_SET_SDHOST_CLOCK				0x00038042

/* Dispmanx TAGS */
#define	RPI_FRAMEBUFFER_ALLOCATE_BUFFER				0x00040001
#define	RPI_FRAMEBUFFER_BLANK_SCREEN				0x00040002
#define	RPI_FRAMEBUFFER_GET_PHYSICAL_WIDTH_HEIGHT	0x00040003
#define	RPI_FRAMEBUFFER_GET_VIRTUAL_WIDTH_HEIGHT	0x00040004
#define	RPI_FRAMEBUFFER_GET_COLOUR_DEPTH			0x00040005
#define	RPI_FRAMEBUFFER_GET_PIXEL_ORDER				0x00040006
#define	RPI_FRAMEBUFFER_GET_ALPHA_MODE				0x00040007
#define	RPI_FRAMEBUFFER_GET_PITCH					0x00040008
#define	RPI_FRAMEBUFFER_GET_VIRTUAL_OFFSET			0x00040009
#define	RPI_FRAMEBUFFER_GET_OVERSCAN				0x0004000a
#define	RPI_FRAMEBUFFER_GET_PALETTE					0x0004000b
#define	RPI_FRAMEBUFFER_GET_TOUCHBUF				0x0004000f
#define	RPI_FRAMEBUFFER_GET_GPIOVIRTBUF				0x00040010

#define	RPI_FRAMEBUFFER_RELEASE						0x00048001
#define	RPI_FRAMEBUFFER_SET_PHYSICAL_WIDTH_HEIGHT	0x00048003
#define	RPI_FRAMEBUFFER_SET_VIRTUAL_WIDTH_HEIGHT	0x00048004
#define	RPI_FRAMEBUFFER_SET_COLOUR_DEPTH			0x00048005
#define	RPI_FRAMEBUFFER_SET_PIXEL_ORDER				0x00048006
#define	RPI_FRAMEBUFFER_SET_ALPHA_MODE				0x00048007
#define	RPI_FRAMEBUFFER_SET_VIRTUAL_OFFSET			0x00048009
#define	RPI_FRAMEBUFFER_SET_OVERSCAN				0x0004800a
#define	RPI_FRAMEBUFFER_SET_PALETTE					0x0004800b
#define	RPI_FRAMEBUFFER_SET_VSYNC					0x0004800e
#define	RPI_FRAMEBUFFER_SET_BACKLIGHT				0x0004800f

#define	RPI_FIRMWARE_VCHIQ_INIT						0x00048010

#define	RPI_FRAMEBUFFER_TEST_PHYSICAL_WIDTH_HEIGHT	0x00044003
#define	RPI_FRAMEBUFFER_TEST_VIRTUAL_WIDTH_HEIGHT	0x00044004
#define	RPI_FRAMEBUFFER_TEST_DEPTH					0x00044005
#define	RPI_FRAMEBUFFER_TEST_PIXEL_ORDER			0x00044006
#define	RPI_FRAMEBUFFER_TEST_ALPHA_MODE				0x00044007
#define	RPI_FRAMEBUFFER_TEST_VIRTUAL_OFFSET			0x00044009
#define	RPI_FRAMEBUFFER_TEST_OVERSCAN				0x0004400a
#define	RPI_FRAMEBUFFER_TEST_PALETTE				0x0004400b
#define	RPI_FRAMEBUFFER_TEST_VSYNC					0x0004400e

/* Config */
#define	RPI_FIRMWARE_GET_COMMAND_LINE				0x00050001

/* Shared resource management */
#define	RPI_FIRMWARE_GET_DMA_CHANNELS				0x00060001

/*==========================================================================}
;{			  RASPBERRY PI LEVEL L1 CACHE CONSTANTS DEFINED				    }
;{=========================================================================*/
#define SCTLR_ENABLE_DATA_CACHE			0x4
#define SCTLR_ENABLE_BRANCH_PREDICTION	0x800
#define SCTLR_ENABLE_INSTRUCTION_CACHE  0x1000

#ifndef __ASSEMBLER__								// C needs to define this type
/*--------------------------------------------------------------------------}
;{						  RGBA COLOR TYPE DEFINED						    }
;{-------------------------------------------------------------------------*/
typedef uint32_t RGBA;
#endif

/*==========================================================================}
;{	 RASPBERRY PI EMMC (ELECTRONIC MULTI MEDIA CARD) INTERFACE REGISTERS    }
;{        (register details from partA2_300.pdf from www.sdcard.org)        }
;{=========================================================================*/
#define EMMC_BASE			0x300000				// EMMC registers offset from RPI_IO_Base_Addr

#define	EMMC_ARG2_OFFS		 0						// Argument 2 register
#define EMMC_BLKSIZECNT_OFFS 4						// Block size count
#define EMMC_ARG1_OFFS		 8						// Argument 1 register
#define EMMC_CMDTM_OFFS		0x0C					// Transfer mode register
#define EMMC_RESP0_OFFS		0x10					// Response 0 register
#define EMMC_RESP1_OFFS		0x14					// Response 1 register
#define EMMC_RESP2_OFFS 	0x18					// Response 2 register
#define EMMC_RESP3_OFFS		0x1C					// Response 3 register
#define EMMC_DATA_OFFS		0x20					// Data register
#define EMMC_STATUS_OFFS	0x24					// Status register
#define EMMC_CONTROL0_OFFS	0x28					// Control register 0
#define EMMC_CONTROL1_OFFS	0x2C					// Control register 1
#define EMMC_INTERRUPT_OFFS	0x30					// Interrupt control register
#define EMMC_IRPT_MASK_OFFS	0x34					// Interrupt mask register
#define EMMC_IRPT_EN_OFFS	0x38					// Interrupt enable register
#define EMMC_CONTROL2_OFFS	0x3C					// Control register 2
#define EMMC_CAPABILITIES_0	0x40					// Capabilities register 0
#define EMMC_CAPABILITIES_1	0x44					// Capabilities register 1
#define EMMC_FORCE_IRPT		0x50					// Force report
#define EMMC_BOOT_TIMEOUT	0x70					// Boot timeout
#define EMMC_DBG_SEL		0x74					// Debug selection
#define EMMC_EXRDFIFO_CFG	0x80					// Extended read fifo config
#define EMMC_EXRDFIFO_EN	0x84					// Extended read fifo enable
#define EMMC_TUNE_STEP		0x88					// Tune step 
#define EMMC_TUNE_STEPS_STD	0x8C					// Tune steps
#define EMMC_TUNE_STEPS_DDR	0x90					// Tune steps DDR
#define EMMC_SPI_INT_SPT	0xF0					// SPI interrrupt
#define EMMC_SLOTISR_VER_OFFS	0xFC				// Slot version

#define SDERR_WAIT_INT_TIMEOUT  1
#define SDERR_WAIT_INT_ERRMASK  2

#define SD_OK                0
#define SD_ERROR             1
#define SD_TIMEOUT           2
#define SD_BUSY              3
#define SD_NO_RESP           5
#define SD_ERROR_RESET       6
#define SD_ERROR_INHIBIT	 7
#define SD_ERROR_CLOCK       8
#define SD_ERROR_VOLTAGE     9
#define SD_ERROR_APP_CMD     10
#define SD_CARD_CHANGED      11
#define SD_CARD_ABSENT       12
#define SD_CARD_REINSERTED   13
#define SD_CARD_MOUNT_FAIL	 14      // Could not mount partition

/***************************************************************************}
{                      PUBLIC INTERFACE MEMORY VARIABLES                    }
{***************************************************************************/
#ifndef __ASSEMBLER__								// C needs external references
extern uint32_t RPi_CompileMode;					// RPI cpu the compiler was targetting when compiling code
extern uint32_t RPi_CpuId;							// RPI CPU type detected by SmartStart.S
extern uint32_t RPi_IO_Base_Addr;					// RPI IO base address auto-detected by SmartStart.S
extern uint32_t RPi_BootAddr;						// RPI address processor booted from
extern uint32_t RPi_CPUBootMode;					// RPI cpu mode it was in when it booted
extern uint32_t RPi_CPUCurrentMode;					// RPI cpu current operation mode
extern uint32_t RPi_GraphWidth;						// RPI current graphics mode screen width
extern uint32_t RPi_GraphHeight;					// RPI current graphics mode screen height
extern uint32_t RPi_GraphColorDepth;				// RPI current graphics mode colour depth

typedef void(*SDErrorHandler) (void);
extern uint32_t RPi_SD_Error;
extern SDErrorHandler RPi_SD_Errorhandler;
extern uint32_t RPi_Heap;

extern uint32_t RPi_disableCRLF;

#else												// Define the variables in ASM
.section ".data.smartstart", "aw"
.balign 4
.globl RPi_CompileMode; @ Make sure RPi_CompileMode label is global
RPi_CompileMode : .4byte 0; @ CPU this code was compiled for is 4 byte value
	.globl RPi_CpuId; @ Make sure RPi_CpuId label is global
	RPi_CpuId : .4byte 0; @ CPU Id is 4 byte variable
	.globl RPi_IO_Base_Addr; @ Make sure Pi_IO_Base_Addr label is global
	RPi_IO_Base_Addr : .4byte 0; @ Peripheral Base addr is 4 byte variable
	.globl RPi_BootAddr; @ Make sure RPi_BootAddr label is global
	RPi_BootAddr : .4byte 0; @ CPU boot address is 4 byte variable
	.globl RPi_CPUBootMode; @ Make sure RPi_CPUBootMode label is global
	RPi_CPUBootMode : .4byte 0; @ CPU Boot Mode is 4 byte variable
	.globl RPi_CPUCurrentMode; @ Make sure RPi_CPUCurrentMode label is global
	RPi_CPUCurrentMode : .4byte 0; @ CPU current Mode is 4 byte variable
	.globl RPi_GraphWidth; @ Make sure RPi_GraphWidth label is global
	RPi_GraphWidth : .4byte 0; @ RPi_GraphWidth is 4 byte variable
	.globl RPi_GraphHeight; @ Make sure RPi_GraphHeight label is global
	RPi_GraphHeight : .4byte 0; @ RPi_GraphHeight is 4 byte variable
	.globl RPi_GraphColorDepth; @ Make sure RPi_GraphColorDepth label is global
	RPi_GraphColorDepth : .4byte 0; @ RPi_GraphHeight is 4 byte variable

	.globl RPi_SD_Error; @ Make sure RPi_SD_Error label is global
	RPi_SD_Error : .4byte 0; @ RPi_SD_Error is 4 byte variable
	.globl RPi_SD_Errorhandler; @ Make sure RPi_SD_Errorhandler label is global
	RPi_SD_Errorhandler : .4byte 0; @ RPi_SD_Errorhandler is 4 byte variable

	.globl RPi_Heap; @ Make sure RPi_Heap label is global
	RPi_Heap : .4byte 0; @ RPi_Heap is 4 byte variable

#endif

#ifndef __ASSEMBLER__
/***************************************************************************}
{                       PUBLIC C INTERFACE ROUTINES                         }
{***************************************************************************/

/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{        ACTIVITY-LED HELPER ROUTINES PROVIDE BY RPi-SmartStart API         }
{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/

/*- RPI_Activity_Led -------------------------------------------------------
 Sets the actual Raspberry Pi activity led on/off as requested. The routine 
 is Pi3 compatible and will use the mailbox system rather than a GPIO on the 
 Pi3. So unlike specific GPIO routines this smart-start function knows to 
 check board type and pick the appropriate method to achieve the request.
 20Jan17 LdB
 --------------------------------------------------------------------------*/
extern void RPI_Activity_Led (bool On) __attribute__((pcs("aapcs")));

/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{            GPIO HELPER ROUTINES PROVIDE BY RPi-SmartStart API             }
{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/

/*- RPI_GPIO_SetFuncMode ----------------------------------------------------
 Sets the given GPIO port functionality to the FSEL_GPIO_TYPE request mode. 
 The valid GPIO port range is 0-53 inclusive.
 RETURN: true for success, false for any failure
 20Jan17 LdB
 --------------------------------------------------------------------------*/
extern bool RPI_GPIO_SetFuncMode (uint8_t gpio_num, FSEL_GPIO_TYPE mode) __attribute__((pcs("aapcs")));

/*- RPI_GPIO_SetClr --------------------------------------------------------
 Sets or clears the given GPIO port number as per the Set request flag. Port 
 needs to have been initialized to FS_OUTPUT via RPI_GPIO_SetFuncMode before 
 use. The valid GPIO port range is 0-53 inclusive.
 RETURN: true for success, false for any failure 
 20Jan17 LdB
 --------------------------------------------------------------------------*/
extern bool RPI_GPIO_SetClr (uint8_t gpio_num, bool Set) __attribute__((pcs("aapcs")));

/*- RPI_GPIO_ClrEvent -------------------------------------------------------
 Clears the given GPIO port number event/irq flag. The valid GPIO port range is 
 0-53 inclusive.
 RETURN: true for success, false for any failure 
 10May17 LdB
 --------------------------------------------------------------------------*/
extern bool RPI_GPIO_ClrEvent (uint8_t gpio_num) __attribute__((pcs("aapcs")));

/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{      TIMER CONTROLLER HELPER ROUTINES PROVIDE BY RPi-SmartStart API       }
{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/

/*-WaitMicroSeconds----------------------------------------------------------
 This will simply wait the requested number of microseconds before return.
 The timer read is as per the Broadcom specification of two 32bit reads
 (http://embedded-xinu.readthedocs.io/en/latest/arm/rpi/BCM2835-System-Timer.html)
 18Jan17 LdB
 --------------------------------------------------------------------------*/
extern void RPI_WaitMicroSeconds (uint64_t us) __attribute__((pcs("aapcs")));

/*-GetArmTickCount-----------------------------------------------------------
 Same as GetTickCount but at full 1Mhz Rapberry Pi system timer resolution.
 The timer read is as per the Broadcom specification of two 32bit reads
 (http://embedded-xinu.readthedocs.io/en/latest/arm/rpi/BCM2835-System-Timer.html)
 24Jan17 LdB
 --------------------------------------------------------------------------*/
extern uint64_t RPI_GetArmTickCount(void) __attribute__((pcs("aapcs")));

/*-RPI_TickDifference--------------------------------------------------------
 Given to ArmTimerTicks it will return elapsed time in microseconds between.
 It knows in the new_tick is less than the original_tick then the timer 
 rolled at max count and still returns the correct time. Most common use
 is a held original_time and current GetArmTickCount() for timeouts.
 example:  elapse = RPI_TickDifference(original_tick, RPI_GetArmTickCount());
 18Jan17 LdB
 --------------------------------------------------------------------------*/
extern uint64_t RPI_TickDifference (uint64_t original_tick, uint64_t new_tick) __attribute__((pcs("aapcs")));


/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{			MEMORY HELPER ROUTINES PROVIDE BY RPi-SmartStart API		    }
{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/

extern uint32_t RPI_ARMaddressToBUSaddress (void* ARMaddress) __attribute__((pcs("aapcs")));

extern uint32_t RPI_BUSaddressToARMaddress (void* BUSaddress) __attribute__((pcs("aapcs")));

/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{			MAILBOX HELPER ROUTINES PROVIDE BY RPi-SmartStart API		    }
{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/

extern uint32_t RPI_MailboxWrite (MAILBOX_CHANNEL channel, uint32_t value) __attribute__((pcs("aapcs")));

extern bool RPI_MailtagExchange4 (uint32_t* result, uint32_t tagid, uint32_t value) __attribute__((pcs("aapcs")));
extern bool RPI_MailtagExchange8 (uint32_t* result1, uint32_t* result2, uint32_t tagid, uint32_t value1, uint32_t value2) __attribute__((pcs("aapcs")));
extern bool RPI_MailtagExchange12 (uint32_t* result1, uint32_t* result2, uint32_t tagid, uint32_t value1, uint32_t value2, uint32_t value3) __attribute__((pcs("aapcs")));

/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{			STRING HELPER ROUTINES PROVIDE BY RPi-SmartStart API		    }
{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/

/*-RPI_GetFileExtension------------------------------------------------------
 Returns extension of a given filepath string eg. ".job",".txt" etc in asciiz
 As the return is asciiz the usual maxlen is 5 for a normal 8:3 filename. If
 just length but not the actual string is required you can set Ext to NULL.
 Return: The length of the extension name returned (minus the asciiz char)
 05Feb17 LdB
 --------------------------------------------------------------------------*/
extern uint32_t RPI_GetFileExtension (char* FilePath, char* Extension, uint32_t maxExtLen) __attribute__((pcs("aapcs")));

/*-RPI_GetFilename-----------------------------------------------------------
 Returns the filename from a full filepath string in asciiz format.
 IE: "c:\\somedirectory\\afile.ext" would return "afile". If just the length
 but not the actual string is required you can set Filename ptr to NULL.
 Return: The length of the filename returned (minus the ascizz char)
 05Feb17 LdB
 --------------------------------------------------------------------------*/
extern uint32_t RPI_GetFilename (char* FilePath, char* Filename, uint32_t maxlen) __attribute__((pcs("aapcs")));

/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{			GRAPHICS HELPER ROUTINES PROVIDE BY RPi-SmartStart API		    }
{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/

/*-RPI_InitGraph-------------------------------------------------------------
 Initializes the graphics screen to the width, height, colour depth requested
 If sussessful will return true, any failure will return false.
 24Jan17 LdB
 --------------------------------------------------------------------------*/
extern bool RPI_InitGraph (uint32_t Width, uint32_t Height, uint32_t ColourDepth) __attribute__((pcs("aapcs")));

/*-RPI_GetGraphMode----------------------------------------------------------
 Returns the current screen parameters to any valid pointer provided. If a
 parameter is not required a NULL pointer can used for that parameter ptr.
 If sussessful will return true, any failure will return false.
 24Jan17 LdB
 --------------------------------------------------------------------------*/
extern bool RPI_GetGraphMode (uint32_t* Width, uint32_t* Height, uint32_t* ColourDepth) __attribute__((pcs("aapcs")));

/*-RPI_WriteChar-------------------------------------------------------------
 Writes the given character in the given RGBA colour to screen position (X,Y) 
 This is a transparent write only the defined text pixels will be written.
 You can use clear area first if you wish to set a background colour to text.
 24Jan17 LdB
 --------------------------------------------------------------------------*/
extern void RPI_WriteChar(uint32_t X, uint32_t Y, char Ch, RGBA Colour) __attribute__((pcs("aapcs")));

/*-RPI_WriteText-------------------------------------------------------------
 Writes the null terminated string in the given RGBA colour starting at the 
 screen position (X,Y). This is a transparent write only the defined text 
 pixels will be written. You can use clear area first if you wish to set a 
 background colour to text.
 24Jan17 LdB
 --------------------------------------------------------------------------*/
extern void RPI_WriteText (uint32_t X, uint32_t Y, char* Txt, RGBA Colour) __attribute__((pcs("aapcs")));

/*-RPI_ClearArea-------------------------------------------------------------
 Clears the rectangle from top left (X1,Y1) to lower right (X2, Y2) in the 
 given RGBA colour. X2,Y2 is not inclusive and both must be larger than the
 top left partner or else the command is ignored.
 24Jan17 LdB
 --------------------------------------------------------------------------*/
extern void RPI_ClearArea (uint32_t X1, uint32_t Y1, uint32_t X2, uint32_t Y2, RGBA Colour) __attribute__((pcs("aapcs")));

/*-RPI_SetPixel-------------------------------------------------------------
 Sets the pixel (X,Y) to the given colour. If the point (X,Y) is outside the
 screen area the command is ignored.
 24Jan17 LdB
 --------------------------------------------------------------------------*/
extern void RPI_SetPixel (uint32_t X, uint32_t Y, RGBA Colour);

/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{			GRAPHICS CONSOLE ROUTINES PROVIDE BY RPi-SmartStart API		    }
{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/

/*-RPI_GraphicsDisableCRLF---------------------------------------------------
 Turns ON/OFF the disable to screen position movement response to characters 
 CR and LF on the graphics console. Using a CR (#13) will set x position back
 to zero. While LF (#10) will set x position back to zero and move y position
 down 1 fontheight. This is what controls the output movement in printf etc.
 I ran across the problem in trying to display disk FAT to screen I needed to
 turn off the behaviour and this provides that feature. The disable defaults
 to off and you should only turn it on if you wish to display the characters
 CR and LF to screen as graphical symbols.
 10Feb17 LdB
 --------------------------------------------------------------------------*/
extern void RPI_GraphicsDisableCRLF (bool SetOff) __attribute__((pcs("aapcs")));


/*-RPI_GraphGotoXY----------------------------------------------------------
 Sets the current screen console position to X,Y so any subsequent console 
 output will be at this position. Position X,Y must be with in screen area.
 11Feb17 LdB
 --------------------------------------------------------------------------*/
extern void RPI_GraphGotoXY (uint32_t X, uint32_t Y) __attribute__((pcs("aapcs")));


/*-RPI_GraphWhereXY----------------------------------------------------------
 Returns the current screen console position to the address pointers X,Y. 
 If one of the values is not needed NULL can be used as value not required.
 11Feb17 LdB
 --------------------------------------------------------------------------*/
extern void RPI_GraphWhereXY (uint32_t* X, uint32_t* Y) __attribute__((pcs("aapcs")));


/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{		  SD_CARD EMMC HELPER ROUTINES PROVIDE BY RPi-SmartStart API 	    }
{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/

// SD card support field values.
#define SD_SUPP_SET_BLOCK_COUNT 0x80000000		// SD CARD supports set block command
#define SD_SUPP_SPEED_CLASS     0x40000000		// SD CARD supports speed classes
#define SD_SUPP_BUS_WIDTH_4     0x20000000		// SD CARD supports 4 bit bus
#define SD_SUPP_BUS_WIDTH_1     0x10000000		// SD CARD supports 1 bit bus

// SD card type field values.
#define SD_TYPE_MMC  1							// Multi Media Card
#define SD_TYPE_1    2							// SD CARD ver 1
#define SD_TYPE_2_SC 3							// SD CARD standard capacity
#define SD_TYPE_2_HC 4							// SD CARD high capacity

// SD host type field values.
#define SDC_HOST_VER1 0x00						// Version 1 SD card host
#define SDC_HOST_VER2 0x01						// Version 2 SD card host
#define SDC_HOST_VER3 0x02						// Version 3 SD card host

// SDHANDLE type defined (contains some info held about the SD CARD)
typedef struct __attribute__((packed)) SDHandle_struct {
	// Static information about the SD Card.
	uint32_t		hostversion;
	uint32_t		support;
	uint64_t		capacity;					// Drive capacity in bytes
	uint64_t		blocknum;
	uint32_t		blocksize;
	uint32_t		RCA;
	struct __attribute__((packed)) {
		uint8_t		revL;
		uint8_t		revH;
		uint8_t		dateY;
		uint8_t		dateM;
	};
	uint32_t		serial;
	struct __attribute__((packed)) {
		uint8_t		type;
		uint8_t		uhsi;
		uint8_t		fileformat;
		uint8_t		manufacturerId;
	};
	uint8_t			productname[8];				// 8 to keep alignment to 4 (only 6 characters) 
	/* Entries above here are locked to assembler code and can not be changed */
} SDHANDLE;

/*-RPI_sdHostVer------------------------------------------------------------
 Returns the SD host version on the SD card that is currently in the slot.
 The 3 options are (00h = ver1, 01h = ver2, 02h = ver3) #defined above
 11Feb17 LdB
 --------------------------------------------------------------------------*/
extern uint8_t RPI_sdHostVer (void) __attribute__((pcs("aapcs")));

/*-RPI_sdInitCard-----------------------------------------------------------
 Initializes the SD Card that is currently in the slot. You must provide a
 valid pointer to a SDHANDLE buffer that will recieve data from initialize.
 Return: 0  for success,  SD Error value otherwise
 11Feb17 LdB
 --------------------------------------------------------------------------*/
extern uint32_t RPI_sdInitCard(SDHANDLE* sdHandle) __attribute__((pcs("aapcs")));

/*-RPI_sdTransferBlocks-----------------------------------------------------
 Transfers a sector block(s) of data to or from the SD Card currently in the 
 slot. You must provide a valid SDHANDLE and buffer that will recieve or has
 the data. A block is 512 bytes and the write flag controls if the data is
 read or written, while the number refers to the sector on the SD card.
 Return: 0  for success,  SD Error value otherwise
 11Feb17 LdB
 --------------------------------------------------------------------------*/
extern uint32_t RPI_sdTransferBlocks (SDHANDLE* sdHandle, uint32_t blockaddr, uint32_t num, uint8_t* buffer, bool write) __attribute__((pcs("aapcs")));

/*-RPI_sdEraseBlocks--------------------------------------------------------
 Erases a sector block(s) on the SD Card. This is used for formatting an SD 
 card not for deleting a file or changing a file.
 Return: 0  for success,  SD Error value otherwise
 11Feb17 LdB
 --------------------------------------------------------------------------*/
extern uint32_t RPI_sdEraseBlocks(SDHANDLE* sdHandle, uint32_t blockaddr, uint32_t numBlocks) __attribute__((pcs("aapcs")));


/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{		   USB_DRIVE HELPER ROUTINES PROVIDE BY RPi-SmartStart API 		    }
{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/

// USBHANDLE type defined (contains some info held about the USB DRIVE)
typedef struct __attribute__((packed)) USBHandle_struct {
	uint64_t		capacity;					// Drive capacity in bytes
} USBHANDLE;

#endif

#ifdef __cplusplus								// If we are including to a C++ file
}												// Close the extern C directive wrapper
#endif

#endif

