#include "rpi-smartstart.h"

/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{       Filename: smartstart.s									}
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

;@"****************************************************************"
;@      INTERNAL DATA FOR SMARTSTART NOT EXPOSED TO INTERFACE 
;@"****************************************************************"
.section ".data.smartstart", "aw"
.balign 4

RPi_BusAlias	: .4byte 0;				// Address offset between physical addressand ARM address needed for all DMA	
RPi_FrameBuffer : .4byte 0;				// The internal Graphics Frame Buffer for the graphics screen (The memory address of first pixel)
RPi_FramePitch : .4byte 0;				// The internal offset value between one line and next on the graphics screen 
RPi_SysFontPtr : .4byte Sys8x16BitFont;	// The internal pointer to current system font
WriteTextPtr:	 .4byte 0;				// The internal pointer to the current write text routine
ClearAreaPtr:	 .4byte 0;				// The internal pointer to the current clear area implementation
SetPixelPtr:	 .4byte 0;				// The internal pointer to the current set pixel implementation
RPi_disableCRLF: .4byte 0;				// The internal disable CRLF processing on graphics
RPi_grPosX:		 .4byte 0;				// The internal graphics console x position
RPi_grPosY:		 .4byte 0;				// The internal graphics console y position

.if (__ARM_ARCH == 6)					// Compiling for ARM6
;@"****************************************************************"
;@      ARM 6 BARRIER MACRO - PROVIDED REGISTER WILL BE TRASHED 
;@"****************************************************************"
.macro Memory_Barrier reg:req 
    mov \reg, #0 
	mcr p15,0,\reg,c7,c10,5
.endm
.else
;@"****************************************************************"
;@    ARM 7/8 BARRIER MACRO - REGISTER IGNORED (COMATABILITY ONLY)  
;@"****************************************************************"
.macro  Memory_Barrier reg
    dmb
.endm
.endif

/*==========================================================================}
;{				 	 ARM CPU MODE CONSTANT DEFINITIONS					    }
;{=========================================================================*/
#define CPU_FIQMODE 0x11						// CPU in FIQ mode
#define CPU_IRQMODE 0x12						// CPU in IRQ mode
#define CPU_SVCMODE 0x13						// CPU in SVC mode
#define CPU_HYPMODE 0x1A						// CPU in HYP mode

/*==========================================================================}
;{				 ARM CPU IRQ/FIQ BIT CONSTANT DEFINITIONS				    }
;{=========================================================================*/
#define I_Bit  (1 << 7)							// Irq flag bit in cpsr (CPUMODE register)
#define F_Bit  (1 << 6)							// Fiq flag bit in cpsr (CPUMODE register)

.section ".text.startup", "ax", %progbits
.balign	4
.globl _start
.syntax unified
.arm
_start:
	mov r12, pc;							;@ Hold boot address in high register R12 
	ldr sp, =__svc_stack					;@ Pi1/2 we will be in HYP_MODE might as well set stack pointer
;@"================================================================"
;@ Now we need to put the processor in a state we can work with. 
;@ The bootloader could have left the CPU in any operation mode.
;@ Currently that is usually HYP_MODE and here we want to also save
;@ that initial CPU boot mode and address we might need later.
;@"================================================================"
	ldr r1, =RPi_BootAddr					;@ Address to hold Boot address
	sub r12, #8								;@ Subtract op-code offset
	str r12, [r1]							;@ Save the boot address we started at
	mrs r2, CPSR							;@ Read current CPU mode
	ldr r1, =RPi_CPUBootMode				;@ Memory address to save this CPU boot mode
	str r2, [r1]							;@ Save the boot mode value to address
;@"================================================================"
;@ If the cpu is in HYP_MODE(EL2) we will bring it SVC_MODE (EL1).
;@"================================================================"
    mrs r0,cpsr								;@ Fetch the cpsr register which includes CPU mode bits 
 	and r1, r0, #0x1F						;@ Mask off the CPU mode bits to register r1                            
 	cmp r1, #CPU_HYPMODE					;@ Check we are in HYP_MODE											
	bne .NotInHypMode						;@ Branch if not equal meaning was not in HYP_MODE  
	bic r0,r0,#0x1F							;@ Clear the CPU mode bits in register r0							
	orr r0, r0, #CPU_SVCMODE | I_Bit | F_Bit;@ Logical OR SVC_MODE bits onto register with Irq/Fiq disabled	
    msr spsr_cxsf,r0						;@ Hold value in spsr_cxsf
    add lr,pc,#4							;@ Calculate address of .NotInHypMode label
	/* I borrowed this trick from Ultibo because ARM6 code running on an ARM7/8 needs this opcode  */
	/* The ARM6 compiler does not know these instructions so it is a way to get needed opcode here */
    /* So our ARM6 code can drop an arm7 or arm8 out of HYP mode and run on an ARM7/8.             */
 	/* Native ARM7/8 compilers already understand the OPCODE but do not mind it this way either	   */        
	.long 0xE12EF30E						;@ "msr ELR_hyp, lr" Set the address to ELR_hyp
	.long 0xE160006E						;@ "eret" Elevated return which will exit at .NotInHypMode in SVC_MODE
.NotInHypMode:
;@"================================================================"
;@ Now setup stack pointers for the different CPU operation modes.
;@"================================================================"
    ldr sp, =__svc_stack					;@ Set the stack pointer for SRV_MODE
    mrs r0,cpsr								;@ Fetch the cpsr register which includes CPU mode bits 
	bic r0,r0,#0x1F							;@ Clear the CPU mode bits in register r0							
	orr r0, r0, #CPU_FIQMODE | I_Bit | F_Bit;@ Logical OR FIQ_MODE bits onto register with Irq/Fiq disabled
    msr CPSR_c, r0							;@ Switch to FIQ_MODE
	ldr sp, =__fiq_stack					;@ Set the stack pointer for that mode
	bic r0,r0,#0x1F							;@ Clear the CPU mode bits in register r0	
	orr r0, r0, #CPU_IRQMODE | I_Bit | F_Bit;@ Logical OR IRQ_MODE bits onto register with Irq/Fiq disabled	
    msr CPSR_c, r0							;@ Switch to IRQ_MODE
    ldr sp, =__irq_stack					;@ Set the stack pointer for that mode
	bic r0,r0,#0x1F							;@ Clear the CPU mode bits in register r0							
	orr r0, r0, #CPU_SVCMODE | I_Bit | F_Bit;@ Logical OR SVC_MODE bits onto register with Irq/Fiq disabled	
    msr CPSR_c, r0							;@ Switch to SVC_MODE again all stacks ready to go
;@"================================================================"
;@ Fetch and hold CPU changed mode. If we changed modes this value
;@ will now reflect a change from the original held RPi_CPUBootMode.
;@"================================================================"
	ldr r1, =RPi_CPUCurrentMode				;@ Address to hold current mode
	str r0, [r1]							;@ Hold the current CPU mode
;@"================================================================"
;@ Read the Arm Main CPUID register => sets RPi_CpuId
;@"================================================================"
	ldr r1, =RPi_CpuId						;@ Address to hold CPU id
	mrc p15,0,r0,c0,c0,0					;@ Read Main ID Register
	str r0, [r1]							;@ Save CPU Id for interface 
;@"================================================================"
;@ Check if BC2835 and if so branch over multi-core park routine
;@"================================================================"
	ldr r1, =#ARM6_CPU_ID					;@ fetch ARM6_CPU_ID
	cmp r1, r0								;@ Check for match
	beq .cpu0_exit_multicore_park			;@ Branch as Arm6 has only 1 CPU 
;@"================================================================"
;@ Now park Core 1,2,3 into a deadloop on BCM2836, BCM2837
;@ If bootloader is used this will not happen but booting with the
;@ "OldKernel=1" from 0x0000 this can happen. Core 0 continues on.
;@"================================================================"
	mrc  p15, 0, r0, c0, c0, 5
	ands r0, r0, #0x3
	beq  .cpu0_exit_multicore_park
.reset_single_cn:
	b    SecondarySpin
.cpu0_exit_multicore_park:
;@"================================================================"
;@ Store the compiler mode in RPi_CompileMode
;@"================================================================"
	eor r0, r0, r0;							;@ Zero register
.if (__ARM_ARCH == 6)						// Compiling for ARM6
	mov r0, #0x06							;@ Compiled for ARM6 CPU
.endif
.if (__ARM_ARCH == 7)						// Compiling for ARM7
	mov r0, #0x07							;@ Compiled for ARM7 CPU
.endif
.if (__ARM_ARCH == 8)						// Compiling for ARM8
	mov r0, #0x08							;@ Compiled for ARM8 CPU
.endif
	ldr r1, =RPi_CompileMode				;@ Address to hold compile mode
	str r0, [r1]							;@ Hold the compiler mode  
;;@"================================================================"
;@ Try Auto-Detect Raspberry PI IO base address at 1st position
;@"================================================================"
	ldr r2, =#0x61757830
	ldr r1, =#0x20215010
	ldr r0, [r1]							;@ Fetch value at 0x20215010 being uart0
	cmp r2, r0;								;@ Check if we have the value the uart0 will be at reset
	bne .not_at_address_1
;@"================================================================"
;@  Raspberry PI IO base address was detected as 0x20000000
;@  RPi_IO_Base_Addr => 0x20000000
;@"================================================================"
	ldr r1, =RPi_BusAlias					;@ Address to hold bus alias
	mov	r0, #0x40000000						;@ Alias is 0x40000000 for a Pi1
	str	r0, [r1]							;@ Hold bus alias address
	ldr r1, =RPi_IO_Base_Addr				;@ Address to hold IO Base addr
	mov	r0, #0x20000000						;@ Pi1 base address is 0x20000000
	str	r0, [r1]							;@ Hold the detected address
	b .autodetect_done;						;@ Jump to reentry
;@"================================================================"
;@ Try Auto-Detect Raspberry PI IO base address at 2nd position
;@"================================================================"
.not_at_address_1:
	ldr r1, =#0x3f215010
	ldr r0, [r1]							;@ Fetch value at 0x3f215010
	cmp r2, r0								;@ Check if we have the value the uart0 will be at reset
	beq .At2ndAddress						;@ Pi2/3 found
;@"================================================================"
;@ ** Auto-Detected failed, not safe to do anything but deadloop **
;@ Would love to be display an error state but no ability on Pi
;@"================================================================"
.pi_detect_fail:
    b .pi_detect_fail
;@"================================================================"
;@  Raspberry PI IO base address was detected as 0x3f000000
;@  RPi_IO_Base_Addr => 0x3f000000
;@"================================================================"
.At2ndAddress:
	ldr r1, =RPi_BusAlias					;@ Address to hold bus alias
	mov	r0, #0xC0000000						;@ Alias is 0xC0000000 for Pi2/3
	str	r0, [r1]							;@ Hold bus alias
	ldr r1, =RPi_IO_Base_Addr				;@ Address to hold IO Base addr
	mov	r0, #0x3F000000						;@ Pi2/3 base address is 0x3F000000
	str	r0, [r1]							;@ Hold the detected address
.autodetect_done:
;@"================================================================"
;@  We are getting close to handing over to C so we need to copy the 
;@  ISR table to position 0x0000 so interrupts can be used if wanted 
;@"================================================================"
	ldr r0, = _isr_Table					;@ Address of isr_Table
	mov     r1, #0x0000						;@ Destination 0x0000
    ldmia   r0!,{r2, r3, r4, r5, r6, r7, r8, r9}
    stmia   r1!,{r2, r3, r4, r5, r6, r7, r8, r9}
    ldmia   r0!,{r2, r3, r4, r5, r6, r7, r8, r9}
    stmia   r1!,{r2, r3, r4, r5, r6, r7, r8, r9}
;@"================================================================"
;@ Now Clear the .BSS segment as the C compiler expects us to do
;@"================================================================"
	ldr   r0, =__bss_start__				;@ Load BSS start address
	ldr   r1, =__bss_end__					;@ Load BSS end address
	mov   r2, #0							;@ Value to write being zero
.clear_bss:
    cmp   r0, r1							;@ Check if start = end
    bge   .clear_bss_exit					;@ If so exit
    str   r2, [r0]							;@ Store the zero 
	add   r0, r0, #4						;@ Increment start
    b .clear_bss							;@ Loop around to fill next
.clear_bss_exit:
@"================================================================"
;@ PI NSACR regsister setup for access to floating point unit
;@ Cortex A-7 => Section 4.3.34. Non-Secure Access Control Register
;@ Cortex A-53 => Section 4.5.32. Non-Secure Access Control Register
;@"================================================================"
	mrc p15, 0, r0, c1, c1, 2				;@ Read NSACR into R0
	cmp r0, #0x00000C00						;@ Access turned on or in AARCH32 mode and can not touch register or EL3 fault
	beq .free_to_enable_fpu
	orr r0, r0, #0x3<<10					;@ Set access to both secure and non secure modes
	mcr p15, 0, r0, c1, c1, 2				;@ Write NSACR
;@"================================================================"
;@ Bring fpu online
;@"================================================================"
.free_to_enable_fpu:
	mrc p15, 0, r0, c1, c0, #2				;@ R0 = Access Control Register
	orr r0, #(0x300000 + 0xC00000)			;@ Enable Single & Double Precision
	mcr p15,0,r0,c1,c0, #2					;@ Access Control Register = R0
	mov r0, #0x40000000						;@ R0 = Enable VFP
	vmsr fpexc, r0							;@ FPEXC = R0
;@"================================================================"
;@ Enable L1 cache
;@"================================================================"
#define SCTLR_ENABLE_DATA_CACHE			0x4
#define SCTLR_ENABLE_BRANCH_PREDICTION	0x800
#define SCTLR_ENABLE_INSTRUCTION_CACHE  0x1000

    mrc p15,0,r0,c1,c0,0					;@ R0 = System Control Register
    orr r0, #SCTLR_ENABLE_BRANCH_PREDICTION	;@ Enable branch prediction
    orr r0, #SCTLR_ENABLE_DATA_CACHE		;@ Enable data cache
    orr r0, #SCTLR_ENABLE_INSTRUCTION_CACHE	;@ Enable instruction cache
    mcr p15,0,r0,c1,c0,0					;@ System Control Register = R0
