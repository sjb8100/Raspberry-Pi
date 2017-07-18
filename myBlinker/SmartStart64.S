
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
	ldr	x0, =0x3F000000			/* No need to detect address in 64bit mode it has to be 0x3F000000 */
	ldr x1, =RPi_IO_Base_Addr	/* Address of RPi_IO_Base_Addr */
	str x0, [x1]				/* Set the address */
	
	ldr	x0, =__usrsys_stack 	/* Fetch address of user stack for safety */
	mov	sp, x0					/* Init to whatever EL level stack we have */
	ldr	x0, =__irq_stack		/* IRQ and exception handler run in EL1h */
	msr	sp_el1, x0				/* init their stack */

	/* Initialize Generic Timers */
	mrs	x0, cnthctl_el2
	orr	x0, x0, #0x3			/* Enable EL1 access to timers */
	msr	cnthctl_el2, x0
	msr	cntvoff_el2, xzr
	
	/* Not sure if I want this yet */
	mrs	x0, cntkctl_el1
	orr	x0, x0, #0x3		/* Enable EL0 access to timers */
	msr	cntkctl_el1, x0

	/* Initilize MPID/MPIDR registers */
	mrs	x0, midr_el1
	mrs	x1, mpidr_el1
	msr	vpidr_el2, x0
	msr	vmpidr_el2, x1

	/* Disable coprocessor traps */
	mov	x0, #0x33ff
	msr	cptr_el2, x0		/* Disable coprocessor traps to EL2 */
	msr	hstr_el2, xzr		/* Disable coprocessor traps to EL2 */
	mov	x0, #3 << 20
	msr	cpacr_el1, x0		/* Enable FP/SIMD at EL1 */

	/* Initialize HCR_EL2 */
	mov	x0, #(1 << 31)		/* 64bit EL1 */
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

	b kernel_main				/* Straight out to C I am not familiar enough with ARM64 assembler */
/*================================================================"
      Just safety incase C code ever returns back
"================================================================*/
hang:
	b hang
.balign	4
.ltorg							/* Tell assembler ltorg data for code above can go here */

.globl enable_irq
enable_irq:

    //clear/enable irq bit in PSTATE
    msr daifclr,#2
    ret

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

	bl	c_irq_handler

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

/****************************************************************
       	   DATA FOR SMARTSTART64  EXPOSED TO INTERFACE 
****************************************************************/
.section ".data.smartstart64", "aw"
.balign 4

.globl RPi_IO_Base_Addr;				// Make sure Pi_IO_Base_Addr label is global
RPi_IO_Base_Addr : .8byte 0;			// Peripheral Base addr is 8 byte variable in 64bit mode


