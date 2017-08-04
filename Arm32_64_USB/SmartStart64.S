/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{       Filename: smartstart64.s								}
{       Copyright(c): Leon de Boer(LdB) 2017					}
{       Version: 2.01											}
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

.section ".text.startup", "ax", %progbits
.balign	4
.globl _start
_start:	
	adr x12, _start							// Hold boot address in high register R12
	ldr x1, =RPi_BootAddr					// Address of RPi_BootAddr
	str w12, [x1]							// Store the boot address

	ldr	x0, =0x3F000000						// No need to detect address in 64bit mode it has to be 0x3F000000 on Pi3
	ldr x1, =RPi_IO_Base_Addr				// Address of RPi_IO_Base_Addr
	str w0, [x1]							// Store the IO base address

	mov x0, #0x38							// Compiled for ARM8 CPU in AARCH64 and supports 1 core
	ldr x1, =RPi_CompileMode				// Address of RPi_CompileMode
	str w0, [x1]							// Store the compiler mode  

	mrs	x0, midr_el1						// Read CPU Id register
	ldr x1, =RPi_CpuId						// Address of RPi_CpuId
	str w0, [x1]							// Store the CPU id 


	ldr	x0, =__EL2_stack 			/* Fetch address of EL2 stack */
	mov	sp, x0				/* EL2 stack set */
	ldr	x0, =__EL1_stack			/* Fetch address of EL1 stack */
	msr	sp_el1, x0			/* EL1 stack set */
	ldr	x0, =__EL0_stack			/* Fetch address of EL0 stack */
	msr	sp_el0, x0			/* EL0 stack set */

	/* Initialize Generic Timers */
	mrs	x0, cnthctl_el2
	orr	x0, x0, #0x3			/* Enable EL1 access to timers */
	msr	cnthctl_el2, x0
	msr	cntvoff_el2, xzr
	
	/* Not sure if I want this yet */
	mrs	x0, cntkctl_el1
	orr	x0, x0, #0x3			/* Enable EL0 access to timers */
	msr	cntkctl_el1, x0

	/* Initilize MPID/MPIDR registers */
	mrs	x0, midr_el1
	mrs	x1, mpidr_el1
	msr	vpidr_el2, x0
	msr	vmpidr_el2, x1

	/* Disable coprocessor traps */
	mov	x0, #0x33ff
	msr	cptr_el2, x0			/* Disable coprocessor traps to EL2 */
	msr	hstr_el2, xzr			/* Disable coprocessor traps to EL2 */
	mov	x0, #3 << 20
	msr	cpacr_el1, x0			/* Enable FP/SIMD at EL1 */

	/* Initialize HCR_EL2 */
	mov	x0, #(1 << 31)			/* 64bit EL1 */
	msr	hcr_el2, x0

	/* SCTLR_EL1 initialization */
	mov	x0, #0x0800
	movk	x0, #0x30d0, lsl #16
	msr	sctlr_el1, x0

	/* Return to the EL1_SP1 mode from EL2 */
	mov	x0, #0x3c5
	msr	spsr_el2, x0	/* EL1_SP1 | D | A | I | F */
	adr	x0, exit_el1
	msr	elr_el2, x0
	eret
exit_el1:



	/* Set vector table for EL1 */
    	ldr x0,=VectorTable
    	msr vbar_el1,x0

	/* About to go to C clear BSS */
	ldr x3, =__bss_end__
	ldr x0, =__bss_start__
	cmp	x0, x3
	bcs	.bss_cleared
.bss_zero_loop:
	str	wzr, [x0], 4
	cmp	x3, x0
	bhi	.bss_zero_loop
.bss_cleared:

	b kernel_main				/* Straight out to C I am not familiar enough with ARM64 assembler */
/*================================================================"
      Just safety incase C code ever returns back
"================================================================*/
hang:
	b hang
.balign	4
.ltorg							/* Tell assembler ltorg data for code above can go here */

.globl RPi_CpuIdString
RPi_CpuIdString:
	ldr x0, =ARM8_STR						// Can not be anything but a Cortex-a53 						
	ret										// Return
.balign	4
.ltorg										/* Tell assembler ltorg data for code above can go here */


.globl EnableInterrupts
EnableInterrupts:
	msr daifclr,#2
	ret

.globl DisableInterrupts
DisableInterrupts:
	msr daifset,#2
	ret

/* Provide weak reference c_irq_handler so if user does not use it functions as dummy */
.weak c_irq_handler
c_irq_handler:
	ret

/* Provide weak reference c_irq_identify_and_clear_source so if user does not use it functions as dummy */
.weak c_irq_identify_and_clear_source
c_irq_identify_and_clear_source:
	ret