;@"================================================================"
;@ Bring Core 1,2,3 to secondary spin if not an ARM6
;@"================================================================"
	mrc p15,0,r0,c0,c0,0					;@ Read Main ID Register
	ldr r1, =#ARM6_CPU_ID					;@ fetch ARM6_CPU_ID
	cmp r1, r0								;@ Check for match
	beq .NoMultiCore						;@ ARM6 jumps as no multicore
    ldr r3, =CoreSetupACK					;@ Address of CoreSetupACK .. ACK core setup	
 	mov	r1, #1073741824						;@ 0x40000000
	mov	r0, #0
    ldr r2, =ExtraCoreSetup					;@ Address of ExtraCoreSetup call
	sub	sp, sp, #12
	str	r0, [r3]							;@ Zero CoreSetupACK
	str	r2, [r1, #156]						;@ Write ExtraCoreSetup to 0x4000009C which signals core1 to jump
.WaitCore1ACK:
	ldr	r1, [r3]							;@ Read CoreSetupACK
	cmp	r1, #0								;@ check for ACK
	beq	.WaitCore1ACK						;@ No ACK read again
 	mov	r1, #1073741824						;@ 0x40000000
	mov	r0, #0
	str	r0, [r3]							;@ Zero CoreSetupACK
	str	r2, [r1, #172]						;@ Write ExtraCoreSetup to 0x400000AC which signals core2 to jump
.WaitCore2ACK:
	ldr	r1, [r3]							;@ Read CoreSetupACK
	cmp	r1, #0								;@ check for ACK
	beq	.WaitCore2ACK						;@ No ACK read again
 	mov	r1, #1073741824						;@ 0x40000000
	mov	r0, #0
	str	r0, [r3]							;@ Zero CoreSetupACK
	str	r2, [r1, #188]						;@ Write ExtraCoreSetup to 0x400000BC which signals core3 to jump
.WaitCore3ACK:
	ldr	r1, [r3]							;@ Read CoreSetupACK
	cmp	r1, #0								;@ check for ACK
	beq	.WaitCore3ACK						;@ No ACK read again
.NoMultiCore:
;@"================================================================"
;@ Kick screen & display message
;@"================================================================"
	ldr r0, =RPi_GraphWidth
	ldr r1, =RPi_GraphHeight
	ldr r2, =RPi_GraphColorDepth
	bl RPI_GetGraphMode
	cmp r0, #0
    beq .GraphModeFailed;
	ldr r0, =RPi_GraphWidth
	ldr r0, [r0]
	ldr r1, =RPi_GraphHeight 
	ldr r1, [r1]
	ldr r2, =RPi_GraphColorDepth
	ldr r2, [r2]
	bl RPI_InitGraph
.GraphModeFailed:
;@"================================================================"
;@ Finally that all done jump to the C compiler entry point
;@"================================================================"
   	 bl kernel_main
hang:
	b hang
.balign	4
.ltorg									;@ Tell assembler ltorg data for this code can go here
CoreSetupACK : .4byte 0;

_isr_Table:
    ldr pc, _reset_h
    ldr pc, _undefined_instruction_vector_h
    ldr pc, _software_interrupt_vector_h
    ldr pc, _prefetch_abort_vector_h
    ldr pc, _data_abort_vector_h
    ldr pc, _unused_handler_h
    ldr pc, _interrupt_vector_h
    ldr pc, _fast_interrupt_vector_h

_reset_h:                           .word   _start
_undefined_instruction_vector_h:    .word  hang
_software_interrupt_vector_h:       .word   hang
_prefetch_abort_vector_h:           .word   hang
_data_abort_vector_h:               .word   hang
_unused_handler_h:                  .word   _start
_interrupt_vector_h:                .word   c_irq_handler
_fast_interrupt_vector_h:           .word   hang	

/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{   Spin loop same as the STUB does but tolerant on registers R0-R3 for C   }
{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
SecondarySpin:
	mrc     p15, 0, r0, c0, c0, 5
	ubfx    r0, r0, #0, #2					// Read core id and make a bit mask in R0 
	ldr r5, =mbox		
	ldr r5, [r5]		@ mbox
	mov	r3, #0			@ magic
	add	r5, #(0x400000CC-0x4000008C)	@ mbox
1:
	ldr	r4, [r5, r0, lsl #4]
	cmp	r4, r3
	beq	1b
@ clear mailbox
	str	r4, [r5, r0, lsl #4]
	mov	r0, #0
	ldr r1, =machid		
	ldr r1, [r1]		@ BCM2708 machine id
	ldr r2, = atags		
	ldr r2, [r2]		@ ATAGS
	ldr lr, =SecondarySpin
	bx	r4
	b SecondarySpin
mbox: 	.4byte 0x4000008C
machid:	.4byte 3138
atags:  .4byte 0x100




/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{				 Routine Stub that does setup on Core 1,2,3					}
{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
ExtraCoreSetup:
;@"================================================================"
;@ If the cpu is in HYP_MODE(EL2) we will bring it SVC_MODE (EL1).
;@"================================================================"
    mrs r0,cpsr								;@ Fetch the cpsr register which includes CPU mode bits 
 	and r1, r0, #0x1F						;@ Mask off the CPU mode bits to register r1                            
 	cmp r1, #0x1A							;@ check we are in HYP_MODE AKA register reads 1A											
	bne .NotInHypMode1						;@ Branch if not equal meaning was not in HYP_MODE  
	bic r0,r0,#0x1F							;@ Clear the CPU mode bits in register r0							
   	orr r0,r0,#0x13							;@ Logical OR SVC_MODE bits onto register
    msr spsr_cxsf,r0						;@ Hold value in spsr_cxsf
    add lr,pc,#4							;@ Calculate address of .NotInHypMode label
	/* I borrowed this trick from Ultibo because ARM6 code running on an ARM7/8 needs this opcode  */
	/* The ARM6 compiler does not know these instructions so it is a way to get needed opcode here */
    /* So our ARM6 code can drop an arm7 or arm8 out of HYP mode and run on an ARM7/8.             */
 	/* Native ARM7/8 compilers already understand the OPCODE but do not mind it this way either	   */        
	.long 0xE12EF30E						;@ "msr ELR_hyp, lr" Set the address to ELR_hyp
	.long 0xE160006E						;@ "eret" Elevated return which will exit at .NotInHypMode in SVC_MODE
.NotInHypMode1:
;@"================================================================"
;@ Now setup stack pointers for the different CPU operation modes.
;@"================================================================"
	mrc     p15, 0, r4, c0, c0, 5
	ubfx    r4, r4, #0, #2					// Read core id and make a bit mask in R2
    ldr r1, = __svc_stack_core1				;@ Address of svc_stack_core1 stack pointer value
    ldr r2, = __fiq_stack_core1				;@ Address of fiq_stack_core1 stack pointer value
    ldr r3, = __irq_stack_core1				;@ Address of irq_stack_core1 stack pointer value
	cmp r4, #1								;@ Check cpu id for core 1
	beq set_svc_stack						;@ This is core 1 so set svc_stack
    ldr r1, = __svc_stack_core2				;@ Address of svc_stack_core2 stack pointer value
    ldr r2, = __fiq_stack_core2				;@ Address of fiq_stack_core2 stack pointer value
    ldr r3, = __irq_stack_core2				;@ Address of irq_stack_core2 stack pointer value
	cmp r4, #2								;@ Check cpu id for core 2
	beq set_svc_stack						;@ This is core 2 so set svc_stack
    ldr r1, = __svc_stack_core3				;@ Address of svc_stack_core3 stack pointer value
    ldr r2, = __fiq_stack_core3				;@ Address of fiq_stack_core3 stack pointer value
    ldr r3, = __irq_stack_core3				;@ Address of irq_stack_core4 stack pointer value
set_svc_stack:
	mov sp, r1								;@ Set the stack pointer for SVC_MODE 
    mrs r0,cpsr								;@ Fetch the cpsr register which includes CPU mode bits 
	bic r0,r0,#0x1F							;@ Clear the CPU mode bits in register r0							
	orr r0, r0, #CPU_FIQMODE | I_Bit | F_Bit;@ Logical OR FIQ_MODE bits onto register with Irq/Fiq disabled
    msr CPSR_c, r0							;@ Switch to FIQ_MODE
	mov sp, r2								;@ Set the stack pointer for FIQ_MODE 
	bic r0,r0,#0x1F							;@ Clear the CPU mode bits in register r0	
	orr r0, r0, #CPU_IRQMODE | I_Bit | F_Bit;@ Logical OR IRQ_MODE bits onto register with Irq/Fiq disabled	
    msr CPSR_c, r0							;@ Switch to IRQ_MODE
	mov sp, r3								;@ Set the stack pointer for IRQ_MODE 
	bic r0,r0,#0x1F							;@ Clear the CPU mode bits in register r0							
	orr r0, r0, #CPU_SVCMODE | I_Bit | F_Bit;@ Logical OR SVC_MODE bits onto register with Irq/Fiq disabled	
    msr CPSR_c, r0							;@ Switch to SVC_MODE again all stacks ready to go
@"================================================================"
;@ PI NSACR regsister setup for access to floating point unit
;@ Cortex A-7 => Section 4.3.34. Non-Secure Access Control Register
;@ Cortex A-53 => Section 4.5.32. Non-Secure Access Control Register
;@"================================================================"
	mrc p15, 0, r0, c1, c1, 2				;@ Read NSACR into R0
	cmp r0, #0x00000C00						;@ Access turned on or in AARCH32 mode and can not touch register or EL3 fault
	beq .free_to_enable_fpu1
	orr r0, r0, #0x3<<10					;@ Set access to both secure and non secure modes
	mcr p15, 0, r0, c1, c1, 2				;@ Write NSACR
;@"================================================================"
;@ Bring fpu online
;@"================================================================"
.free_to_enable_fpu1:
	mrc p15, 0, r0, c1, c0, #2				;@ R0 = Access Control Register
	orr r0, #(0x300000 + 0xC00000)			;@ Enable Single & Double Precision
	mcr p15,0,r0,c1,c0, #2					;@ Access Control Register = R0
	mov r0, #0x40000000						;@ R0 = Enable VFP
	vmsr fpexc, r0							;@ FPEXC = R0
;@"================================================================"
;@ Enable L1 cache
;@"================================================================"
    mrc p15,0,r0,c1,c0,0					;@ R0 = System Control Register

    /* Enable caches and branch prediction */
    orr r0, #SCTLR_ENABLE_BRANCH_PREDICTION
    orr r0, #SCTLR_ENABLE_DATA_CACHE
    orr r0, #SCTLR_ENABLE_INSTRUCTION_CACHE

    mcr p15,0,r0,c1,c0,0					;@ System Control Register = R0
;@"================================================================"
;@ Acknowledge stacks set by clearing the values
;@"================================================================"
	mov r0, #1
	ldr r1, =CoreSetupACK					;@ Core setup ACK address
	str r0, [r1]							;@ Set the acknowledge
	ldr lr, =SecondarySpin					;@ Load secondary spin address
	bx lr									;@ Always return to secondary spin	
	bl SecondarySpin						;@ Just safety .. to be sure to be sure









#define MAIL_TAGS 8

/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{        ACTIVITY-LED HELPER ROUTINES PROVIDE BY RPi-SmartStart API         }
{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/

/* "PROVIDE C FUNCTION: void RPI_Activity_Led (bool On);" */
.section .text.RPI_Activity_Led, "ax", %progbits
.balign	4
.globl RPI_Activity_Led;		
.type RPI_Activity_Led, %function
.syntax unified
.arm
;@"================================================================"
;@ Activity_Led -- Composite Pi1, Pi2 & Pi3 code
;@ C Function: void RPI_Activity_Led (bool On)
;@ Entry: R0 will have bool state to set LED on or off
;@"================================================================"
RPI_Activity_Led:
 .if !(__ARM_ARCH == 8)						// Only ARM 6/7 compile this code
    push {r4 }
 	ldr r1, =RPi_CpuId
	ldr r1, [r1]							;@ R1 is carrying CPUID  
	mov r2, #16;							;@ R2 is carrying GPIO Port 16 mask roll
	mov r4, #0
	ldr r3, =#ARM6_CPU_ID					;@ CPU arm6 id
	cmp r1, r3
	beq Pi1_OR_2_Activity_Led				;@ Arm6 so Pi1 board go straight to Led set code
	mov r2, #(47-32);						;@ R2 is carrying GPIO Port 47 mask roll
	mov r4, #4
	ldr r3, =#ARM7_CPU_ID					;@ CPU arm7 id
	cmp r1, r3
	beq Pi1_OR_2_Activity_Led				;@ Arm7 so Pi2 board go straight to Led set code
	pop {r4 }
.endif
	mov r3, r0								;@ Hold on/off request in r3
	ldr r0, =FB_ACTLED_STRUCT				;@ FB_ACTLED_STRUCT ADDRESS
	;@ Response buffer will be trashed in last response .. need to zero it 
	add r1, r0, #4							;@ Response address in that struct
	eor r2, r2, r2							;@ Zero r2 register
	str r2, [r1]							;@ Write that to response element in FB_STRUCT
	;@ Value buffer will be trashed .. reload values port=130, state = from callee R0 
	add r1, r0, #0x14						;@ Address of 1st value buffer in FB_STRUCT	
	mov r2, #130
	stmia r1!,{r2,r3}						;@ write Port and On/off request to value buffers
     ;@ okay now send it to mailbox
 	ldr r1, =RPi_IO_Base_Addr
	ldr r1, [r1]   
	cmp r1, #536870912
    orreq r0, r0, #1073741824
    orrne r0, r0, #-1073741824
	bic r0, r0, #0x0F						;@ Make sure low four bits for channel are clear
	orr r0, #MAIL_TAGS						;@ OR in channel as MAIL_TAGS CHANNEL
	ldr r2, =#MAIL_BASE_OFFSET
	add r1, r1, r2;
.mailboxfullwait:
    Memory_Barrier r2
	ldr r3, [r1, #MAIL_STATUS_OFFS]			;@ Mail status
    Memory_Barrier r2
    cmp r3, #0
    blt .mailboxfullwait
	str r0,[r1, #MAIL_WRITE_OFFS]			;@ Mail Box Write
.waitforresponse:	
	ldr r3, [r1, #MAIL_STATUS_OFFS]			;@ Mail status	
    Memory_Barrier r2
	ands r3, r3, #1073741824  
	bne .waitforresponse	
	ldr r3,[r1, #MAIL_READ_OFFS]			;@ Mail Box Read
	Memory_Barrier r2
    and r3, r3, #15
    cmp r3, #8
    bne .waitforresponse
	bx  lr									;@ Return
;@"****************************************************************"
;@ ARM 6/7 - SPECIFIC CODE FOR ORIGINAL PI 1 & 2 BOARD ACTIVITY LED 
;@"****************************************************************"
.if !(__ARM_ARCH == 8)						// Only ARM 6/7 compile this code
;@"================================================================"
;@ Pi1_OR_2_Activity_Led -- Pi1 & 2 code
;@ C Function: void Activity_Led (bool On)
;@ Entry: R0 will have bool state to set, R2 = GPIO Port Number
;@"================================================================"
Pi1_OR_2_Activity_Led:
    mov r3, #0x1C							;@ GPIO_BIT_SET OFFSET
    cmp r0, #1
	bne .Pi1_Led_On     
	mov r3, #0x28							;@ GPIO_BIT_CLR_OFFSET
.Pi1_Led_On:
	add r3, r4								;@ add +4 offset for Pi2
	ldr r1, =RPi_IO_Base_Addr
	ldr r1, [r1]
	add r1, r1, #0x200000
	mov r0, #1
	lsl r0, r0, r2							;@ Create a bit mask of the port number
	str r0, [r1, r3]						;@ Write bit shifted to position to port
	pop { r4 }
	bx   lr									;@ Return.
.endif
.balign	4
.ltorg										;@ Tell assembler its ok to put ltorg data for above code here
.size	RPI_Activity_Led, .-RPI_Activity_Led

.section .data1.mailbox.activityled, "aw"
;@ Mailbox Property Interface Buffer Structure
.type FB_ACTLED_STRUCT, %object
.balign 16
FB_ACTLED_STRUCT:
  .4byte (FB_ACTLED_STRUCT_END - FB_ACTLED_STRUCT);@ Buffer Size In Bytes (Including The Header Values, The End Tag And Padding)
  .4byte 0x00000000							;@ Buffer Request/Response Code
  .4byte 0x00038041							;@ Tag Identifier MAILBOX_TAG_SET_GPIO_STATE = 0x00038041
  .4byte 0x00000008							;@ Value Buffer Size In Bytes
  .4byte 0x00000008							;@ 1 bit (MSB) Request/Response Indicator (0=Request, 1=Response), 31 bits (LSB) Value Length In Bytes
  .4byte 130								;@ Pin 130 for activity led
  .4byte 1									;@ 1 for on   0 for off
.4byte   0x00000000							;@ 0x0 (End Tag)
FB_ACTLED_STRUCT_END:
.size	FB_ACTLED_STRUCT, .-FB_ACTLED_STRUCT

/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{      TIMER CONTROLLER HELPER ROUTINES PROVIDE BY RPi-SmartStart API       }
{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/

/* "PROVIDE C FUNCTION: void RPI_WaitMicroSeconds (uint64_t delay);" */
.section .text.RPI_WaitMicroSeconds, "ax", %progbits
.balign	4
.globl RPI_WaitMicroSeconds;		
.type RPI_WaitMicroSeconds, %function
.syntax unified
.arm
;@"================================================================"
;@ RPI_WaitMicroSeconds -- Composite Pi1, Pi2 & Pi3 code
;@ C Function: void RPI_WaitMicroSeconds (uint64_t)
;@ Entry: R0, R1 will have delay value
;@"================================================================"
RPI_WaitMicroSeconds:
        stmfd   sp!, {r4, r8, r9}
        mov     r8, r0
        mov     r9, r1						;@ Hold delay in r8 & r9
        ldr     r3, =RPi_IO_Base_Addr
        ldr     r3, [r3]
        add     r3, r3, #0x3000
.HiTimerMoved:
        Memory_Barrier r0
		ldr     r2, [r3, #8]				;@ Read timer hi count
        ldr     r4, [r3, #4]				;@ Read timer lo count
        ldr     r1, [r3, #8]				;@ Re-Read timer hi count
        Memory_Barrier r0
        cmp     r2, r1
        bne     .HiTimerMoved
        adds    r8, r8, r4;					;@ Add least significant 32 bits
		adcs    r9, r9, r1;					;@ Add the high 32 bits with carry (Adds current time to us delay .. creating timeout value )
.HiTimerMoved1:
		Memory_Barrier r0
        ldr     r2, [r3, #8]				;@ Read timer hi count
        ldr     r4, [r3, #4]				;@ Read time lo count
        ldr     r1, [r3, #8]				;@ Re-raed timer hi count
        Memory_Barrier r0
        cmp     r2, r1
        bne     .HiTimerMoved1
		cmp     r1, r9
        cmpeq   r4, r8
		bcc		.HiTimerMoved1				;@ Timeout not reached
        ldmfd   sp!, {r4, r8, r9}
		bx lr;
.balign	4
.ltorg										;@ Tell assembler ltorg data for this code can go here
.size	RPI_WaitMicroSeconds, .-RPI_WaitMicroSeconds


/* "PROVIDE C FUNCTION: uint64_t RPI_GetArmTickCount (void);" */
.section .text.RPI_GetArmTickCount, "ax", %progbits
.balign	4
.globl RPI_GetArmTickCount;		
.type RPI_GetArmTickCount, %function
.syntax unified
.arm
;@"================================================================"
;@ RPI_GetArmTickCount -- Composite Pi1, Pi2 & Pi3 code
;@ C Function: uint64_t RPI_GetArmTickCount (void)
;@ Return: R0, R1 will have tickcount value
;@"================================================================"
RPI_GetArmTickCount:
		stmfd   sp!, {r4, lr}
        ldr     r3, =RPi_IO_Base_Addr
        ldr     r3, [r3]					
        add     r3, r3, #0x3000
.HiTimerMoved2:
		Memory_Barrier r4
 		ldr     r2, [r3, #8]				;@ Read timer hi count
        ldr     r0, [r3, #4]				;@ Read timer lo count
        ldr     r1, [r3, #8]				;@ Re-Read timer hi count
        Memory_Barrier r4
		cmp     r2, r1
        bne     .HiTimerMoved2				;@ Check both hi count reads were same
        ldmfd   sp!, {r4, pc}
.balign	4
.ltorg										;@ Tell assembler ltorg data for this code can go here
.size	RPI_GetArmTickCount, .-RPI_GetArmTickCount


/* "PROVIDE C FUNCTION: uint64_t RPI_TickDifference (uint64_t original_tick, uint64_t new_tick);" */
.section .text.RPI_TickDifference, "ax", %progbits
.balign	4
.globl RPI_TickDifference;		
.type RPI_TickDifference, %function
.syntax unified
.arm
;@"================================================================"
;@ RPI_TickDifference -- Composite Pi1, Pi2 & Pi3 code
;@ C Function: uint64_t RPI_TickDifference (uint64_t original_tick, uint64_t new_tick)
;@ Entry: R0,R1 = Original_Tick   R2,R3 = New_Tick   (This is clock roll aware AKA new_tick < original_tick)
;@ Return: R0, R1 will have tickcount difference value
;@"================================================================"
RPI_TickDifference:
     subs    r0, r2, r0	
     sbc     r1, r3, r1						;@ Yes it looks crazy simple ... its a sign flag bit bash trick .. and it works
     bx      lr
.balign	4
.ltorg										;@ Tell assembler ltorg data for this code can go here
.size	RPI_TickDifference, .-RPI_TickDifference


/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{			MEMORY HELPER ROUTINES PROVIDE BY RPi-SmartStart API		    }
{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/

/* "PROVIDE C FUNCTION: uint32_t RPI_ARMaddressToBUSaddress (void* ARMaddress);" */
.section .text.RPI_ARMaddressToBUSaddress, "ax", %progbits
.balign	4
.globl RPI_ARMaddressToBUSaddress;		
.type RPI_ARMaddressToBUSaddress, %function
.syntax unified
.arm
;@"================================================================"
;@ RPI_ARMaddressToBUSaddress -- Composite Pi1, Pi2 & Pi3 code
;@ C Function: uint32_t RPI_ARMaddressToBUSaddress (void* ARMaddress);
;@ Entry: R0 will have ARMAddress value
;@"================================================================"
RPI_ARMaddressToBUSaddress:
	ldr r1, =RPi_BusAlias
    ldr r1,[r1]								;@ Fetch bus alias	
	orr r0, r0, r1							;@ Create bus address
	bx   lr									;@ Return
.balign	4
.ltorg										;@ Tell assembler ltorg data for this code can go here
.size	RPI_ARMaddressToBUSaddress, .-RPI_ARMaddressToBUSaddress


/* "PROVIDE C FUNCTION: uint32_t RPI_BUSaddressToARMaddress (void* BUSaddress);" */
.section .text.RPI_BUSaddressToARMaddress, "ax", %progbits
.balign	4
.globl RPI_BUSaddressToARMaddress;		
.type RPI_BUSaddressToARMaddress, %function
.syntax unified
.arm
;@"================================================================"
;@ RPI_BUSaddressToARMaddress -- Composite Pi1, Pi2 & Pi3 code
;@ C Function: uint32_t RPI_BUSaddressToARMaddress (void* BUSaddress);
;@ Entry: R0 will have BUSAddress value
;@"================================================================"
RPI_BUSaddressToARMaddress:
	ldr r1, =RPi_BusAlias
    ldr r1,[r1]								;@ Fetch bus alias	
	bic r0, r0, r1							;@ Create arm address
	bx   lr									;@ Return
.balign	4
.ltorg										;@ Tell assembler ltorg data for this code can go here
.size	RPI_BUSaddressToARMaddress, .-RPI_BUSaddressToARMaddress


/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{			MAILBOX HELPER ROUTINES PROVIDE BY RPi-SmartStart API		    }
{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/

/* "PROVIDE C FUNCTION: uint32_t RPI_MailboxWrite (MAILBOX_CHANNEL channel, uint32_t value);" */
.section .text.RPI_MailboxWrite, "ax", %progbits
.balign	4
.globl RPI_MailboxWrite;		
.type RPI_MailboxWrite, %function
.syntax unified
.arm
;@"================================================================"
;@ RPI_MailboxWrite -- Composite Pi1, Pi2 & Pi3 code
;@ C Function: uint32_t RPI_MailboxWrite (MAILBOX_CHANNEL channel, uint32_t value);
;@ Entry: R0 will have channel, R1 will have value
;@"================================================================"
RPI_MailboxWrite:
	stmfd   sp!, {r4, lr}
  	bic r1, r1, #0x0F						;@ Make sure low four bits for channel are clear
	and r4, r0, #0x0F						;@ Make sure upper channel bits are clear and hold result in R4
	orr r0, r1, r4							;@ ORR channel and value together to R0
 	ldr r1, =RPi_IO_Base_Addr
	ldr r1, [r1]							;@ PI IO base address 
	ldr r2, =#MAIL_BASE_OFFSET				
	add r1, r1, r2;							;@ Add mail offset to IO base
.mailboxfullwaiting:
    Memory_Barrier r2
	ldr r3, [r1, #MAIL_STATUS_OFFS]			;@ Mail status
    Memory_Barrier r2
    cmp r3, #0
    blt .mailboxfullwaiting
	str r0,[r1, #MAIL_WRITE_OFFS]			;@ Mail Box Write
.waitformailboxresponse:	
	ldr r3, [r1, #MAIL_STATUS_OFFS]			;@ Mail status	
    Memory_Barrier r2
	ands r3, r3, #1073741824  
	bne .waitformailboxresponse	
	ldr r3,[r1, #MAIL_READ_OFFS]			;@ Mail Box Read
	Memory_Barrier r2
    mov r0, r3								;@ xfer mailbox response for return
	and r3, r3, #15							;@ Cleave all but channel 
    cmp r3, r4								;@ Check response is from channel we sent
    bne .waitformailboxresponse
	ldmfd   sp!, {r4, pc}					;@ Return
.balign	4
.ltorg										;@ Tell assembler ltorg data for this code can go here
.size	RPI_MailboxWrite, .-RPI_MailboxWrite


/* "PROVIDE C FUNCTION: bool RPI_MailtagExchange4 (uint32_t* result, uint32_t tagid, uint32_t value);" */
.section .text.RPI_MailtagExchange4, "ax", %progbits
.balign	4
.globl RPI_MailtagExchange4;		
.type RPI_MailtagExchange4, %function
.syntax unified
.arm
;@"================================================================"
;@ RPI_MailtagExchange4 -- Composite Pi1, Pi2 & Pi3 code
;@ C Function: bool RPI_MailtagExchange4 (uint32_t* result, uint32_t tagid, uint32_t value);
;@ Entry: R0 result ptr, R1 = tagid, R2 = value 
;@"================================================================"
RPI_MailtagExchange4:
        ldr     r3, =RPi_IO_Base_Addr
        stmfd   sp!, {r4, r5, r6, lr}
        ldr     lr, [r3]					;@ Fetch pi base address
        mov     r6, r0						;@ Hold r0 pointer in r6
        ldr     ip, =FB_TAG4EXCHANGE_STRUCT	;@ Fetch address of structure
        mov     r0, #0
        str     r0, [ip, #4]				;@ Clear response value, might be corrupt from previous call
        str     r1, [ip, #8]				;@ Set the tagid provided
        mov     r0, #4
        str     r0, [ip, #16]				;@ Clear response value, might be corrupt from previous call
        str     r2, [ip, #20]				;@ Set the value provided
        cmp     lr, #0x20000000
        orreq   r5, ip, #0x40000000			;@ ORR value with 0x40000000
        orrne   r5, ip, #0xC0000000			;@ ORR value with 0xC0000000
		ldr		r0, =#MAIL_BASE_OFFSET		;@ Fetch mail base from io base offset
        add     r4, lr, r0					;@ Mailbox base IO offset
        bic     r5, r5, #0xF				;@ Make sure channel is clear
        orr     r5, r5, #MAIL_TAGS			;@ ORR tags channel onto value	
.CheckMailboxNotFull4xchg:
        Memory_Barrier r0
        ldr     r3, [r4, #MAIL_STATUS_OFFS]	;@ Read mailbox status
        Memory_Barrier r0
        cmp     r3, #0
        blt     .CheckMailboxNotFull4xchg	;@ Branch if mailbox full (aka status = 0x80000000)
        str     r5, [r4, #MAIL_WRITE_OFFS]	;@ Write Register 7 to mailbox write register
.WaitForMailResponse4xchg:
        Memory_Barrier r0
        ldr     r3, [r4, #MAIL_STATUS_OFFS]	;@ Read mailbox status
        Memory_Barrier r0
        ands    r3, r3, #MAIL_EMPTY			;@ Check mailbox not empty
        bne     .WaitForMailResponse4xchg	;@ If empty repeat read of status
        ldr     r3, [r4, #MAIL_READ_OFFS]	;@ If not empty read mailbox result
        Memory_Barrier r0
        and     r3, r3, #15					;@ Clear all but tag
        cmp     r3, #MAIL_TAGS				;@ check its a mail tage response
        bne     .WaitForMailResponse4xchg	;@ If not mail-tag channel response try again 
        ldr     r0, [ip, #4]				;@ Fetch response written in FB_GET_SCREEN_STRUCT				
        cmp     r0, #0x80000000				;@ Check for response flag
        beq     .Exchange4Replied		    ;@ Continue on if valid response
.Exchange4Failed:
        mov     r0, #0						;@ We will return false
        ldmfd   sp!, {r4, r5, r6, pc}		;@ return from this call
.Exchange4Replied:
        ldr     r0, [ip, #16]				;@ Fetch response to exchange 4 request
        cmp     r0, #0x80000004				;@ It should be 0x80000004
        bne     .Exchange4Failed			;@ Fail if not that value
        cmp     r6, #0						;@ Check if pointer not null
        ldrne   r0, [ip, #20]				;@ If pointer not null fetch
        strne   r0, [r6]					;@ Write to R6 which is address provide in R0 at start
        mov     r0, #1						;@ We will return true
        ldmfd   sp!, {r4, r5, r6, pc}		;@ return from this call
.balign	4
.ltorg										;@ Tell assembler ltorg data for this code can go here
.size	RPI_MailtagExchange4, .-RPI_MailtagExchange4

.section .data1.mailbox.tagexchange4, "aw"
;@ Mailbox Property Interface Buffer Structure
.type FB_TAG4EXCHANGE_STRUCT, %object
.balign 16
FB_TAG4EXCHANGE_STRUCT:
  .4byte (FB_TAG4EXCHANGE_STRUCT_END - FB_TAG4EXCHANGE_STRUCT);@ Buffer Size In Bytes (Including The Header Values, The End Tag And Padding)
  .4byte 0x00000000							;@ Buffer Request/Response Code
  .4byte 0x0								;@ Tag Identifier (RPI_FIRMWARE_xxxxx_xxxxxx)
  .4byte 0x00000004							;@ Value Buffer Size In Bytes
  .4byte 0x00000004							;@ 1 bit (MSB) Request/Response Indicator (0=Request, 1=Response), 31 bits (LSB) Value Length In Bytes
  .4byte 0									;@ 4 byte exchange
.4byte   0x00000000							;@ 0x0 (End Tag)
FB_TAG4EXCHANGE_STRUCT_END:
.size	FB_TAG4EXCHANGE_STRUCT, .-FB_TAG4EXCHANGE_STRUCT


/* "PROVIDE C FUNCTION: bool RPI_MailtagExchange8 (uint32_t* result1, uint32_t* result2, uint32_t tagid, uint32_t value1, uint32_t value2);" */
.section .text.RPI_MailtagExchange8, "ax", %progbits
.balign	4
.globl RPI_MailtagExchange8;		
.type RPI_MailtagExchange8, %function
.syntax unified
.arm
;@"================================================================"
;@ RPI_MailtagExchange8 -- Composite Pi1, Pi2 & Pi3 code
;@ C Function: bool RPI_MailtagExchange8 (uint32_t* result1, uint32_t* result2, uint32_t tagid, uint32_t value1, uint32_t value2);
;@ Entry: R0 result1 ptr, R1 result2 ptr, R2 = tagid, R3 = value1 , Stack = value2
;@"================================================================"
RPI_MailtagExchange8:
 		push	{r4, r5, r6, r7, r8, lr}
 		mov	ip, #0
 		mov	lr, #8
 		mov	r7, #32
 		ldr	r5, =RPi_IO_Base_Addr
 		ldr	r4, =FB_TAG812EXCHANGE_STRUCT
 		ldr	r5, [r5]
 		str	r7, [r4]
 		cmp	r5, #536870912
 		mov	r5, r1
 		ldr	r1, [sp, #24]
 		str	ip, [r4, #4]
 		mov	r6, r0
 		str	r2, [r4, #8]
 		mov	r0, #8
 		str	lr, [r4, #12]
 		str	lr, [r4, #16]
 		str	r3, [r4, #20]
 		str	r1, [r4, #24]
 		orreq	r1, r4, #1073741824
 		orrne	r1, r4, #-1073741824
 		str	ip, [r4, #28]
 		bl	RPI_MailboxWrite
 		cmp	r0, #0
 		popeq	{r4, r5, r6, r7, r8, pc}
 		ldr	r3, [r4, #4]
 		cmp	r3, #-2147483648
 		beq	.L18MailtagExchange8
.MailtagExchange8Fail:
 		mov	r0, #0
 		pop	{r4, r5, r6, r7, r8, pc}
.L18MailtagExchange8:
 		ldr	r3, [r4, #16]
 		cmp	r3, #-2147483640
 		bne	.MailtagExchange8Fail
 		cmp	r6, #0
 		ldrne	r3, [r4, #20]
 		strne	r3, [r6]
 		cmp	r5, #0
 		beq	.MailtagExchange8Success
 		ldr	r3, [r4, #24]
 		mov	r0, #1
 		str	r3, [r5]
.MailtagExchange8Success:
 		mov	r0, #1
 		pop	{r4, r5, r6, r7, r8, pc}
.balign	4
.ltorg										;@ Tell assembler ltorg data for this code can go here
.size	RPI_MailtagExchange8, .-RPI_MailtagExchange8
		

/* "PROVIDE C FUNCTION: bool RPI_MailtagExchange12 (uint32_t* result1, uint32_t* result2, uint32_t tagid, uint32_t value1, uint32_t value2, uint32_t value3);" */
.section .text.RPI_MailtagExchange12, "ax", %progbits
.balign	4
.globl RPI_MailtagExchange12;		
.type RPI_MailtagExchange12, %function
.syntax unified
.arm
;@"================================================================"
;@ RPI_MailtagExchange12 -- Composite Pi1, Pi2 & Pi3 code
;@ C Function: bool RPI_MailtagExchange12 (uint32_t* result1, uint32_t* result2, uint32_t tagid, uint32_t value1, uint32_t value2, uint32_t value3);
;@ Entry: R0 result1 ptr, R1 result2 ptr, R2 = tagid, R3 = value1, tsack = value2, value3
;@"================================================================"
RPI_MailtagExchange12:
 		push	{r4, r5, r6, r7, r8, lr}
 		mov	ip, #0
 		mov	r8, #36
 		mov	lr, #8
 		mov	r7, #12
 		ldr	r5, =RPi_IO_Base_Addr
 		ldr	r4, =FB_TAG812EXCHANGE_STRUCT
 		ldr	r5, [r5]
 		str	r8, [r4]
 		cmp	r5, #536870912
 		mov	r5, r1
 		ldr	r1, [sp, #24]
 		str	ip, [r4, #4]
 		str	r2, [r4, #8]
 		ldr	r2, [sp, #28]
 		str	r7, [r4, #12]
 		mov	r6, r0
 		str	lr, [r4, #16]
 		mov	r0, #8
 		str	r3, [r4, #20]
 		str	r1, [r4, #24]
 		orreq	r1, r4, #1073741824
 		orrne	r1, r4, #-1073741824
 		str	r2, [r4, #28]
 		str	ip, [r4, #32]
 		bl	RPI_MailboxWrite
 		cmp	r0, #0
 		popeq	{r4, r5, r6, r7, r8, pc}
 		ldr	r3, [r4, #4]
 		cmp	r3, #-2147483648
 		beq	.L34MailtagExchange12
.MailtagExchange12Fail:
 		mov	r0, #0
 		pop	{r4, r5, r6, r7, r8, pc}
.L34MailtagExchange12:
 		ldr	r3, [r4, #16]
 		cmp	r3, #-2147483640
 		bne	.MailtagExchange12Fail
 		cmp	r6, #0
 		ldrne	r3, [r4, #20]
 		strne	r3, [r6]
 		cmp	r5, #0
 		beq	.MailtagExchange12Success
 		ldr	r3, [r4, #24]
 		mov	r0, #1
 		str	r3, [r5]
 		pop	{r4, r5, r6, r7, r8, pc}
.MailtagExchange12Success:
 		mov	r0, #1
 		pop	{r4, r5, r6, r7, r8, pc}
.balign	4
.ltorg										;@ Tell assembler ltorg data for this code can go here
.size	RPI_MailtagExchange12, .-RPI_MailtagExchange12

.section .data1.mailbox.tagexchange812, "aw"
;@ Mailbox Property Interface Buffer Structure
.type FB_TAG812EXCHANGE_STRUCT, %object
.balign 16
FB_TAG812EXCHANGE_STRUCT:
  .4byte (FB_TAG812EXCHANGE_STRUCT_END - FB_TAG812EXCHANGE_STRUCT);@ Buffer Size In Bytes (Including The Header Values, The End Tag And Padding)
  .4byte 0x00000000							;@ Buffer Request/Response Code
  .4byte 0x0								;@ Tag Identifier (RPI_FIRMWARE_xxxxx_xxxxxx)
  .4byte 0x00000008							;@ Value Buffer Size In Bytes
  .4byte 0x00000008							;@ 1 bit (MSB) Request/Response Indicator (0=Request, 1=Response), 31 bits (LSB) Value Length In Bytes
  .4byte 0								    ;@ first 4 bytes
  .4byte 0									;@ second 4 bytes
.4byte   0x00000000							;@ 0x0 (End Tag) or 3rd 4 bytes if 12
.4byte   0x00000000							;@ 0x0 (End Tag) for 12 byte
FB_TAG812EXCHANGE_STRUCT_END:
.size	FB_TAG812EXCHANGE_STRUCT, .-FB_TAG812EXCHANGE_STRUCT

/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{			STRING HELPER ROUTINES PROVIDE BY RPi-SmartStart API		    }
{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/

/* "PROVIDE C FUNCTION: uint32_t RPI_GetFileExtension (char* FilePath, char* Extension, uint32_t maxExtLen); " */
.section .text.RPI_GetFileExtension, "ax", %progbits
.balign	4
.globl RPI_GetFileExtension;		
.type RPI_GetFileExtension, %function
.syntax unified
.arm
;@"================================================================"
;@ RPI_GetFileExtension -- Composite Pi1, Pi2 & Pi3 code
;@ C Function: uint32_t RPI_GetFileExtension (char* FilePath, char* Extension, uint32_t maxExtLen);
;@ Return: R0 length of extension string, copied if ext ptr valid
;@"================================================================"
RPI_GetFileExtension:
 		push	{r4, r5, r6, lr}
 		subs	r5, r1, #0
 		beq	.L4GetFileExtension
 		mov	r1, #0
 		cmp	r0, r1
 		mov	r6, r0
 		strb	r1, [r5]
 		beq	.L4GetFileExtension
 		mov	r4, r2
 		bl	strlen
 		cmp	r0, #0
		beq	.L4GetFileExtension
 		ldrb	r3, [r6, r0]	@ zero_extendqisi2
		add	ip, r6, r0
 		cmp	r3, #46
 		mov	r3, r0
 		bne	.L6GetFileExtension
 		b	.L5GetFileExtension
.L34GetFileExtension:
 		ldrb	lr, [ip, #-1]!	@ zero_extendqisi2
 		cmp	lr, #46
 		beq	.L33GetFileExtension
.L6GetFileExtension:
 		subs	r3, r3, #1
 		bne	.L34GetFileExtension
.L4GetFileExtension:
 		mov	r0, #0
 		pop	{r4, r5, r6, pc}
.L33GetFileExtension:
 		add	ip, r0, #1
 		sub	ip, ip, r3
 		cmp	ip, r4
 		bcc	.L11GetFileExtension
.L10GetFileExtension:
 		sub	ip, r4, #1
.L11GetFileExtension:
 		cmp	ip, #0
 		beq	.L8GetFileExtension
.L12GetFileExtension:
 		mov	r2, #0
 		add	r3, r6, r3
 		sub	r1, r5, #1
.L9GetFileExtension:
 		add	r2, r2, #1
 		ldrb	r0, [r3], #1	@ zero_extendqisi2
 		cmp	ip, r2
 		strb	r0, [r1, #1]!
 		bhi	.L9GetFileExtension
.L8GetFileExtension:
 		mov	r3, #0
 		mov	r0, ip
 		strb	r3, [r5, ip]
 		pop	{r4, r5, r6, pc}
.L5GetFileExtension:
 		cmp	r4, #1
 		movhi	ip, #1
 		bhi	.L12GetFileExtension
 		b	.L10GetFileExtension
;@ No ltorg data required for this function 
.size	RPI_GetFileExtension, .-RPI_GetFileExtension


/* "PROVIDE C FUNCTION: uint32_t RPI_GetFilename (char* FilePath, char* Filename, uint32_t maxlen); " */
.section .text.RPI_GetFilename, "ax", %progbits
.balign	4
.globl RPI_GetFilename;		
.type RPI_GetFilename, %function
.syntax unified
.arm
;@"================================================================"
;@ RPI_GetFilename -- Composite Pi1, Pi2 & Pi3 code
;@ C Function: uint32_t RPI_GetFilename (char* FilePath, char* Filename, uint32_t maxlen);
;@ Return: R0 length of filename string, copied if filename ptr valid
;@"================================================================"
RPI_GetFilename:
 		push	{r4, r5, r6, lr}
 		subs	r4, r1, #0
 		beq	.L4GetFilename
 		mov	r3, #0
 		cmp	r0, r3
 		mov	r5, r0
 		strb	r3, [r4]
 		beq	.L4GetFilename
 		mov	r6, r2
		bl	strlen
 		cmp	r0, #0
		beq	.L17GetFilename
 		ldrb	r1, [r5, r0]	@ zero_extendqisi2
 		add	ip, r5, r0
 		cmp	r1, #46
 		beq	.L18GetFilename
 		mov	lr, ip
 		mov	r3, r0
 		b	.L8GetFilename
.L40GetFilename:
 		ldrb	r2, [lr, #-1]!	@ zero_extendqisi2
 		cmp	r2, #46
		beq	.L38GetFilename
.L8GetFilename:
 		subs	r3, r3, #1
 		bne	.L40GetFilename
 		ldrb	r1, [ip]	@ zero_extendqisi2
 		add	r3, r0, #1
 		cmp	r1, #92
 		beq	.L15GetFilename
.L10GetFilename:
 		subs	r0, r0, #1
 		beq	.L5GetFilename
 		ldrb	r1, [ip, #-1]!	@ zero_extendqisi2
.L38GetFilename:
 		cmp	r1, #92
 		bne	.L10GetFilename
.L15GetFilename:
 		add	r0, r0, #1
.L11GetFilename:
 		sub	r3, r3, r0
 		cmp	r3, r6
 		subcs	r3, r6, #1
 		subcs	r3, r3, r0, lsl #1
 		cmp	r3, #0
 		beq	.L13GetFilename
 		mov	r2, r4
 		add	r0, r5, r0
 		add	ip, r4, r3
.L14GetFilename:
 		ldrb	r1, [r0], #1	@ zero_extendqisi2
 		strb	r1, [r2], #1
 		cmp	ip, r2
 		bne	.L14GetFilename
.L13GetFilename:
 		mov	r2, #0
 		mov	r0, r3
 		strb	r2, [r4, r3]
 		pop	{r4, r5, r6, pc}
.L17GetFilename:
 		mov	r3, #1
.L5GetFilename:
 		ldrb	r2, [r5]	@ zero_extendqisi2
 		mov	r0, #0
 		cmp	r2, #92
 		bne	.L11GetFilename
 		b	.L15GetFilename
.L4GetFilename:
 		mov	r0, #0
 		pop	{r4, r5, r6, pc}
.L18GetFilename:
 		mov	r3, r0
 		b	.L10GetFilename
;@ No ltorg data required for this function 
.size	RPI_GetFilename, .-RPI_GetFilename

/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{			GRAPHICS HELPER ROUTINES PROVIDE BY RPi-SmartStart API		    }
{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/

/* "INTERNAL graphics function WriteChar32 " */
.section .text.WriteChar32, "ax", %progbits
.balign	4
.type WriteChar32, %function
.syntax unified
.arm
;@"================================================================"
;@ WriteChar32 -- Pi1, 2 & 3 code
;@
;@ Internal Function: 
;@   Writes a character to screen in graphics 32 bit colour mode
;@
;@ Entry: R0 = X1, R1 = Y1, R2 = character, R3 = RGBA Colour
;@ Return: None
;@"================================================================"
WriteChar32:
        stmfd   sp!, {r4, r5, r6, r7, lr}
        mov     lr, #0
        ldr     ip, =RPi_FrameBuffer		;@ Fetch framebuffer address
        ldr     r4, =RPi_FramePitch			;@ Fetch pitch address
        ldr     ip, [ip]					;@ Load framebuffer value
        ldr     r5, [r4]					;@ Load pitch value
        add     r0, ip, r0, lsl #2
        ldr     ip, =RPi_SysFontPtr			;@ Load system font ptr address
        mla     r1, r5, r1, r0
        mov     r2, r2, asl #4						
        ldr     r0, [ip]					;@ Load system font ptr	
        add     r7, r2, #16
        mov     r5, r5, lsr #2
        add     r7, r0, r7
        add     r6, r0, r2
		;@ R1 = video_wr_ptr R3 = Colour  R4 = wr_ptr_yoffs R5 = PitchDiv4 R6 = Font pointer  lr = xoffs
.Process32Bits:
        mov     r2, #0						;@ For i = 0 ... to 31
        ldr     r0, [r6], #4				;@ Load next 32 bits from font and increment by 4
.Bit32Loop:
        cmp     r0, #0						;@ Compare bit to zero (Less than means bit 31 set) 
        and     ip, r2, #7					;@ Hold i mod 8 result  (i is in R2)
        addlt   r4, ip, lr					;@ if less than (bit31 set) add xoffs to wr_ptr_yoffs 
        add     r2, r2, #1					;@ inc i
        strlt   r3, [r1, r4, asl #2]		;@ Save the colour (r3) to array position video_wr_ptr[wr_ptr_yoffs]
        cmp     ip, #7						;@ Compare xoffs for 7
        addeq   lr, lr, r5					;@ if zero wr_ptr_yoffs(lr) += PitchDiv4(r5)
        cmp     r2, #32						;@ compare i for 32 and completed
        mov     r0, r0, asl #1				;@ Roll the font bits left 1 place
        bne     .Bit32Loop					;@ If we have not done the 32 bits loop
        cmp     r7, r6						;@ check if we have done all the font bits
        bne     .Process32Bits
        ldmfd   sp!, {r4, r5, r6, r7, pc}
.balign	4
.ltorg										;@ Tell assembler ltorg data for this code can go here
.size	WriteChar32, .-WriteChar32

/* "INTERNAL graphics function WriteChar24 " */
.section .text.WriteChar24, "ax", %progbits
.balign	4
.type WriteChar24, %function
.syntax unified
.arm
;@"================================================================"
;@ WriteChar24 -- Pi1, 2 & 3 code
;@
;@ Internal Function: 
;@   Writes a character to screen in graphics 24 bit colour mode
;@
;@ Entry: R0 = X1, R1 = Y1, R2 = character, R3 = RGBA Colour
;@ Return: None
;@"================================================================"
WriteChar24:
 		push	{r4, r5, r6, r7, r8, r9, r10, fp, lr}
 		ldr	r4, =RPi_FramePitch
 		ldr	lr, =RPi_FrameBuffer
 		ldr	r5, [r4]
 		ldr	r4, [lr]
 		ldr	lr, =RPi_SysFontPtr
 		lsl	r2, r2, #4
 		ldr	r9, [lr]
 		add	lr, r2, #16
 		sub	sp, sp, #28
 		add	lr, r9, lr
 		ldr	ip, =#65535
  		add	r9, r9, r2
 		lsl	r2, r3, #16
 		str	r2, [sp, #8]
 		lsl	r2, r3, #24
 		mla	r1, r1, r5, r4
 		str	r2, [sp]
 		lsr	r4, r3, #16
 		and	r2, ip, r3, lsr #8
 		uxtb	r4, r4
 		str	r2, [sp, #4]
 		ldr	r6, =#715827883
 		lsl	r2, r3, #8
 		ldr	r10, =#-65536
 		str	r4, [sp, #12]
 		str	lr, [sp, #20]
 		bic	r5, r5, #3
 		str	r2, [sp, #16]
 		bic	r7, r3, #-16777216
.L9WriteChar24:
 		mov	ip, #0
 		ldr	lr, [r9], #4
 		b	.L8WriteChar24
.L2WriteChar24:
		cmp	r2, #7
 		add	ip, ip, #1
 		addeq	r1, r1, r5
 		cmp	ip, #32
 		lsl	lr, lr, #1
 		beq	.L14WriteChar24
.L8WriteChar24:
 		cmp	lr, #0
 		and	r2, ip, #7
		bge	.L2WriteChar24
 		add	r4, r2, r0
 		add	r3, r4, r4, lsl #1
 		smull	r8, fp, r6, r3
 		asr	r3, r3, #31
 		rsb	r3, r3, fp, asr #1
 		add	r3, r3, r3, lsl #1
 		lsl	r3, r3, #2
 		cmp	r3, #0
 		add	fp, r3, #3
 		movlt	r3, fp
 		and	r4, r4, #3
 		cmp	r4, #2
 		asr	r3, r3, #2
 		beq	.L4WriteChar24
 		cmp	r4, #3
 		beq	.L5WriteChar24
 		cmp	r4, #1
 		beq	.L6WriteChar24
 		ldr	r4, [r1, r3, lsl #2]
 		and	r4, r4, #-16777216
  		orr	r4, r7, r4
 		str	r4, [r1, r3, lsl #2]
 		b	.L2WriteChar24
.L4WriteChar24:
 		add	r3, r3, #1
 		ldr	r4, [r1, r3, lsl #2]
 		ldr	r8, [sp, #8]
 		uxth	r4, r4
 		orr	r4, r4, r8
 		add	fp, r1, r3, lsl #2
 		str	r4, [r1, r3, lsl #2]
 		ldrb	r3, [sp, #12]	@ zero_extendqisi2
 		strb	r3, [fp, #4]
 		b	.L2WriteChar24
.L6WriteChar24:
  		ldr	fp, [r1, r3, lsl #2]
  		ldr	r8, [sp]
 		bic	fp, fp, #-16777216
 		lsl	r4, r3, #2
 		orr	fp, fp, r8
 		str	fp, [r1, r3, lsl #2]
 		add	r4, r4, #4
 		ldr	r3, [r1, r4]
 		ldr	r8, [sp, #4]
 		and	r3, r3, r10
 		orr	r3, r3, r8
 		str	r3, [r1, r4]
 		b	.L2WriteChar24
.L5WriteChar24:
 		add	r3, r3, #2
  		ldrb	r4, [r1, r3, lsl #2]	@ zero_extendqisi2
 		ldr	r8, [sp, #16]
 		orr	r4, r4, r8
 		str	r4, [r1, r3, lsl #2]
 		b	.L2WriteChar24
.L14WriteChar24:
 		ldr	r3, [sp, #20]
 		cmp	r9, r3
		bne	.L9WriteChar24
		add	sp, sp, #28
 		pop	{r4, r5, r6, r7, r8, r9, r10, fp, pc}
.balign	4
.ltorg										;@ Tell assembler ltorg data for this code can go here
.size	WriteChar24, .-WriteChar24


/* "INTERNAL graphics function WriteChar16 " */
.section .text.WriteChar16, "ax", %progbits
.balign	4
.type WriteChar16, %function
.syntax unified
.arm
;@"================================================================"
;@ WriteChar16 -- Pi1, 2 & 3 code
;@
;@ Internal Function: 
;@   Writes a character to screen in graphics 16 bit colour mode
;@
;@ Entry: R0 = X1, R1 = Y1, R2 = character, R3 = RGBA Colour
;@ Return: None
;@"================================================================"
WriteChar16:
 		push	{r4, r5, r6, r7, r8, r9, r10, fp, lr}
 		ldr	ip, =RPi_FrameBuffer
 		ldr	lr, =RPi_FramePitch
 		ldr	r4, [ip]
 		ldr	r7, [lr]
 		lsr	ip, r3, #8
 		lsr	r8, r3, #5
 		ldr	lr, =RPi_SysFontPtr
 		and	r8, r8, #2016
 		and	ip, ip, #63488
 		lsl	r2, r2, #4
 		lsl	r3, r3, #24
 		ldr	lr, [lr]
 		orr	ip, ip, r8
 		orr	r8, ip, r3, lsr #27
 		add	r3, r2, #16
 		sub	sp, sp, #12
 		add	r3, lr, r3
 		str	r3, [sp, #4]
 		ldr	fp, =#65535
 		add	r3, lr, r2
 		ldr	r10, =#-65536
  		mla	r1, r1, r7, r4
  		lsl	r9, r8, #16
  		str	r3, [sp]
 		bic	r7, r7, #3
.L48WriteChar16:
 		ldr	r3, [sp]
 		mov	lr, #0
		ldr	r4, [r3], #4
		str	r3, [sp]
 		b	.L47WriteChar16
.L44WriteChar16:
 		cmp	r2, #7
 		add	lr, lr, #1
 		addeq	r1, r1, r7
 		cmp	lr, #32
 		lsl	r4, r4, #1
 		beq	.L52WriteChar16
.L47WriteChar16:
		cmp	r4, #0
		and	r2, lr, #7
 		bge	.L44WriteChar16
 		add	ip, r2, r0
 		lsl	r3, ip, #1
 		asr	r5, r3, #31
 		lsr	r6, r5, #30
  		add	r5, r3, r6
 		and	r5, r5, #3
		sub	r5, r5, r6
 		sub	r3, r3, r5
 		cmp	r3, #0
 		add	r5, r3, #3
 		movlt	r3, r5
 		asr	r3, r3, #2
  		tst	ip, #1
 		ldr	ip, [r1, r3, lsl #2]
 		andeq	ip, ip, r10
 		andne	ip, ip, fp
  		orreq	ip, r8, ip
 		orrne	ip, ip, r9
 		str	ip, [r1, r3, lsl #2]
 		b	.L44WriteChar16
.L52WriteChar16:
 		ldr	r3, [sp]
 		ldr	r2, [sp, #4]
 		cmp	r3, r2
 		bne	.L48WriteChar16
 		add	sp, sp, #12
		pop	{r4, r5, r6, r7, r8, r9, r10, fp, pc}
.balign	4
.ltorg										;@ Tell assembler ltorg data for this code can go here
.size	WriteChar16, .-WriteChar16


/* "INTERNAL graphics function SetPixel16 " */
.section .text.SetPixel16, "ax",%progbits
.balign	4
.type	SetPixel16, %function
.syntax unified
.arm
;@"================================================================"
;@ SetPixel16 -- Pi1, 2 & 3 code
;@
;@ Internal Function: 
;@   Sets (X1,Y1) pixel in the given RGBA colour in 16 bit mode
;@
;@ Return: None
;@"================================================================"
SetPixel16:
 		ldr	r3, =RPi_GraphWidth
 		ldr	r3, [r3]
 		cmp	r3, r0
 		bxls	lr
 		ldr	r3, =RPi_GraphHeight
 		ldr	r3, [r3]
 		cmp	r1, r3
 		bxcs	lr
 		ldr	ip, =RPi_FramePitch
 		ldr	r3, =RPi_FrameBuffer
 		str	lr, [sp, #-4]!
 		ldr	lr, [ip]
 		ldr	ip, [r3]
 		lsr	r3, r2, #8
 		mla	r1, lr, r1, ip
 		lsr	ip, r2, #5
 		tst	r0, #1
 		and	ip, ip, #2016
 		lsr	r0, r0, #1
 		and	r3, r3, #63488
 		orr	r3, r3, ip
 		ldr	ip, [r1, r0, lsl #2]
 		lsl	r2, r2, #24
 		orr	r2, r3, r2, lsr #27
 		lsreq	r3, ip, #16
 		uxthne	r3, ip
 		lsleq	r3, r3, #16
 		orrne	r2, r3, r2, lsl #16
 		orreq	r2, r2, r3
 		str	r2, [r1, r0, lsl #2]
 		ldr	pc, [sp], #4
.balign	4
.ltorg										;@ Tell assembler ltorg data for this code can go here
.size	SetPixel16, .-SetPixel16


/* "INTERNAL graphics function SetPixel24 " */
.section .text.SetPixel24, "ax",%progbits
.balign	4
.type	SetPixel24, %function
.syntax unified
.arm
;@"================================================================"
;@ SetPixel24 -- Pi1, 2 & 3 code
;@
;@ Internal Function: 
;@   Sets (x1,Y1) pixel in the given RGBA colour in 24 bit mode
;@
;@ Return: None
;@"================================================================"
SetPixel24:
 		ldr	r3, =RPi_GraphWidth
 		ldr	r3, [r3]
 		cmp	r3, r0
 		bxls	lr
 		ldr	r3, =RPi_GraphHeight
 		ldr	r3, [r3]
 		cmp	r1, r3
 		bxcs	lr
 		ldr	ip, =RPi_FramePitch
 		ldr	r3, =RPi_FrameBuffer
 		str	lr, [sp, #-4]!
 		ldr	lr, [ip]
 		ldr	ip, [r3]
 		and	r3, r0, #3
 		cmp	r3, #1
 		add	r0, r0, r0, lsl #1
 		mla	r1, lr, r1, ip
 		lsr	ip, r0, #2
 		bic	r0, r0, #3
 		beq	.L4SetPixel24
 		cmp	r3, #2
 		beq	.L5SetPixel24
 		cmp	r3, #0
 		beq	.L13SetPixel24
 		ldrb	r3, [r1, r0]	@ zero_extendqisi2
 		orr	r2, r3, r2, lsl #8
 		str	r2, [r1, r0]
 		ldr	pc, [sp], #4
.L5SetPixel24:
 		ldrh	r3, [r1, r0]
 		add	ip, ip, #1
 		orr	r3, r3, r2, lsl #16
 		lsr	r2, r2, #16
 		str	r3, [r1, r0]
 		strb	r2, [r1, ip, lsl #2]
 		ldr	pc, [sp], #4
.L4SetPixel24:
 		add	r0, r1, r0
 		strb	r2, [r0, #3]
 		add	ip, ip, #1
 		ldr	r3, [r1, ip, lsl #2]
 		lsl	r2, r2, #8
 		lsr	r3, r3, #16
 		lsl	r3, r3, #16
 		orr	r3, r3, r2, lsr #16
 		str	r3, [r1, ip, lsl #2]
 		ldr	pc, [sp], #4
.L13SetPixel24:
 		ldr	r3, [r1, r0]
 		bic	r2, r2, #-16777216
		and	r3, r3, #-16777216
 		orr	r2, r2, r3
		str	r2, [r1, r0]
 		ldr	pc, [sp], #4
.balign	4
.ltorg										;@ Tell assembler ltorg data for this code can go here
.size	SetPixel24, .-SetPixel24


/* "INTERNAL graphics function SetPixel32 " */
.section .text.SetPixel32, "ax",%progbits
.balign	4
.type	SetPixel32, %function
.syntax unified
.arm
;@"================================================================"
;@ SetPixel32 -- Pi1, 2 & 3 code
;@
;@ Internal Function: 
;@   Sets (x1,Y1) pixel in the given RGBA colour in 32 bit mode
;@
;@ Return: None
;@"================================================================"
SetPixel32:
 		ldr	r3, =RPi_GraphWidth
 		ldr	r3, [r3]
 		cmp	r3, r0
 		bxls	lr
 		ldr	r3, =RPi_GraphHeight
 		ldr	r3, [r3]
 		cmp	r1, r3
 		bxcs	lr
 		ldr	r3, =RPi_FramePitch
 		lsl	r0, r0, #2
 		ldr	ip, [r3]
 		ldr	r3, =RPi_FrameBuffer
 		mla	r0, ip, r1, r0
 		ldr	r3, [r3]
 		str	r2, [r0, r3]
 		bx	lr
.balign	4
.ltorg										;@ Tell assembler ltorg data for this code can go here
.size	SetPixel32, .-SetPixel32


/* "INTERNAL graphics function ClearArea16 " */
.section .text.ClearArea16, "ax",%progbits
.balign	4
.type	ClearArea16, %function
.syntax unified
.arm
;@"================================================================"
;@ ClearArea16 -- Pi1, 2 & 3 code
;@
;@ Internal Function: 
;@   Clears a screen area in graphics 16 bit colour mode
;@
;@ Return: None
;@"================================================================"
ClearArea16:
 		cmp	r1, r3
 		push	{r4, r5, r6, r7, r8, r9, r10, fp, lr}
 		movcc	lr, #0
 		movcs	lr, #1
 		cmp	r2, r0
 		orrls	lr, lr, #1
 		sub	sp, sp, #28
 		cmp	lr, #0
 		ldr	r4, [sp, #64]
 		bne	.L1ClearArea16
 		ldr	r5, =RPi_FramePitch
 		ands	fp, r0, #1
 		ldr	r5, [r5]
 		str	lr, [sp, #16]
 		mov	lr, r5
 		add	r8, r0, #1
 		moveq	r8, r0
 		ldr	ip, =RPi_FrameBuffer
 		lsr	r5, r4, #8
 		ldr	r9, [ip]
 		bic	r7, r2, #1
 		mla	r9, r1, lr, r9
 		lsr	ip, r4, #5
 		sub	r7, r7, r8
 		sub	r10, r2, r8
 		and	ip, ip, #2016
 		and	r5, r5, #63488
 		orr	r5, r5, ip
 		bic	r6, r7, #1
 		cmp	r10, #1
 		lsl	r4, r4, #24
 		orr	r4, r5, r4, lsr #27
 		add	r6, r6, r8
 		lsr	r7, r7, #1
 		movls	r6, r8
 		lsr	ip, r2, #1
 		lsr	r8, r8, #1
 		lsl	ip, ip, #2
 		str	r9, [sp, #20]
 		lsl	r5, r4, #16
 		lsr	r9, r0, #1
 		add	r0, r8, r7
		rsb	r0, ip, r0, lsl #2
 		str	r5, [sp, #12]
 		sub	r5, r3, r1
 		ldr	r1, [sp, #20]
 		str	r0, [sp, #8]
		lsl	r3, r4, #16
 		rsb	r0, ip, r8, lsl #2
 		bic	r8, lr, #3
 		ldr	lr, [sp, #16]
 		str	r0, [sp, #4]
		rsb	r9, ip, r9, lsl #2
 		orr	r0, r4, r3
 		add	ip, r1, ip
.L9ClearArea16:
 		cmp	fp, #0
 		ldrne	r3, [r9, ip]
		ldrne	r1, [sp, #12]
 		uxthne	r3, r3
 		orrne	r3, r3, r1
 		strne	r3, [r9, ip]
 		cmp	r10, #1
 		bls	.L4ClearArea16
 		cmp	r7, #0
 		beq	.L4ClearArea16
 		ldr	r3, [sp, #4]
 		ldr	r1, [sp, #8]
		add	r3, ip, r3
 		add	r1, ip, r1
.L6ClearArea16:
 		str	r0, [r3], #4
 		cmp	r3, r1
		bne	.L6ClearArea16
.L4ClearArea16:
 		cmp	r6, r2
 		ldrne	r3, [ip]
 		add	lr, lr, #1
 		lsrne	r3, r3, #16
 		lslne	r3, r3, #16
 		orrne	r3, r4, r3
 		strne	r3, [ip]
 		cmp	lr, r5
 		add	ip, ip, r8
 		bne	.L9ClearArea16
.L1ClearArea16:
 		add	sp, sp, #28
		pop	{r4, r5, r6, r7, r8, r9, r10, fp, pc}
.balign	4
.ltorg										;@ Tell assembler ltorg data for this code can go here
.size	ClearArea16, .-ClearArea16

/* "INTERNAL graphics function ClearArea24 " */
.section .text.ClearArea24, "ax",%progbits
.balign	4
.type	ClearArea24, %function
.syntax unified
.arm
;@"================================================================"
;@ ClearArea24 -- Pi1, 2 & 3 code
;@
;@ Internal Function: 
;@   Clears a screen area in graphics 24 bit colour mode
;@
;@ Return: None
;@"================================================================"
ClearArea24:
		cmp	r1, r3
		push	{r4, r5, r6, r7, r8, r9, r10, fp, lr}
		movcc	lr, #0
		movcs	lr, #1
 		cmp	r2, r0
		orrls	lr, lr, #1
 		sub	sp, sp, #28
		cmp	lr, #0
 		mov	r10, r0
		str	r0, [sp, #8]
 		ldr	ip, [sp, #64]
 		bne	.L23ClearArea24Exit
 		ldr	r5, =RPi_FramePitch
		sub	r3, r3, r1
		ldr	r6, [r5]
		ldr	r0, =RPi_FrameBuffer
 		str	r3, [sp, #16]
		bic	r3, r6, #3
		str	r3, [sp, #12]
		lsl	r3, ip, #8
		ldr	r4, =#65535
		ldr	r0, [r0]
		str	r3, [sp]
		bic	r3, ip, #-16777216
		lsr	r5, ip, #16
		str	r3, [sp, #4]
		ldr	r8, =#-65536
		add	r3, r10, r10, lsl #1
		mov	r9, r4
		mla	r0, r1, r6, r0
		and	r4, r4, ip, lsr #8
 		uxtb	r5, r5
 		lsl	r7, ip, #16
 		lsl	r6, ip, #24
 		str	r3, [sp, #20]
.L32ClearArea24:
 		ldr	r1, [sp, #20]
		ldr	r3, [sp, #8]
 		b	.L31ClearArea24
.L42ClearArea24:
		cmp	r10, #2
 		beq	.L28ClearArea24
 		cmp	r10, #0
 		bic	r10, r1, #3
 		beq	.L40ClearArea24
 		ldrb	ip, [r0, r10]	@ zero_extendqisi2
 		ldr	fp, [sp]
 		orr	ip, ip, fp
 		str	ip, [r0, r10]
.L30ClearArea24:
 		add	r3, r3, #1
 		cmp	r2, r3
 		add	r1, r1, #3
 		bls	.L41ClearArea24
.L31ClearArea24:
  		and	r10, r3, #3
  		cmp	r10, #1
  		lsr	ip, r1, #2
  		bne	.L42ClearArea24
 		bic	fp, r1, #3
  		ldr	r10, [r0, fp]
  		add	ip, ip, #1
  		bic	r10, r10, #-16777216
  		orr	r10, r10, r6
  		str	r10, [r0, fp]
  		ldr	r10, [r0, ip, lsl #2]
  		add	r3, r3, #1
  		and	r10, r10, r8
  		orr	r10, r10, r4
  		cmp	r2, r3
  		str	r10, [r0, ip, lsl #2]
  		add	r1, r1, #3
  		bhi	.L31ClearArea24
.L41ClearArea24:
  		ldr	r3, [sp, #16]
  		add	lr, lr, #1
  		cmp	lr, r3
  		ldr	r3, [sp, #12]
  		add	r0, r0, r3
  		bne	.L32ClearArea24
.L23ClearArea24Exit:
  		add	sp, sp, #28
		pop	{r4, r5, r6, r7, r8, r9, r10, fp, pc}
.L40ClearArea24:
  		ldr	ip, [r0, r10]
  		ldr	fp, [sp, #4]
  		and	ip, ip, #-16777216
  		orr	ip, fp, ip
  		str	ip, [r0, r10]
  		b	.L30ClearArea24
.L28ClearArea24:
 		bic	fp, r1, #3
 		ldr	r10, [r0, fp]
 		add	ip, ip, #1
 		and	r10, r10, r9
 		orr	r10, r10, r7
 		str	r10, [r0, fp]
 		strb	r5, [r0, ip, lsl #2]
 		b	.L30ClearArea24
.balign	4
.ltorg										;@ Tell assembler ltorg data for this code can go here
.size	ClearArea24, .-ClearArea24

/* "INTERNAL graphics function ClearArea32 " */
.section .text.ClearArea32, "ax",%progbits
.balign	4
.type	ClearArea32, %function
.syntax unified
.arm
;@"================================================================"
;@ ClearArea32 -- Pi1, 2 & 3 code
;@
;@ Internal Function: 
;@   Clears a screen area in graphics 32 bit colour mode
;@
;@ Return: None
;@"================================================================"
ClearArea32:
 		cmp	r1, r3
 		push	{r4, r5, r6, r7, lr}
 		movcc	lr, #0
 		movcs	lr, #1
 		cmp	r2, r0
 		movhi	r4, lr
 		orrls	r4, lr, #1
 		cmp	r4, #0
 		ldr	ip, [sp, #20]
 		popne	{r4, r5, r6, r7, pc}
 		ldr	r5, =RPi_FramePitch
 		ldr	lr, =RPi_FrameBuffer
 		ldr	r7, [r5]
 		ldr	lr, [lr]
 		sub	r5, r2, r0
 		mla	r2, r1, r7, lr
 		mov	lr, r4
 		sub	r6, r3, r1
 		lsl	r5, r5, #2
 		add	r1, r2, r0, lsl #2
 		bic	r0, r7, #3
.L8ClearArea32:
 		mov	r3, r1
		add	r2, r1, r5
.L9ClearArea32:
		str	ip, [r3], #4
 		cmp	r3, r2
 		bne	.L9ClearArea32
 		add	lr, lr, #1
 		cmp	lr, r6
		add	r1, r1, r0
 		bne	.L8ClearArea32
 		pop	{r4, r5, r6, r7, pc}
.balign	4
.ltorg										;@ Tell assembler ltorg data for this code can go here
.size	ClearArea32, .-ClearArea32

/* "PROVIDE C FUNCTION: bool RPI_InitGraph (unsigned int Width, unsigned int Height, unsigned int ColourDepth);" */
.section .text.RPI_InitGraph, "ax", %progbits
.balign	4
.globl RPI_InitGraph;			
.type RPI_InitGraph, %function
.syntax unified
.arm
;@"================================================================"
;@ RPI_InitGraph -- Pi1, 2 & 3 code
;@
;@ C Function: 
;@   bool RPI_InitGraph (unsigned int Width, unsigned int Height, unsigned int ColourDepth);
;@
;@ Entry: R0 = Req width, R1 = Req Height, R2 = Req Colour Depth
;@ Return: true if successfull, false if any error occurred
;@ Special Function: Updates WriteTextPtr based on colour depth 
;@"================================================================"
RPI_InitGraph:
        stmfd   sp!, {r4, r5, r6, lr} 
		mov		r5, r0						;@ Hold the screen width request
		mov		r6, r1						;@ Hold the screen height request
        ldr     ip, =FB_SCREEN_RES_STRUCT  
        str     r0, [ip, #20]				;@ Physical width
        str     r0, [ip, #40]				;@ Virtual width
        str     r1, [ip, #24]				;@ Physical height
        str     r1, [ip, #44]				;@ Virt height							     
        str     r2, [ip, #60]				;@ req colour depth
		mov		r0, #0
        mov		r1, #4
		mov		r2, #16   
	    str     r0, [ip, #4]				;@ Clear response if we have already called it will be trashed
        str     r1, [ip, #72]				;@ Clear response
        str     r2, [ip, #76]				;@ Frame buffer needs to be align 16
        str     r0, [ip, #80]								
        str     r1, [ip, #92]
        str     r0, [ip, #96]
		ldr     r3, =RPi_IO_Base_Addr		;@ Fetch address of base address
		ldr     r3, [r3]					;@ Load the base address value
		cmp     r3, #0x20000000
        orreq   r4, ip, #0x40000000			;@ ORR value with 0x40000000
        orrne   r4, ip, #0xC0000000			;@ ORR value with 0xC0000000
        bic     r4, r4, #15					;@ Clear mail channel bits
        orr     r4, r4, #MAIL_TAGS			;@ ORR mail tags channel on
		ldr		r0, =#MAIL_BASE_OFFSET		;@ Fetch mail base from io base offset
        add     r1, r3, r0					;@ Mailbox base IO offset
.CheckMailboxNotFull:
        Memory_Barrier r0
        ldr     r3, [r1, #MAIL_STATUS_OFFS]	;@ Read mailbox status
        Memory_Barrier r0
        cmp     r3, #0
        blt     .CheckMailboxNotFull		;@ If mailbox full reloop
        str     r4, [r1, #MAIL_WRITE_OFFS]	;@ Write r4 value to mailbox
.WaitForMailResponse:
        Memory_Barrier r0
        ldr     r3, [r1, #MAIL_STATUS_OFFS]	;@ Read mailbox status
        Memory_Barrier r0
        ands     r3, r3, #MAIL_EMPTY		;@ Check mailbox not empty
        bne     .WaitForMailResponse
        ldr     r3, [r1, #MAIL_READ_OFFS]	;@ Read mailbox value
        Memory_Barrier r0
        and     r3, r3, #15					;@ clear off all but channel bits
        cmp     r3, #MAIL_TAGS				;@ Compare to mail tags channel
        bne     .WaitForMailResponse		;@ Loop if not mail tag channel response
        ldr     r2, [ip, #4]				;@ Fetch response written into FB_SCREEN_RES_STRUCT
        cmp     r2, #0x80000000				;@ Check for valid response
        beq     .InitGraphMsgReplied
.InitgraphFailed:
        mov     r0, #0						;@ Set fail result return
        ldmfd   sp!, {r4, pc}
.InitGraphMsgReplied:
        ldr     r2, [ip, #72]				;@ Fetch framebuffer response
        cmp     r2, #0x80000008				;@ Compare to valid response
        bne     .InitgraphFailed			;@ If not valid fail out
        ldr     r2, [ip, #92]				;@ Fetch pitch response 
        cmp     r2, #0x80000004				;@ Compare to valid response
        bne     .InitgraphFailed			;@ If not valid fail out
        ldr     r2, [ip, #76]				;@ Fetch the valid framebuffer returned
        ldr     r1, [ip, #96]				;@ Fetch the valid pitch returned
        bic     r3, r2, #0xC0000000			;@ Logical AND framebuffer with 0x3FFFFFFF
		ldr		r2, =RPi_FrameBuffer		;@ Fetch RPI_Framebuffer address
        str     r3, [r2]					;@ Store frame buffer result there
		ldr		r2, =RPi_FramePitch			;@ Fetch RPI_Pitch Address
		str		r1, [r2]					;@ Store pitch result there
		ldr	    r1, =RPi_GraphWidth			;@ Fetch pointer to graphics width
		str	    r5, [r1]					;@ Update the changed graphics Width
		ldr	    r1, =RPi_GraphHeight		;@ Fetch pointer to graphics width
		str	    r6, [r1]					;@ Update the changed graphics Height
        ldr     r2, [ip, #60]				;@ Fetch the colourdepth
		ldr	    r1, =RPi_GraphColorDepth	;@ Fetch pointer to colour depth
		str     r2, [r1]					;@ Store the new colour depth
		ldr		r1, =WriteChar32			;@ r1 = Address of 32 bit colour mode writechar
		ldr		r3, =ClearArea32			;@ r3 = Adrress of 32 bit colour clear area function
		ldr		r4, =SetPixel32				;@ r4 = Address of 32 bit colour mode SetPixel
		cmp		r2, #32						;@ Check if we are in 32 bit mode
		beq		.SetWritePtr				;@ If we are in 32 bit mode save that address
		ldr		r1, =WriteChar24			;@ r1 = Address of 24 bit colour mode writechar
		ldr		r3, =ClearArea24			;@ r3 = Adrress of 24 bit colour clear area function
		ldr		r4, =SetPixel24				;@ r4 = Address of 24 bit colour mode SetPixel
		cmp		r2, #24						;@ Check if we are in 24 bit mode
		beq		.SetWritePtr				;@ If we are in 24 bit mode save that address
		ldr		r1, =WriteChar16			;@ r1 = Address of 16 bit colour mode writechar  (our default)
		ldr		r3, =ClearArea16			;@ r3 = Adrress of 16 bit colour clear area function
		ldr		r4, =SetPixel16				;@ r4 = Address of 16 bit colour mode SetPixel
.SetWritePtr:
		ldr		r0, =WriteTextPtr			;@ Write text pointer address
		str		r1, [r0]					;@ Save our selected writechar address to this variable
		ldr		r0, =ClearAreaPtr			;@ ClearArea pointer address
		str		r3, [r0]					;@ Save our selected cleararea address to this variable
		ldr		r0, =SetPixelPtr			;@ SetPixel pointer address
		str		r4, [r0]					;@ Save our selected setpixel address to this variable
		mov     r0, #1						;@ Return sucess with a true result
        ldmfd   sp!, {r4, r5, r6, pc}		;@ Return from call
.balign	4
.ltorg										;@ Tell assembler ltorg data for this code can go here
.size	RPI_InitGraph, .-RPI_InitGraph

.section .data1.mailbox.initgraph, "aw"
;@ Mailbox Property Interface Buffer 
.type FB_SCREEN_RES_STRUCT, %object
.balign 16
FB_SCREEN_RES_STRUCT: 
  .4byte (FB_SCREEN_RES_STRUCT_END - FB_SCREEN_RES_STRUCT);@ Buffer Size In Bytes (Including The Header Values, The End Tag And Padding)
  .4byte 0x00000000							;@ Buffer Request/Response Code
  .4byte 0x00048003							;@ Tag Identifier MAILBOX_TAG_SET_PHYSICAL_WIDTH_HEIGHT
  .4byte 0x00000008							;@ Value Buffer Size In Bytes
  .4byte 0x00000008							;@ 1 bit (MSB) Request/Response Indicator (0=Request, 1=Response), 31 bits (LSB) Value Length In Bytes
  .4byte 800								;@ Screen width
  .4byte 600								;@ Screen height
  .4byte 0x00048004							;@ Tag Identifier MAILBOX_TAG_SET_VIRTUAL_WIDTH_HEIGHT
  .4byte 0x00000008							;@ Value Buffer Size In Bytes
  .4byte 0x00000008							;@ 1 bit (MSB) Request/Response Indicator (0=Request, 1=Response), 31 bits (LSB) Value Length In Bytes
  .4byte 800								;@ Screen width
  .4byte 600								;@ Screen height
  .4byte 0x00048005							;@ Tag Identifier MAILBOX_TAG_SET_COLOUR_DEPTH
  .4byte 0x00000004							;@ Value Buffer Size In Bytes
  .4byte 0x00000004							;@ 1 bit (MSB) Request/Response Indicator (0=Request, 1=Response), 31 bits (LSB) Value Length In Bytes
  .4byte 32									;@ Colour depth
  .4byte 0x00040001							;@ Tag Identifier MAILBOX_TAG_ALLOCATE_FRAMEBUFFER
  .4byte 0x00000008							;@ Value Buffer Size In Bytes
  .4byte 0x00000004							;@ 1 bit (MSB) Request/Response Indicator (0=Request, 1=Response), 31 bits (LSB) Value Length In Bytes
  .4byte 16									;@ Alignment 16
  .4byte 0									;@ Value will be written here
  .4byte 0x00040008							;@ Tag Identifier MAILBOX_TAG_GET_PITCH
  .4byte 0x00000004							;@ Value Buffer Size In Bytes
  .4byte 0x00000004							;@ 1 bit (MSB) Request/Response Indicator (0=Request, 1=Response), 31 bits (LSB) Value Length In Bytes
  .4byte 0									;@ Value will be written here
.4byte 0x00000000							;@ 0x0 (End Tag)
FB_SCREEN_RES_STRUCT_END:
.size	FB_SCREEN_RES_STRUCT, .-FB_SCREEN_RES_STRUCT

/* "PROVIDE C FUNCTION: bool RPI_GetGraphMode (unsigned int* Width, unsigned int* Height, unsigned int* ColourDepth);" */
.section .text.RPI_GetGraphMode, "ax", %progbits
.balign	4
.globl RPI_GetGraphMode;			
.type RPI_GetGraphMode, %function
.syntax unified
.arm
;@"================================================================"
;@ RPI_GetGraphMode -- Pi1, 2 & 3 code
;@
;@ C Function: 
;@   bool RPI_GetGraphMode (unsigned int* Width, unsigned int* Height, unsigned int* ColourDepth);
;@
;@ Entry: R0 = Width result pointer, R1 = Height result pointer, 
;@        R2 = Colour depth result pointer 
;@ Return: None
;@ Special Function: Updates WriteTextPtr based on colour depth 
;@"================================================================"
RPI_GetGraphMode:
        ldr     r3, =RPi_IO_Base_Addr
        stmfd   sp!, {r4, r5, r6, lr}
        ldr     lr, [r3]					;@ Fetch pi base address
        mov     r6, r0						;@ Hold r0 pointer in r6
        ldr     ip, =FB_GET_SCREEN_STRUCT	;@ Fetch address of structure
        mov     r0, #0
        str     r0, [ip, #4]				;@ Clear response value, might be corrupt from previous call
        mov     r0, #8
        str     r0, [ip, #16]				;@ Clear wth/ht response value, might be corrupt from previous call
        mov     r0, #4
        str     r0, [ip, #36]				;@ Clear depth response value, might be corrupt from previous call
        cmp     lr, #0x20000000
        orreq   r5, ip, #0x40000000			;@ ORR value with 0x40000000
        orrne   r5, ip, #0xC0000000			;@ ORR value with 0xC0000000
		ldr		r0, =#MAIL_BASE_OFFSET		;@ Fetch mail base from io base offset
        add     r4, lr, r0					;@ Mailbox base IO offset
        bic     r5, r5, #0xF				;@ Make sure channel is clear
        orr     r5, r5, #MAIL_TAGS			;@ ORR tags channel onto value	
.CheckMailboxNotFull1:
        Memory_Barrier r0
        ldr     r3, [r4, #MAIL_STATUS_OFFS]	;@ Read mailbox status
        Memory_Barrier r0
        cmp     r3, #0
        blt     .CheckMailboxNotFull1		;@ Branch if mailbox full (aka status = 0x80000000)
        str     r5, [r4, #MAIL_WRITE_OFFS]	;@ Write Register 7 to mailbox write register
.WaitForMailResponse1:
        Memory_Barrier r0
        ldr     r3, [r4, #MAIL_STATUS_OFFS]	;@ Read mailbox status
        Memory_Barrier r0
        ands    r3, r3, #MAIL_EMPTY			;@ Check mailbox not empty
        bne     .WaitForMailResponse1		;@ If empty repeat read of status
        ldr     r3, [r4, #MAIL_READ_OFFS]	;@ If not empty read mailbox result
        Memory_Barrier r0
        and     r3, r3, #15					;@ Clear all but tag
        cmp     r3, #MAIL_TAGS				;@ check its a mail tage response
        bne     .WaitForMailResponse1		;@ If not mail-tag channel response try again 
        ldr     r0, [ip, #4]				;@ Fetch response written in FB_GET_SCREEN_STRUCT				
        cmp     r0, #0x80000000				;@ Check for response flag
        beq     .GetGraphModeReplied		;@ Continue on if valid response
.GetGraphModeFailed:
        mov     r0, #0						;@ We will return false
        ldmfd   sp!, {r4, r5, r6, pc}		;@ return from this call
.GetGraphModeReplied:
        ldr     r0, [ip, #16]				;@ Fetch reposne to screen Wth/Ht request
        cmp     r0, #0x80000008				;@ It should be 0x80000008
        bne     .GetGraphModeFailed			;@ Fail if not that value
        ldr     r0, [ip, #36]				;@ Fetch response to screen ColourDepth
        cmp     r0, #0x80000004				;@ That shoudl be 0x80000004
        bne     .GetGraphModeFailed			;@ Fail if not that value
        cmp     r6, #0						;@ Check if pointer not null
        ldrne   r0, [ip, #20]				;@ If pointer not null fetch graphics screen width report
        strne   r0, [r6]					;@ Write to R6 which is address provide in R0 at start
        cmp     r1, #0						;@ Check if R1 pointer is not null			
        ldrne   r0, [ip, #24]				;@ If pointer not null fetch graphics screen height report 
        strne   r0, [r1]					;@ Write to R1 which is address provide in R1 at start (register remains untouched)
        cmp     r2, #0						;@ Check if R1 pointer is not null
        ldrne   r0, [ip, #40]				;@ If pointer not null fetch graphics screen colour depth report
        strne   r0, [r2]					;@ Write to R1 which is address provide in R2 at start (register remians untouched)
		ldr		r1, =WriteChar32			;@ r1 = Address of 32 bit colour mode Writechar
		ldr		r3, =ClearArea32			;@ r3 = Address of 32 bit colour mode ClearArea
		ldr		r4, =SetPixel32				;@ r4 = Address of 32 bit colour mode SetPixel
		cmp		r0, #32						;@ Check if we are in 32 bit mode
		beq		.SetWritePtr1				;@ If we are in 32 bit mode save that address
		ldr		r1, =WriteChar24			;@ r1 = Address of 24 bit colour mode Writechar
		ldr		r3, =ClearArea24			;@ r3 = Address of 24 bit colour mode ClearArea
		ldr		r4, =SetPixel24				;@ r4 = Address of 24 bit colour mode SetPixel
		cmp		r0, #24						;@ Check if we are in 24 bit mode
		beq		.SetWritePtr1				;@ If we are in 24 bit mode save that address
		ldr		r1, =WriteChar16			;@ Address of 16 bit colour mode Writechar (our default)
		ldr		r3, =ClearArea16			;@ r3 = Address of 16 bit colour mode ClearArea
		ldr		r4, =SetPixel16				;@ r4 = Address of 16 bit colour mode SetPixel
.SetWritePtr1:
		ldr		r0, =WriteTextPtr			;@ Write text pointer address
		str		r1, [r0]					;@ Save our selected writechar address to this variable
		ldr		r0, =ClearAreaPtr			;@ ClearArea pointer address
		str		r3, [r0]					;@ Save our selected cleararea address to this variable
		ldr		r0, =SetPixelPtr			;@ SetPixelPtr pointer address
		str		r4, [r0]					;@ Save our selected setpixel address to this variable
        mov     r0, #1						;@ Return true result
        ldmfd   sp!, {r4, r5, r6, pc}		;@ Return from call
.balign	4
.ltorg										;@ Tell assembler ltorg data for this code can go here
.size	RPI_GetGraphMode, .-RPI_GetGraphMode

.globl FB_GET_SCREEN_STRUCT;
.section .data1.mailbox.getgraphmode, "aw"
;@ Mailbox Property Interface Buffer Structure
.type FB_GET_SCREEN_STRUCT, %object
.balign 16
FB_GET_SCREEN_STRUCT: 
  .4byte  (FB_GET_SCREEN_STRUCT_END - FB_GET_SCREEN_STRUCT);@ Buffer Size In Bytes (Including The Header Values, The End Tag And Padding)
  .4byte 0x00000000							;@ Buffer Request/Response Code
  .4byte 0x00040003							;@ Tag Identifier MAILBOX_TAG_GET_PHYSICAL_WIDTH_HEIGHT
  .4byte 0x00000008							;@ Value Buffer Size In Bytes
  .4byte 0x00000008							;@ 1 bit (MSB) Request/Response Indicator (0=Request, 1=Response), 31 bits (LSB) Value Length In Bytes
  .4byte 0									;@ Screen width
  .4byte 0									;@ Screen height
  .4byte 0x00040005							;@ Tag Identifier MAILBOX_TAG_GET_COLOUR_DEPTH
  .4byte 0x00000004							;@ Value Buffer Size In Bytes
  .4byte 0x00000004							;@ 1 bit (MSB) Request/Response Indicator (0=Request, 1=Response), 31 bits (LSB) Value Length In Bytes
  .4byte 0									;@ Colour depth
.4byte 0x00000000							;@ 0x0 (End Tag)
FB_GET_SCREEN_STRUCT_END:
.size	FB_GET_SCREEN_STRUCT, .-FB_GET_SCREEN_STRUCT


/* "PROVIDE C FUNCTION: void RPI_WriteChar (uint32_t X, uint32_t Y, unsigned char Ch, RGBA Colour);" */
.section .text.RPI_WriteChar, "ax", %progbits
.balign	4
.globl RPI_WriteChar;			
.type RPI_WriteChar, %function
.syntax unified
.arm
;@"================================================================"
;@ RPI_WriteChar -- Pi1, 2 & 3 code
;@
;@ C Function: 
;@  void RPI_WriteChar (uint32_t X, uint32_t Y, unsigned char Ch, RGBA Colour);
;@
;@ Entry: R0 = X screen Poistion, R1 = Y Screen Position 
;@        R2 = Character		  R3 = Colour for character 
;@ Return: None
;@"================================================================"
RPI_WriteChar:
		ldr     ip, =WriteTextPtr			;@ Fetch address of current write text for color mode we are on			
        str     lr, [sp, #-4]!
        ldr     lr, [ip]					;@ Load write text for our colour mode
        mov     ip, lr						
        ldr     lr, [sp], #4
        bx      ip							;@ indirect register sibling call
.balign	4
.ltorg										;@ Tell assembler ltorg data for this code can go here
.size	RPI_WriteChar, .-RPI_WriteChar


/* "PROVIDE C FUNCTION: void RPI_WriteText (uint32_t X, uint32_t Y, char* Txt, RGBA Colour);" */
.section .text.RPI_WriteText, "ax", %progbits
.balign	4
.globl RPI_WriteText;			
.type RPI_WriteText, %function
.syntax unified
.arm
;@"================================================================"
;@ RPI_WriteText -- Pi1, 2 & 3 code
;@
;@ C Function: 
;@  void RPI_WriteText (uint32_t X, uint32_t Y, char* Txt, RGBA Colour);
;@
;@ Entry: R0 = X screen Poistion, R1 = Y Screen Position 
;@        R2 = Pointer to string, R3 = Colour to write string 
;@ Return: None
;@"================================================================"
RPI_WriteText:
 		push	{r4, r5, r6, r7, r8, r9, r10, lr}
 		subs	r4, r2, #0
 		popeq	{r4, r5, r6, r7, r8, r9, r10, pc}
 		mov	r5, r0
 		mov	r0, r4
 		mov	r7, r1
		mov	r8, r3
 		bl	strlen
 		cmp	r0, #0
 		popeq	{r4, r5, r6, r7, r8, r9, r10, pc}
 		ldr	r9, =WriteTextPtr
		add	r6, r4, r0
 		b	.L47WriteText
.L46WriteText:
 		cmp	r6, r4
 		add	r5, r5, #8
 		beq	.L56WriteText
.L47WriteText:
 		ldrb	r2, [r4], #1	@ zero_extendqisi2
 		cmp	r2, #19
 		cmpne	r2, #10
  		beq	.L46WriteText
 		mov	r0, r5
 		ldr	r10, [r9]
 		mov	r3, r8
 		mov	r1, r7
		blx	r10
 		cmp	r6, r4
 		add	r5, r5, #8
 		bne	.L47WriteText
.L56WriteText:
 		pop	{r4, r5, r6, r7, r8, r9, r10, pc}
.balign	4
.ltorg										;@ Tell assembler ltorg data for this code can go here
.size	RPI_WriteText, .-RPI_WriteText


/* "PROVIDE C FUNCTION: void RPI_ClearArea (uint32_t X1, uint32_t Y1, uint32_t X2,  uint32_t Y2, RGBA Colour);" */
.section .text.PRI_ClearArea, "ax", %progbits
.balign	4
.globl RPI_ClearArea;			
.type RPI_ClearArea, %function
.syntax unified
.arm
;@"================================================================"
;@ RPI_ClearArea -- Pi1, 2 & 3 code
;@
;@ C Function: 
;@    void RPI_ClearArea (uint32_t X1, uint32_t Y1, uint32_t X2,  uint32_t Y2, RGBA Colour);
;@
;@ Special Function: Updates ClearAreaPtr based on colour depth 
;@"================================================================"
RPI_ClearArea:
		ldr     ip, =ClearAreaPtr			;@ Fetch address of current cleararea for color mode we are on			
        str     lr, [sp, #-4]!
        ldr     lr, [ip]					;@ Load write text for our colour mode
        mov     ip, lr						
        ldr     lr, [sp], #4
        bx      ip							;@ indirect register sibling call
.balign	4
.ltorg										;@ Tell assembler ltorg data for this code can go here
.size	RPI_ClearArea, .-RPI_ClearArea


/* "PROVIDE C FUNCTION: void RPI_SetPixel (uint32_t X, uint32_t Y, RGBA Colour);" */
.section .text.RPI_SetPixel, "ax", %progbits
.balign	4
.globl RPI_SetPixel;			
.type RPI_SetPixel, %function
.syntax unified
.arm
;@"================================================================"
;@ RPI_SetPixel -- Pi1, 2 & 3 code
;@
;@ C Function: 
;@    void RPI_SetPixel (uint32_t X, uint32_t Y, RGBA Colour);
;@
;@ Special Function: Set pixel based on colour depth 
;@"================================================================"
RPI_SetPixel:
 		ldr	r3, =SetPixelPtr
 		ldr	r3, [r3]
 		bx	r3	@ indirect register sibling call
.balign	4
.ltorg										;@ Tell assembler ltorg data for this code can go here
.size	RPI_SetPixel, .-RPI_SetPixel


/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{			GRAPHICS CONSOLE ROUTINES PROVIDE BY RPi-SmartStart API		    }
{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/

/* "PROVIDE C FUNCTION: void RPI_GraphicsDisableCRLF (bool SetOff);" */
.section .text.RPI_GraphicsDisableCRLF, "ax", %progbits
.balign	4
.globl RPI_GraphicsDisableCRLF;		
.type RPI_GraphicsDisableCRLF, %function
.syntax unified
.arm
;@"================================================================"
;@ GraphicsDisableCRLF -- Composite Pi1, Pi2 & Pi3 code
;@ C Function: void RPI_GraphicsDisableCRLF (bool SetOff)
;@ Entry: R0 bool state will turn graphics CR/LF processing on/off
;@"================================================================"
RPI_GraphicsDisableCRLF:
        ldr     r3, =RPi_disableCRLF
        strb    r0, [r3]
        bx      lr
.balign	4
.ltorg										;@ Tell assembler ltorg data for this code can go here
.size	RPI_GraphicsDisableCRLF, .-RPI_GraphicsDisableCRLF


/* "PROVIDE C FUNCTION: void RPI_GraphGotoXY (uint32_t X, uint32_t Y);" */
.section .text.RPI_GraphGotoXY, "ax", %progbits
.balign	4
.globl RPI_GraphGotoXY;		
.type RPI_GraphGotoXY, %function
.syntax unified
.arm
;@"================================================================"
;@ RPI_GraphGotoXY -- Composite Pi1, Pi2 & Pi3 code
;@ C Function: void RPI_GraphGotoXY (uint32_t X, uint32_t Y);
;@ Entry: R0 bool state will turn graphics CR/LF processing on/off
;@"================================================================"
 RPI_GraphGotoXY:
        ldr     r3, =RPi_GraphWidth
        ldr     r3, [r3]					;@ Fetch graphics screen width
        cmp     r3, r0						;@ Check requested X is smaller
        bxls    lr							;@ If not smaller immediate exit
        ldr     r3, =RPi_GraphHeight
        ldr     r3, [r3]					;@ Fetch graphics screen height
        cmp     r3, r1						;@ Check requested y is smaller
        ldrhi   r2, =RPi_grPosX
        ldrhi   r3, =RPi_grPosY
        strhi   r0, [r2]					;@ Store x to RPi_grPosX
        strhi   r1, [r3]					;@ Store y to RPi_grPosY
        bx      lr
.balign	4
.ltorg										;@ Tell assembler ltorg data for this code can go here
.size	 RPI_GraphGotoXY, .-RPI_GraphGotoXY


/* "PROVIDE C FUNCTION: void RPI_GraphWhereXY (uint32_t* X, uint32_t* Y);" */
.section .text.RPI_GraphWhereXY, "ax", %progbits
.balign	4
.globl RPI_GraphWhereXY;		
.type RPI_GraphWhereXY, %function
.syntax unified
.arm
;@"================================================================"
;@ RPI_GraphWhereXY -- Composite Pi1, Pi2 & Pi3 code
;@ C Function: void RPI_GraphWhereXY (uint32_t* X, uint32_t* Y);
;@ Entry: R0 bool state will turn graphics CR/LF processing on/off
;@"================================================================"
 RPI_GraphWhereXY:
        cmp     r0, #0
        ldrne   r3, =RPi_grPosX			
        ldrne   r3, [r3]					;@ Fetch  RPi_grPosX  value
        strne   r3, [r0]					;@ If X pointer valid store value at pointer address
        cmp     r1, #0
        ldrne   r3, =RPi_grPosY
        ldrne   r3, [r3]					;@ Fetch RPi_grPosY value
        strne   r3, [r1]					;@ If Y pointer valid store value at pointer address
        bx      lr
.balign	4
.ltorg										;@ Tell assembler ltorg data for this code can go here
.size	 RPI_GraphWhereXY, .-RPI_GraphWhereXY


/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{		   MATHEMATICS HELPER ROUTINES PROVIDE BY RPi-SmartStart API 	    }
{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
.section .text.fls_long, "ax", %progbits
.balign	4
.globl fls_long;			
.type fls_long, %function
.syntax unified
.arm
fls_long:
        cmp     r0, #0
        bxeq    lr
        movs    r3, r0, lsr #16
        moveq   r3, #16
        movne   r3, #32
        moveq   r0, r0, asl #16
        tst     r0, #-16777216
        moveq   r0, r0, asl #8
        subeq   r3, r3, #8
        tst     r0, #-268435456
        moveq   r0, r0, asl #4
        subeq   r3, r3, #4
        tst     r0, #-1073741824
        moveq   r0, r0, asl #2
        subeq   r3, r3, #2
        cmp     r0, #0
        subge   r0, r3, #1
        movlt   r0, r3
        bx      lr
;@ no ltorg data for this code
.size	 fls_long, .-fls_long


/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{					 NEWLIB STUBS PROVIDE BY RPi-SmartStart API 		    }
{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
/* Set position in a file. Minimal implementation: */
//int _lseek(int file, int ptr, int dir)
.section .text._lseek, "ax", %progbits
.balign	4
.globl _lseek;			
.type _lseek, %function
.syntax unified
.arm
_lseek:
		mov r0, #0;
		bx lr;
.size	_lseek, .-_lseek

/* Query whether output stream is a terminal. For consistency with the other
minimal implementations, which only support output to stdout, this minimal
implementation is suggested: */
//int _isatty(int file)
.section .text._isatty, "ax", %progbits
.balign	4
.globl _isatty;			
.type _isatty, %function
.syntax unified
.arm
_isatty:
		mov r0, #1;
		bx lr;
.size	_isatty, .-_isatty

/* Read from a file. Minimal implementation: */
//int _read(int file, char *ptr, int len)
.section .text._read, "ax", %progbits
.balign	4
.globl _read;			
.type _read, %function
.syntax unified
.arm
_read:
		mov r0, #0;
		bx lr;
.size	_read, .-_read

//_close(int):
.section .text._close, "ax", %progbits
.balign	4
.globl _close;			
.type _close, %function
.syntax unified
.arm
_close:
        mvn     r0, #0
        bx      lr
.size	_close, .-_close

//int _open (const char *name, int flags, int mode):
.section .text._open, "ax", %progbits
.balign	4
.globl _open;			
.type _open, %function
.syntax unified
.arm
_open:
        mvn     r0, #0
        bx      lr
.size	_open, .-_open

.section .text._fstat, "ax",%progbits
.balign	4
.globl _fstat;			
.type _fstat, %function
.syntax unified
.arm
_fstat:
        mov     r3, #8192
        mov     r0, #0
        str     r3, [r1, #4]
        bx      lr
.size	_fstat, .-_fstat

.section .text._sbrk, "ax", %progbits
.balign	4
.globl _sbrk;			
.type _sbrk, %function
.syntax unified
.arm
_sbrk:
        ldr     r2, =RPi_Heap
        ldr     r1, =_end
        ldr     r3, [r2]
        cmp     r3, #0
        moveq   r3, r1
        add     r0, r3, r0
        str     r0, [r2]
        mov     r0, r3
        bx      lr
.balign	4
.ltorg										;@ Tell assembler ltorg data for this code can go here
.size	_sbrk, .-_sbrk


.section .text.GetStackPointer, "ax", %progbits
.balign	4
.globl GetStackPointer;			
.type GetStackPointer, %function
.syntax unified
.arm
GetStackPointer:
        mov     r0, sp
        bx      lr
.size	GetStackPointer, .-GetStackPointer


.section .text._write,"ax",%progbits
.balign	4
.global	_write
.type	_write, %function
.syntax unified
.arm
_write:
		push	{r4, r5, r6, r7, r8, r9, r10, lr}
		subs	r10, r2, #0
		ble	.L13WriteExit
 		mov	r4, r1
		mvn	r9, #0
		ldr	r7, =RPi_disableCRLF
 		ldr	r8, =RPi_grPosY
 		ldr	r5, =RPi_grPosX
 		add	r6, r1, r10
 		b	.L7Write
.L4Write:
		cmp	r2, #13
 		streq	r3, [r5]
 		beq	.L5Write
 		cmp	r2, #10
 		ldreq	r2, [r8]
 		streq	r3, [r5]
 		addeq	r3, r2, #BitFontHt
		streq	r3, [r8]
.L5Write:
 		cmp	r6, r4
 		beq	.L13WriteExit
.L7Write:
 		ldrb	r3, [r7]	@ zero_extendqisi2
 		ldrb	r2, [r4], #1	@ zero_extendqisi2
		cmp	r3, #1
 		beq	.L3Write
 		cmp	r2, #13
 		cmpne	r2, #10
		movne	r3, #1
		moveq	r3, #0
   		beq	.L4Write
.L3Write:
   		mov	r3, r9
   		ldr	r1, [r8]
 		ldr	r0, [r5]
  		bl	RPI_WriteChar
  		ldr	r3, [r5]
  		cmp	r6, r4
  		add	r3, r3, #BitFontWth
  		str	r3, [r5]
  		bne	.L7Write
.L13WriteExit:
 		mov	r0, r10
		pop	{r4, r5, r6, r7, r8, r9, r10, pc}
.balign	4
.ltorg										;@ Tell assembler ltorg data for this code can go here
.size	_write, .-_write

/* Include the system 8x16 bitfont */
.include "font8x16.inc"