/* Re-entrant interrupt handler stub */
/* http://infocenter.arm.com/help/index.jsp?topic=/com.arm.doc.den0024a/ch10s05.html */
.globl irq_handler
irq_handler:
	stp	x29, x30, [sp, #-16]!
	stp	x27, x28, [sp, #-16]!
	stp	x25, x26, [sp, #-16]!
	stp	x23, x24, [sp, #-16]!
	stp	x21, x22, [sp, #-16]!
	stp	x19, x20, [sp, #-16]!
	stp	x17, x18, [sp, #-16]!
	stp	x15, x16, [sp, #-16]!
	stp	x13, x14, [sp, #-16]!
	stp	x11, x12, [sp, #-16]!
	stp	x9, x10, [sp, #-16]!
	stp	x7, x8, [sp, #-16]!
	stp	x5, x6, [sp, #-16]!
	stp	x3, x4, [sp, #-16]!
	stp	x1, x2, [sp, #-16]!
	str	x0, [sp, #-16]!
	
	mrs	x1, SPSR_EL1
	mrs	x2, ELR_EL1
	stp	x1, x2, [sp, #-16]!
	bl c_irq_identify_and_clear_source  /* User will provide or will use weak stub */
	msr daifclr,#2
	bl	c_irq_handler					/* User will provide or will use weak stub */
	msr daifset,#2

	ldp	x1, x2, [sp], #16
	msr	ELR_EL1, x2
	msr	SPSR_EL1, x1

	ldr	x0, [sp], #16
	ldp	x1, x2, [sp], #16
	ldp	x3, x4, [sp], #16
	ldp	x5, x6, [sp], #16
	ldp	x7, x8, [sp], #16
	ldp	x9, x10, [sp], #16
	ldp	x11, x12, [sp], #16
	ldp	x13, x14, [sp], #16
	ldp	x15, x16, [sp], #16
	ldp	x17, x18, [sp], #16
	ldp	x19, x20, [sp], #16
	ldp	x21, x22, [sp], #16
	ldp	x23, x24, [sp], #16
	ldp	x25, x26, [sp], #16
	ldp	x27, x28, [sp], #16
	ldp	x29, x30, [sp], #16
	eret

/* macro to align handlers every 0x80 bytes */
.macro	vector handler
.balign 0x80
b	\handler
.endm

.balign 0x800
.globl	VectorTable
VectorTable:
	/* from current EL with sp_el0 */
	vector	_start			/* Synchronous */
	vector  hang			/* IRQ */
	vector	hang			/* FIQ */
	vector	hang			/* SErrorStub */

	/* from current EL with sp_elx, x != 0 */
	vector	hang			/* Synchronous */
	vector	irq_handler		/* IRQ */
	vector	hang			/* FIQ */
	vector	hang			/* SErrorStub */

	/* from lower EL, target EL minus 1 is AArch64 */
	vector	hang			/* Synchronous */
	vector  hang			/* IRQ */
	vector	hang			/* FIQ */
	vector	hang			/* SErrorStub */

	/* from lower EL, target EL minus 1 is AArch32 */
	vector	hang			/* Synchronous */
	vector  hang			/* IRQ */
	vector	hang			/* FIQ */
	vector	hang			/* SErrorStub */

/*==========================================================================}
;{					  CPU STRING CONSTANT DEFINITIONS					    }
;{=========================================================================*/
.section ".rodata.cpuid", "a", %progbits
.balign	4
ARM8_STR: .string "cortex-a53\0"

/****************************************************************
       	   DATA FOR SMARTSTART64  EXPOSED TO INTERFACE 
****************************************************************/
.section ".data.smartstart64", "aw"
.balign 4

.globl RPi_IO_Base_Addr;				// Make sure Pi_IO_Base_Addr label is global
RPi_IO_Base_Addr : .4byte 0;			// Peripheral Base addr is 4 byte variable in 64bit mode

.globl RPi_BootAddr;					// Make sure RPi_BootAddr label is global
RPi_BootAddr : .4byte 0;				// CPU boot address is 4 byte variable in 64bit mode

.globl RPi_CPUBootMode;					// Make sure RPi_CPUBootMode label is global
RPi_CPUBootMode : .4byte 0;				// CPU Boot Mode is 4 byte variable in 64bit mode

.globl RPi_CpuId;						// Make sure RPi_CpuId label is global
RPi_CpuId : .4byte 0;					// CPU Id is 4 byte variable in 64bit mode

.globl RPi_CompileMode;					// Make sure RPi_CompileMode label is global
RPi_CompileMode : .4byte 0;				// Compile mode is 4 byte variable in 64bit mode