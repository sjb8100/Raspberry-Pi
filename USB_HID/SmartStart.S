#include "rpi-smartstart.h"

/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{       Filename: smartstart.s									}
{       Copyright(c): Leon de Boer(LdB) 2017					}
{       Version: 1.01											}
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

.section ".text.startup", "ax", %progbits
.balign	4
.globl _start
.syntax unified
.arm
_start:
	mov r12, pc;							;@ Hold boot address in high register R12
	ldr sp, =__usrsys_stack					;@ This is just a safety if all hell breaks loose
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
	bl  RPi_CheckAndExitHypModeToSvcMode;	;@ First check for HYP_MODE and if in it drop out to SRV_MODE

;@"================================================================"
;@ Now setup stack pointers for the different CPU operation modes.
;@"================================================================"
    msr CPSR_c, #0xD1						;@ Switch to FIQ_MODE
	ldr sp, =__fiq_stack					;@ Set the stack pointer for that mode
	msr CPSR_c, #0xD2						;@ Switch to IRQ_MODE
    ldr sp, =__irq_stack					;@ Set the stack pointer for that mode
	msr CPSR_c, #0xD3						;@ Switch back to SRV_MODE
    ldr sp, =__svc_stack					;@ Set the stack pointer for that mode

;@"================================================================"
;@ Fetch and hold CPU changed mode. If we changed modes this value
;@ will now reflect a change from the original held RPi_CPUBootMode.
;@"================================================================"
	mrs r2, CPSR
	ldr r1, =RPi_CPUCurrentMode
	str r2, [r1]						;@ Hold the boot address

;@"================================================================"
;@ Read the Arm Main CPUID register => sets RPi_CpuId
;@"================================================================"
	ldr r1, =RPi_CpuId
	mrc p15,0, r0,c0,c0,0					;@ Read Main ID Register
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
	b    .reset_single_cn
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
	ldr r1, =RPi_CompileMode
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
	ldr r1, =RPi_BusAlias
	mov	r0, #0x40000000
	str	r0, [r1]							;@ Hold bus alias
	ldr r1, =RPi_IO_Base_Addr
	mov	r0, #0x20000000
	str	r0, [r1]							;@ Hold the detected address
	b .autodetect_done;
;@"================================================================"
;@ Try Auto-Detect Raspberry PI IO base address at 2nd position
;@"================================================================"
.not_at_address_1:
	ldr r1, =#0x3f215010
	ldr r0, [r1]							;@ Fetch value at 0x3f215010
	cmp r2, r0								;@ Check if we have the value the uart0 will be at reset
	beq .At2ndAddress
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
	ldr r1, =RPi_BusAlias
	mov	r0, #0xC0000000
	str	r0, [r1]							;@ Hold bus alias
;@ Pi2 address 0x3f000000
	ldr r1, =RPi_IO_Base_Addr
	mov	r0, #0x3f000000						;@ Hold the detected address
	str	r0, [r1]
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
	ldr   r0, =__bss_start__
	ldr   r1, =__bss_end__	
	mov   r2, #0
.clear_bss:
    cmp   r0, r1
    bge   .clear_bss_exit
    str   r2, [r0]
	add   r0, r0, #4
    b .clear_bss
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
    mrc p15,0,r0,c1,c0,0					;@ R0 = System Control Register

    // Enable caches and branch prediction
    orr r0, #SCTLR_ENABLE_BRANCH_PREDICTION
    orr r0, #SCTLR_ENABLE_DATA_CACHE
    orr r0, #SCTLR_ENABLE_INSTRUCTION_CACHE

    mcr p15,0,r0,c1,c0,0					;@ System Control Register = R0
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
_interrupt_vector_h:                .word   hang
_fast_interrupt_vector_h:           .word   hang	



	

/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{    PROCESSOR CONTROLLER HELPER ROUTINES PROVIDE BY RPi-SmartStart API     }
{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/

/* "PROVIDE C FUNCTION: bool RPi_CheckAndExitHypModeToSvcMode (void);" */
.section .text.RPi_CheckAndExitHypModeToSvcMode, "ax", %progbits
.balign	4
.type RPi_CheckAndExitHypModeToSvcMode, %function
.syntax unified
.arm
;@"================================================================"
;@ RPi_CheckAndExitHypModeToSvcMode -- Composite Pi1, Pi2 & Pi3 code
;@ Return: Drops out from HYP_MODE to SRV_MODE and FIQ/IRQ disabled
;@         If not in HYP_MODE will exit unchanged
;@"================================================================"
RPi_CheckAndExitHypModeToSvcMode:
	mrs r0, cpsr							;@ Fetch the cpsr register             
	and r1, r0, #0x1F						;@ Mask off the arm mode bits in register                            
 	cmp r1, #0x1A							;@ check we are in HYP_MODE AKA register reads 1A							
	beq .WeHaveHyperMode
	mov r0, #0;								;@ return false
	bx lr									;@ Return we are not in hypermode
.WeHaveHyperMode:
	bic r0, r0, #0x1F						;@ Clear the mode bits		             
	orr r0, r0, #0xD3						;@ We want SRV_MODE with IRQ/FIQ disabled			
	mov r1, #0								;@ Make sure CNTVOFF to 0 before exit HYP mode
	mcrr p15, #4, r1, r1, cr14				;@ We do not want our clocks going fwd or backwards
	orr r0, r0, #0x100						;@ Set data abort mask	 
	msr spsr_cxsf, r0						;@ Load our request into return status register
	mov r0, #1;								;@ return true
	/* I borrowed this trick from Ultibo because ARM6 code running on an ARM7/8 needs this opcode  */
	/* The ARM6 compiler does not know these instructions so it is a way to get needed opcode here */
    /* So our ARM6 code can drop an arm7 or arm8 out of HYP mode and run on an ARM7/8.             */
 	/* Native ARM7/8 compilers already understand the OPCODE but do not mind it this way either	   */        
	.long 0xE12EF30E						;@ "msr ELR_hyp, lr"
	.long 0xE160006E						;@ "eret"	
;@ No ltorg data required for this function 
.size	RPi_CheckAndExitHypModeToSvcMode, .-RPi_CheckAndExitHypModeToSvcMode

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
	ldr r1, =RPi_CpuId
	ldr r1, [r1]							;@ R1 is carrying CPUID  
	mov r2, #16;							;@ R2 is carrying GPIO Port 16
	ldr r3, =#ARM6_CPU_ID					;@ CPU arm6 id
	cmp r1, r3
	beq Pi1_OR_2_Activity_Led				;@ Arm6 so Pi1 board go straight to Led set code
	mov r2, #18;							;@ R2 is carrying GPIO Port 18
	ldr r3, =#ARM7_CPU_ID					;@ CPU arm7 id
	cmp r1, r3
	beq Pi1_OR_2_Activity_Led				;@ Arm7 so Pi2 board go straight to Led set code
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
	ldr r1, =RPi_IO_Base_Addr
	ldr r1, [r1]
	add r1, r1, #0x200000
	mov r0, #1
	lsl r0, r0, r2							;@ Create a bit mask of the port number
	Memory_Barrier r2
	str r0, [r1, r3]						;@ Write bit shifted to position to port
	Memory_Barrier r2
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
  .4byte RPI_FIRMWARE_SET_GPIO_STATE		;@ Tag Identifier (RPI_FIRMWARE_SET_GPIO_STATE = 0x00038041)
  .4byte 0x00000008							;@ Value Buffer Size In Bytes
  .4byte 0x00000008							;@ 1 bit (MSB) Request/Response Indicator (0=Request, 1=Response), 31 bits (LSB) Value Length In Bytes
  .4byte 130								;@ Pin 130 for activity led
  .4byte 1									;@ 1 for on   0 for off
.4byte   0x00000000							;@ 0x0 (End Tag)
FB_ACTLED_STRUCT_END:
.size	FB_ACTLED_STRUCT, .-FB_ACTLED_STRUCT

/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{            GPIO HELPER ROUTINES PROVIDE BY RPi-SmartStart API             }
{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/

/* "PROVIDE C FUNCTION: bool RPI_GPIO_SetClr (uint8_t gpio_num, bool Set);" */
.section .text.RPI_GPIO_SetClr, "ax", %progbits
.balign	4
.globl RPI_GPIO_SetClr;		
.type RPI_GPIO_SetClr, %function
.syntax unified
.arm
;@"================================================================"
;@ RPI_GPIO_SetClr -- Pi1, 2 & 3 code
;@ C Function: bool RPI_GPIO_SetClr (uint8_t gpio_num, bool Set)
;@ Entry: R0 = GPIO Port Number, R1 = Set/Clear state  (true = set)
;@"================================================================"
RPI_GPIO_SetClr:
    cmp r0, #54								;@ GPIO port number can only be 0..53
	blt .SetClr_GPIO_Valid
	mov r0, #0								;@ Outside valid port number return fail
	bx   lr									;@ Return with fail result
.SetClr_GPIO_Valid:
    cmp r0, #32								;@ Bank 0 is 0..31, Bank 1 is 32 .. 53
	bge .SetClr_GPIO_Bank1
    mov r3, #0x1C							;@ BANK 0 GPIO_BIT_SET offset
    cmp r1, #0 
	beq .SetClr_GPIO     
	mov r3, #0x28							;@ BANK 0 GPIO_BIT_CLR offset
    b .SetClr_GPIO
.SetClr_GPIO_Bank1:
    sub r0, r0, #32							;@  GPIO number % 32
    mov r3, #0x20							;@ BANK 1 GPIO_BIT_SET offset
    cmp r1, #0
	beq .SetClr_GPIO     
	mov r3, #0x2C							;@ BANK 1 GPIO_BIT_CLR offset
.SetClr_GPIO:
    ;@#REGISTERS:  R0 = GPIO port number modulo 32, R3 = GPIO set/clr register offset
  	ldr r1, =RPi_IO_Base_Addr
	ldr r1, [r1]
	add r1, r1, #0x200000					;@ Create GPIO base offset
	mov r2, #1								;@ 1 bit to shift
	lsl r0, r2, r0							;@ shift it by modulo 32 GPIO port number
	Memory_Barrier r2
	str r0, [r1, r3]						;@ Store bit mask  at GPIO base addr + Register offset
	Memory_Barrier r2
	mov r0, #1								;@ return success		  
	bx   lr									;@ Return.
.balign	4
.ltorg										;@ Tell assembler its ok to put ltorg data for above code here
.size	RPI_GPIO_SetClr, .-RPI_GPIO_SetClr

/* "PROVIDE C FUNCTION: bool RPI_GPIO_SetFuncMode (uint8_t gpio_num, FSEL_GPIO_TYPE mode);" */
.section .text.RPI_GPIO_SetFuncMode, "ax", %progbits
.balign	4
.globl RPI_GPIO_SetFuncMode;		
.type RPI_GPIO_SetFuncMode, %function
.syntax unified
.arm
;@"================================================================"
;@ RPI_GPIO_SetFuncMode -- Pi1, 2 & 3 code
;@
;@ C Function: 
;@   bool RPI_GPIO_SetFuncMode (uint8_t gpio_num, FSEL_GPIO_TYPE mode)
;@
;@ Entry: R0 = GPIO Port Number, R1 = FS_TYPE mode to set GPIO to 
;@"================================================================"
RPI_GPIO_SetFuncMode:
    cmp r0, #54								;@ GPIO port number can only be 0..53
	blt .SetFunc_GPIO_Valid
	mov r0, #0								;@ Outside valid port number return fail
	bx   lr									;@ Return with fail
.SetFunc_GPIO_Valid:
    push {r4, r5, fp, lr}					;@ Keep the callee saved registers
	mov r2, #0								;@ Start bank count at 0
.BankCalcLoop:
    cmp r0, #10								;@ Bank 0 is 0..31, Bank 1 is 32 .. 53
	blt .Bank_Calc_Done
	add r2, r2, #1							;@ Inc Bank
	sub r0, r0, #10;						;@ Subtract 10 from gpio number
	b .BankCalcLoop
.Bank_Calc_Done:  
	add r3, r0, r0
	add r3, r3, r0							;@ r3 = shift value = (gpio num % 10) * 3						
	;@#REGISTERS:  R2 = bank,  R3 = GPIO modulo shift 0..27  (shift = (gpio num % 10) * 3)
	mov r4, #04
	mul r4, r4, r2							;@ Port offset is simply 0x04 * bank  (r4 is set)
    mov r2, #7  
	lsl r2, r2, r3							;@ shift mask from GPIO number created (r2 is set)
	lsl r3, r1, r3							;@ GPIO mode shifted by r3 and moved to r3  (r3 set)
	;@#REGISTERS: R2 = shift mask from GPIO number,  R3 = FSEL_GPIO_TYPE mask shifted from GPIO number,  R4 = GPIO port offset
	ldr r5, =RPi_IO_Base_Addr
	ldr r5, [r5]
	add r5, r5, #0x200000					;@ GPIO BASE OFFSET
	Memory_Barrier r0
	ldr r1, [r5, r4]						;@ Read current FSELx 
	Memory_Barrier r0
	bic r1, r1, r2							;@ AND read value with the "NOT" of shift mask
	orr r1, r1, r3							;@ ORR shifted FSEL_GPIO_TYPE bit mask onto R1
	Memory_Barrier r0
	str r1, [r5, r4]						;@ Write r1 to FSELx 
	Memory_Barrier r0
	pop {r4, r5, fp, lr}					;@ Restore the callee saved registers.
	mov r0, #1								;@ return success		  
	bx   lr									;@ Return
.balign	4
.ltorg										;@ Tell assembler its ok to put ltorg data for code above here
.size	RPI_GPIO_SetFuncMode, .-RPI_GPIO_SetFuncMode

/* "PROVIDE C FUNCTION: bool RPI_GPIO_ClrEvent (uint8_t gpio_num);" */
.section .text.RPI_GPIO_ClrEvent, "ax", %progbits
.balign	4
.globl RPI_GPIO_ClrEvent;		
.type RPI_GPIO_ClrEvent, %function
.syntax unified
.arm
;@"================================================================"
;@ RPI_GPIO_ClrEvent -- Pi1, 2 & 3 code
;@ C Function: bool RPI_GPIO_ClrEvent (uint8_t gpio_num)
;@ Entry: R0 = GPIO Port Number
;@"================================================================"
RPI_GPIO_ClrEvent:
    cmp r0, #54								;@ GPIO port number can only be 0..53
	blt .Clr_GPIO_Event_Valid
	mov r0, #0								;@ Outside valid port number return fail
	bx   lr									;@ Return with fail result
.Clr_GPIO_Event_Valid:
    cmp r0, #32								;@ Bank 0 is 0..31, Bank 1 is 32 .. 53
	bge .Clr_GPIO_Bank1_Event
    mov r3, #0x40							;@ GPEDS0 offset
    b .Clr_GPIO_Event
.Clr_GPIO_Bank1_Event:
    sub r0, r0, #32							;@ GPIO number % 32
    mov r3, #0x44							;@ GPEDS1 offset
.Clr_GPIO_Event:
    ;@#REGISTERS:  R0 = GPIO port number modulo 32, R3 = clr event register offset
  	ldr r1, =RPi_IO_Base_Addr
	ldr r1, [r1]
	add r1, r1, #0x200000					;@ Create GPIO base offset
	mov r2, #1								;@ 1 bit to shift
	lsl r0, r2, r0							;@ shift it by modulo 32 GPIO port number
	Memory_Barrier r2
	str r0, [r1, r3]						;@ Write bit mask at GPIO base addr + clear event Register offset
	Memory_Barrier r2
	mov r0, #1								;@ return success		  
	bx   lr									;@ Return.
.balign	4
.ltorg										;@ Tell assembler its ok to put ltorg data for above code here
.size	RPI_GPIO_ClrEvent, .-RPI_GPIO_ClrEvent

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
  .4byte RPI_FRAMEBUFFER_SET_PHYSICAL_WIDTH_HEIGHT;@ Tag Identifier (RPI_FRAMEBUFFER_SET_PHYSICAL_WIDTH_HEIGHT)
  .4byte 0x00000008							;@ Value Buffer Size In Bytes
  .4byte 0x00000008							;@ 1 bit (MSB) Request/Response Indicator (0=Request, 1=Response), 31 bits (LSB) Value Length In Bytes
  .4byte 800								;@ Screen width
  .4byte 600								;@ Screen height
  .4byte RPI_FRAMEBUFFER_SET_VIRTUAL_WIDTH_HEIGHT;@ Tag Identifier (RPI_FRAMEBUFFER_SET_VIRTUAL_WIDTH_HEIGHT)
  .4byte 0x00000008							;@ Value Buffer Size In Bytes
  .4byte 0x00000008							;@ 1 bit (MSB) Request/Response Indicator (0=Request, 1=Response), 31 bits (LSB) Value Length In Bytes
  .4byte 800								;@ Screen width
  .4byte 600								;@ Screen height
  .4byte RPI_FRAMEBUFFER_SET_COLOUR_DEPTH	;@ Tag Identifier (RPI_FRAMEBUFFER_SET_COLOUR_DEPTH)
  .4byte 0x00000004							;@ Value Buffer Size In Bytes
  .4byte 0x00000004							;@ 1 bit (MSB) Request/Response Indicator (0=Request, 1=Response), 31 bits (LSB) Value Length In Bytes
  .4byte 32									;@ Colour depth
  .4byte RPI_FRAMEBUFFER_ALLOCATE_BUFFER	;@ Tag Identifier (RPI_FRAMEBUFFER_ALLOCATE_BUFFER)
  .4byte 0x00000008							;@ Value Buffer Size In Bytes
  .4byte 0x00000004							;@ 1 bit (MSB) Request/Response Indicator (0=Request, 1=Response), 31 bits (LSB) Value Length In Bytes
  .4byte 16									;@ Alignment 16
  .4byte 0									;@ Value will be written here
  .4byte RPI_FRAMEBUFFER_GET_PITCH			;@ Tag Identifier (RPI_FRAMEBUFFER_GET_PITCH)
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
  .4byte RPI_FRAMEBUFFER_GET_PHYSICAL_WIDTH_HEIGHT;@ Tag Identifier (RPI_FRAMEBUFFER_GET_PHYSICAL_WIDTH_HEIGHT)
  .4byte 0x00000008							;@ Value Buffer Size In Bytes
  .4byte 0x00000008							;@ 1 bit (MSB) Request/Response Indicator (0=Request, 1=Response), 31 bits (LSB) Value Length In Bytes
  .4byte 0									;@ Screen width
  .4byte 0									;@ Screen height
  .4byte RPI_FRAMEBUFFER_GET_COLOUR_DEPTH	;@ Tag Identifier (RPI_FRAMEBUFFER_GET_COLOUR_DEPTH)
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
{	PRIVATE SD_CARD EMMC HELPER ROUTINES PROVIDE BY RPi-SmartStart API 	    }
{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/

/* ASSEMBLER NEEDS THESE SD CONSTANTS TO BUILD COMMAND TABLE */

// INTERRUPT register settings
#define INT_AUTO_ERROR   0x01000000
#define INT_DATA_END_ERR 0x00400000
#define INT_DATA_CRC_ERR 0x00200000
#define INT_DATA_TIMEOUT 0x00100000
#define INT_INDEX_ERROR  0x00080000
#define INT_END_ERROR    0x00040000
#define INT_CRC_ERROR    0x00020000
#define INT_CMD_TIMEOUT  0x00010000
#define INT_ERR          0x00008000
#define INT_ENDBOOT      0x00004000
#define INT_BOOTACK      0x00002000
#define INT_RETUNE       0x00001000
#define INT_CARD         0x00000100
#define INT_READ_RDY     0x00000020
#define INT_WRITE_RDY    0x00000010
#define INT_BLOCK_GAP    0x00000004
#define INT_DATA_DONE    0x00000002
#define INT_CMD_DONE     0x00000001
#define INT_ERROR_MASK   (INT_CRC_ERROR|INT_END_ERROR|INT_INDEX_ERROR| \
                          INT_DATA_TIMEOUT|INT_DATA_CRC_ERR|INT_DATA_END_ERR| \
                          INT_ERR|INT_AUTO_ERROR)
#define INT_ALL_MASK     (INT_CMD_DONE|INT_DATA_DONE|INT_READ_RDY|INT_WRITE_RDY|INT_ERROR_MASK)

// STATUS register settings
#define SR_DAT_INHIBIT       0x00000002
#define SR_CMD_INHIBIT       0x00000001

// Block tranfer command controls
#define CMD_IS_DATA      0x00200000
#define TM_MULTI_BLOCK   0x00000020
#define TM_DAT_DIR_HC    0x00000000
#define TM_DAT_DIR_CH    0x00000010
#define TM_BLKCNT_EN     0x00000002
#define TM_MULTI_DATA    (CMD_IS_DATA|TM_MULTI_BLOCK|TM_BLKCNT_EN)

// Command responses as per SD CARD Command Register (Offset 00Eh) 
#define CMD_RSPNS_NO     0x00000000
#define CMD_RSPNS_136    0x00010000
#define CMD_RSPNS_48     0x00020000
#define CMD_RSPNS_48B    0x00030000

// Response types ... on PI, the index and CRC are dropped, leaving 32 bits in RESP0.
#define RESP_NO    0     // No response
#define RESP_R1    1     // 48  RESP0    contains card status
#define RESP_R1b  11     // 48  RESP0    contains card status, data line indicates busy
#define RESP_R2I   2     // 136 RESP0..3 contains 128 bit CID shifted down by 8 bits as no CRC
#define RESP_R2S  12     // 136 RESP0..3 contains 128 bit CSD shifted down by 8 bits as no CRC
#define RESP_R3    3     // 48  RESP0    contains OCR register
#define RESP_R6    6     // 48  RESP0    contains RCA and status bits 23,22,19,12:0
#define RESP_R7    7     // 48  RESP0    contains voltage acceptance and check pattern

// Does the response require RCA
#define RCA_NO     0
#define RCA_YES    0x10000

// Command table positions
#define SD_CMD0			0						// SD card Command 0 is index position 0 in command table  (GO_IDLE_STATE)
#define SD_CMD2			1						// SD card Command 2 is index position 1 in command table  (ALL_SEND_CID)
#define SD_CMD3			2						// SD card Command 3 is index position 2 in command table  (SEND_REL_ADDR)
#define SD_CMD4			3						// SD card Command 4 is index position 3 in command table  (SET_DSR)
#define SD_CMD6			4						// SD card Command 6 is index position 4 in command table  (SWITCH_FUNC)
#define SD_CMD7			5						// SD card Command 7 is index position 5 in command table  (CARD_SELECT)
#define SD_CMD8			6						// SD card Command 8 is index position 6 in command table  (SEND_IF_COND)
#define SD_CMD9			7						// SD card command 9 is index position 7 in command table  (SEND_CSD)
#define SD_CMD10		8						// SD card command 10 is index position 8 in command table (SEND_CID)
#define SD_CMD11		9						// SD card command 11 is index position 9 in command table (VOLTAGE_SWITCH)
#define SD_CMD12		10						// SD card command 12 is index position 10 in command table (STOP_TRANSFER)
#define SD_CMD13		11						// SD card command 13 is index position 11 in command table (SEND_STATUS)
#define SD_CMD15		12						// SD card command 15 is index position 12 in command table (GO_INACTIVE)
#define SD_CMD16		13						// SD card command 16 is index position 13 in command table (SET_BLOCKLEN)
#define SD_CMD17		14						// SD card command 17 is index position 14 in command table (READ_SINGLE_BLOCK)
#define SD_CMD18		15						// SD card command 18 is index position 15 in command table (READ_MULTI_BLOCK)
#define SD_CMD19		16						// SD card command 19 is index position 16 in command table (SEND_TUNING)
#define SD_CMD20		17						// SD card command 20 is index position 17 in command table (SPEED_CLASS)
#define SD_CMD23		18						// SD card command 23 is index position 18 in command table (SET_BLOCKCNT)
#define SD_CMD24		19						// SD card command 24 is index position 19 in command table (WRITE_SINGLE_BLOCK)
#define SD_CMD25		20						// SD card command 25 is index position 20 in command table (WRITE_MULTI_BLOCK)
#define SD_CMD27		21						// SD card command 27 is index position 21 in command table (PROGRAM_CSD)
#define SD_CMD28		22						// SD card command 28 is index position 22 in command table (SET_WRITE_PR)
#define SD_CMD29		23						// SD card command 29 is index position 23 in command table (CLR_WRITE_PR)
#define SD_CMD30		24						// SD card command 30 is index position 24 in command table (SEND_WRITE_PR)
#define SD_CMD32		25						// SD card command 32 is index position 25 in command table (ERASE_WR_START)
#define SD_CMD33		26						// SD card command 33 is index position 26 in command table (ERASE_WR_END)
#define SD_CMD38		27						// SD card command 38 is index position 27 in command table (ERASE)
#define SD_CMD42		28						// SD card command 42 is index position 28 in command table (LOCK_UNLOCK)
#define SD_CMD55		29						// SD card Command 55 with no RCA is index position 29 in that table
#define SD_CMD55_RCA	30						// SD card Command 55 with RCA is index position 30 in that table
#define SD_CMD55_EXT    SD_CMD55_RCA + 2		// Start of extended CMD 55 Commands
#define SD_ACMD6		32						// SD card APP command 6  set Bus width
#define SD_ACMD51		38						// SD card APP command 51 send SCR data

.section .data.sdCommandTable, "aw"
.balign	4
.globl sdCommandTable;
;@ SD CARD COMMAND TABLE
.type sdCommandTable, %object
sdCommandTable:
.4byte 0x00000000 | CMD_RSPNS_NO,									RESP_NO | RCA_NO,		0			;@ GO_IDLE_STATE
.4byte 0x02000000 | CMD_RSPNS_136,									RESP_R2I | RCA_NO,		0			;@ ALL_SEND_CID 
.4byte 0x03000000 | CMD_RSPNS_48,									RESP_R6 | RCA_NO,		0			;@ SEND_REL_ADDR
.4byte 0x04000000 | CMD_RSPNS_NO,									RESP_NO | RCA_NO,		0			;@ SET_DSR
.4byte 0x06000000 | CMD_RSPNS_48,									RESP_R1 | RCA_NO,		0			;@ SWITCH_FUNC
.4byte 0x07000000 | CMD_RSPNS_48B,									RESP_R1b | RCA_YES,		0			;@ CARD_SELECT
.4byte 0x08000000 | CMD_RSPNS_48,									RESP_R7 | RCA_NO,		100			;@ SEND_IF_COND
.4byte 0x09000000 | CMD_RSPNS_136,									RESP_R2S | RCA_YES,		0			;@ SEND_CSD
.4byte 0x0A000000 | CMD_RSPNS_136,									RESP_R2I | RCA_YES ,	0			;@ SEND_CID
.4byte 0x0B000000 | CMD_RSPNS_48,									RESP_R1 | RCA_NO,		0			;@ VOLTAGE_SWITCH
.4byte 0x0C000000 | CMD_RSPNS_48B,									RESP_R1b | RCA_NO,		0			;@ STOP_TRANSFER
.4byte 0x0D000000 | CMD_RSPNS_48,									RESP_R1 | RCA_YES,		0			;@ SEND_STATUS
.4byte 0x0F000000 | CMD_RSPNS_NO,									RESP_NO | RCA_YES,		0			;@ GO_INACTIVE
.4byte 0x10000000 | CMD_RSPNS_48,									RESP_R1 | RCA_NO,		0			;@ SET_BLOCKLEN
.4byte 0x11000000 | CMD_RSPNS_48 | CMD_IS_DATA | TM_DAT_DIR_CH,		RESP_R1 | RCA_NO,		0			;@ READ_SINGLE_BLOCK
.4byte 0x12000000 | CMD_RSPNS_48 | TM_MULTI_DATA | TM_DAT_DIR_CH,	RESP_R1 | RCA_NO,		0			;@ READ_MULTI_BLOCK
.4byte 0x13000000 | CMD_RSPNS_48,									RESP_R1 | RCA_NO,		0			;@ SEND_TUNING
.4byte 0x14000000 | CMD_RSPNS_48B,									RESP_R1b | RCA_NO,		0			;@ SPEED_CLASS
.4byte 0x17000000 | CMD_RSPNS_48,									RESP_R1 | RCA_NO,		0			;@ SET_BLOCKCNT
.4byte 0x18000000 | CMD_RSPNS_48 | CMD_IS_DATA | TM_DAT_DIR_HC,		RESP_R1 | RCA_NO,		0			;@ WRITE_SINGLE_BLOCK
.4byte 0x19000000 | CMD_RSPNS_48 | TM_MULTI_DATA | TM_DAT_DIR_HC,	RESP_R1 | RCA_NO,		0			;@ WRITE_MULTI_BLOCK
.4byte 0x1B000000 | CMD_RSPNS_48,									RESP_R1 | RCA_NO,		0			;@ PROGRAM_CSD
.4byte 0x1C000000 | CMD_RSPNS_48B,									RESP_R1b | RCA_NO,		0			;@ SET_WRITE_PR
.4byte 0x1D000000 | CMD_RSPNS_48B,									RESP_R1b | RCA_NO,		0			;@ CLR_WRITE_PR
.4byte 0x1E000000 | CMD_RSPNS_48,									RESP_R1 | RCA_NO,		0			;@ SND_WRITE_PR
.4byte 0x20000000 | CMD_RSPNS_48,									RESP_R1 | RCA_NO,		0			;@ ERASE_WR_ST
.4byte 0x21000000 | CMD_RSPNS_48,									RESP_R1 | RCA_NO,		0			;@ ERASE_WR_END
.4byte 0x26000000 | CMD_RSPNS_48B,									RESP_R1b | RCA_NO,		0			;@ ERASE
.4byte 0x2A000000 | CMD_RSPNS_48,									RESP_R1 | RCA_NO,		0			;@ LOCK_UNLOCK
.4byte 0x37000000 | CMD_RSPNS_NO,									RESP_NO | RCA_NO,		100			;@ APP_CMD
.4byte 0x37000000 | CMD_RSPNS_48,									RESP_R1 | RCA_YES,		0			;@ APP_CMD
.4byte 0x38000000 | CMD_RSPNS_48,									RESP_R1 | RCA_NO,		0			;@ GEN_CMD

// APP commands must be prefixed by an APP_CMD.
.4byte 0x06000000 | CMD_RSPNS_48,									RESP_R1 | RCA_NO,		0			;@ SET_BUS_WIDTH
.4byte 0x0D000000 | CMD_RSPNS_48,									RESP_R1 | RCA_YES,		0			;@ SD_STATUS
.4byte 0x16000000 | CMD_RSPNS_48,									RESP_R1 | RCA_NO,		0			;@ SEND_NUM_WRBL
.4byte 0x17000000 | CMD_RSPNS_48,									RESP_R1 | RCA_NO,		0			;@ SEND_NUM_ERS
.4byte 0x29000000 | CMD_RSPNS_48,									RESP_R3 | RCA_NO,		50000		;@ SD_SENDOPCOND
.4byte 0x2A000000 | CMD_RSPNS_48,									RESP_R1 | RCA_NO,		0			;@ SET_CLR_DET
.4byte 0x33000000 | CMD_RSPNS_48 | CMD_IS_DATA | TM_DAT_DIR_CH,		RESP_R1 | RCA_NO,		0			;@ SEND_SCR
.size	 sdCommandTable, .-sdCommandTable


.section .text.SD_WaitingOnInterrupt, "ax", %progbits
.balign	4			
.type SD_WaitingOnInterrupt, %function
.syntax unified
.arm
;@"================================================================"
;@ SD_WaitingOnInterrupt -- Pi1, 2 & 3 code
;@
;@ Internal Function: 
;@   Waits until either a SD timeout or card interrupt signalled
;@
;@ Return: 0 for success, SD error values for failure id source
;@"================================================================"
SD_WaitingOnInterrupt:
        mov     r3, #SD_OK
        stmfd   sp!, {r4, r5, r6, r7, r8, lr}
        mov     r6, r0						;@ Hold mask
        ldr     r7, =RPi_SD_Error
		ldr     r5, =#INT_ERROR_MASK
        orr     r5, r0, #0
	    ldr     r4, =#1000000				;@ Timeout 1 second
        ldr     r8, =RPi_IO_Base_Addr		;@ Fetch base address pointer
		ldr		r8, [r8]
		add     r8, r8, #0x300000			;@ SD card IO base offset
        sub     sp, sp, #8
        str     r3, [r7]					;@ Preset Rpi_SD_Error = SD_OK
.WaitForMaskLoop:
        mov     r0, #1
        mov     r1, #0
        bl      RPI_WaitMicroSeconds		;@ Wait 1 microsecond
		ldr     r2, [r8, #48]				;@ Read Interrupt status				
        Memory_Barrier r0
		str     r2, [sp, #4]				;@ Hold that status
        tst     r2, r5
        bne     .SDCheckWaitTimeOut
        subs    r4, r4, #1
        bcs     .WaitForMaskLoop
        ldr     r2, [sp, #4]				;@ Fetch back int status
        tst     r2, #65536
        beq     .CheckSDWaitExitMasks
.SDMaskWaitTimeOut:
        mov     r2, #SD_TIMEOUT				;@ Mask has timed out
        ldr     r6, [sp, #4]				;@ Fetch back held int status
        str     r2, [r7]					;@ RPI_Error = SD_TIMEOUT
.ExitSDWaitInt:
        str     r6, [r8, #48]				;@ Clear the interrupt register
        ldr     r0, [r7]					;@ Fetch the SD error status
        ldr     r4, =RPi_SD_Error
        cmp     r0, #SD_OK
        beq     .SDWaitSuccess
        ldr     r3, =RPi_SD_Errorhandler	;@ Fetch SD error handler address
        ldr     r3, [r3]					;@ Fetch the SD error handler itself
        cmp     r3, #0						;@ Chek if handler is zero
        beq     .SDWaitSuccess				;@ Just exit if it is
        blx     r3							;@ None zero call the handler
        ldr     r0, [r4]					;@ Return with the Error result
.SDWaitSuccess:
        add     sp, sp, #8
        ldmfd   sp!, {r4, r5, r6, r7, r8, pc}
.SDCheckWaitTimeOut:
        cmp     r4, #0
        beq     .SDMaskWaitTimeOut
        ldr     r2, [sp, #4]				;@ Fetch held int status
        tst     r2, #65536					
        bne     .SDMaskWaitTimeOut
.CheckSDWaitExitMasks:
        ldr     r2, [sp, #4]
        tst     r2, #1048576
        bne     .SDMaskWaitTimeOut
        ldr     r1, [sp, #4]
        ldr     r2, =#25067520
        and     r2, r2, r1
        cmp     r2, #0
        movne   r2, #SD_ERROR
        ldrne   r6, [sp, #4]
        strne   r2, [r7]					;@ RPi_SD_Error = SD_ERROR
        b       .ExitSDWaitInt
.balign	4
.ltorg										;@ Tell assembler ltorg data for this code can go here
.size	 SD_WaitingOnInterrupt, .-SD_WaitingOnInterrupt


.section .text.SD_WaitingOnCommand, "ax", %progbits
.balign	4			
.type SD_WaitingOnCommand, %function
.syntax unified
.arm
;@"================================================================"
;@ SD_WaitingOnCommand -- Pi1, 2 & 3 code
;@
;@ Internal Function: 
;@   Waits until either a SD timeout or card command completes
;@
;@ Return: 0 for success, SD error values for failure id source
;@"================================================================"
SD_WaitingOnCommand:
        mov     r3, #SD_OK
        stmfd   sp!, {r4, r5, r6, lr}
        ldr     r5, =RPi_SD_Error
	    ldr     r4, =#1000000				;@ Timeout 1 second
        ldr     r6, =RPi_IO_Base_Addr		;@ Fetch base address pointer
		ldr		r6, [r6]
		add     r6, r6, #0x300000			;@ SD card IO base offset
        sub     sp, sp, #8
        str     r3, [r5]
.SDWaitOnCmdLoop:
        mov     r1, #0
        mov     r0, #1
        bl      RPI_WaitMicroSeconds		;@ Wait 1 microsecond
        Memory_Barrier r0
        ldr     r1, [r6, #36]				;@ Read EMMC status register
        ldr     r3, [r6, #48]				;@ Read EMMC Inteterupt register
		Memory_Barrier r0
        tst     r1, #1
        str     r3, [sp, #4]				;@ hold interrupt register value
        beq     .SDWaitCmdExit
		ldr     r2, =#INT_ERROR_MASK
        and     r2, r2, r3					;@ Check againts int mask
        cmp     r2, #0
        bne     .SDWaitCmdExit
        subs    r4, r4, #SR_CMD_INHIBIT
        bcs     .SDWaitOnCmdLoop
.SDBusyExit:
        mov     r3, #SD_BUSY
        str     r3, [r5]					;@ Set RPi_SD_Error = SD_BUSY
.WaitCmdCheckErrorHandler:
        ldr     r3, =RPi_SD_Errorhandler
        ldr     r3, [r3]					;@ Load error handler func
        cmp     r3, #0						;@ Check handler is not null
        beq     .WaitCmdErrorHandlerNULL	;@ If null just kick over
        blx     r3							;@ Call the error handler
.WaitCmdErrorHandlerNULL:
        ldr     r0, [r5]					;@ Fetch RPi_SD_Error value
        add     sp, sp, #8
        ldmfd   sp!, {r4, r5, r6, pc}		;@ Return
.SDWaitCmdExit:
        cmp     r4, #0
        ble     .SDBusyExit
        ldr     r2, [sp, #4]
        ldr     r3, =#INT_ERROR_MASK
        and     r3, r3, r2
        cmp     r3, #0
        bne     .SDBusyExit
        ldr     r0, [r5]					;@ Fetch RPiSD_Error value
        cmp     r0, #SD_OK					;@ Check against SD_OK
        bne     .WaitCmdCheckErrorHandler
        add     sp, sp, #8
        ldmfd   sp!, {r4, r5, r6, pc}
.balign	4
.ltorg										;@ Tell assembler ltorg data for this code can go here
.size	 SD_WaitingOnCommand, .-SD_WaitingOnCommand


.section .text.SD_WaitingOnData, "ax", %progbits
.balign	4			
.type SD_WaitingOnData, %function
.syntax unified
.arm
;@"================================================================"
;@ SD_WaitingOnData -- Pi1, 2 & 3 code
;@
;@ Internal Function: 
;@   Waits until either a SD timeout or card data xfer completes
;@
;@ Return: 0 for success, SD error values for failure id source
;@"================================================================"
SD_WaitingOnData:
        mov     r3, #SD_OK
        stmfd   sp!, {r4, r5, r6, lr}
        ldr     r5, =RPi_SD_Error
	    ldr     r4, =#500000				;@ Timeout 0.5 second
        ldr     r6, =RPi_IO_Base_Addr		;@ Fetch base address pointer
		ldr		r6, [r6]
		add     r6, r6, #0x300000			;@ SD card IO base offset
        sub     sp, sp, #8
        str     r3, [r5]
.L50SDWaitOnDataLoop:
        mov     r1, #0
        mov     r0, #1
        bl      RPI_WaitMicroSeconds		;@ Wait 1 microsecond
        ldr     r2, =#INT_ERROR_MASK
		Memory_Barrier r0
        ldr     r1, [r6, #36]				;@ Read EMMC status register
        ldr     r3, [r6, #48]				;@ Read EMMC Inteterupt register
        Memory_Barrier r0
		tst     r1, #SR_DAT_INHIBIT
        str     r3, [sp, #4]				;@ hold interrupt register value
        beq     .L49CheckDataDone
        and     r2, r2, r3
        cmp     r2, #0
        bne     .L49CheckDataDone
        subs    r4, r4, #1
        bcs     .L50SDWaitOnDataLoop
.L54CheckDataInt:
        ldr     r2, [sp, #4]
        ldr     r3, =#INT_ERROR_MASK
        and     r3, r3, r2
        cmp     r3, #0
        beq     .L67SDWaitDataExit
.L51WaitDataBusyError:
        mov     r3, #SD_BUSY
        str     r3, [r5]
.L55WaitDataCheckErrorHandler:
        ldr     r3, =#RPi_SD_Errorhandler
        ldr     r3, [r3]
        cmp     r3, #0
        beq     .L65WaitDataErrorHandlerNULL
        blx     r3
.L65WaitDataErrorHandlerNULL:
        ldr     r0, [r5]
        add     sp, sp, #8
        ldmfd   sp!, {r4, r5, r6, pc}
.L49CheckDataDone:
        cmp     r4, #0
        beq     .L51WaitDataBusyError
        b       .L54CheckDataInt
.L67SDWaitDataExit:
        ldr     r0, [r5]
        cmp     r0, #SD_OK
        bne     .L55WaitDataCheckErrorHandler
        add     sp, sp, #8
        ldmfd   sp!, {r4, r5, r6, pc}
.balign	4
.ltorg										;@ Tell assembler ltorg data for this code can go here
.size	 SD_WaitingOnData, .-SD_WaitingOnData


.section .text.SD_GetClockDivider, "ax", %progbits
.balign	4
.type SD_GetClockDivider, %function
.syntax unified
.arm
;@"================================================================"
;@ SD_GetClockDivider -- Pi1, 2 & 3 code
;@
;@ Internal Function: 
;@   Gets the nearest legally matching divider for frequency
;@
;@ Entry: R0 = Requested frequency 
;@ Return: R0 = returns the divider all shifted ready for clock set
;@"================================================================"
SD_GetClockDivider:
        mov     r1, r0
        stmfd   sp!, {r4, lr}
        ldr     r0, =#41666666
        bl      __aeabi_uidiv
        mov     r2, r0
        subs    r0, r0, #1
        beq     .L17sdGetClockDivider
        bl      fls_long
        cmp     r0, #0
        beq     .L17sdGetClockDivider
        sub     r0, r0, #1
        cmp     r0, #7
        movcs   r0, #7
.L17sdGetClockDivider:
        ldr     r3, =RPi_IO_Base_Addr
        ldr     r3, [r3]
        add     r3, r3, #3145728
        add     r3, r3, #252
        ldrb    r1, [r3, #2]    @ zero_extendqisi2
        ldrb    r3, [r3, #2]    @ zero_extendqisi2
        cmp     r1, #1
        movle   r2, #1
        movle   r2, r2, asl r0
        cmp     r2, #2
        movcc   r2, #2
        cmp     r3, #1
        movle   r0, #0
        movgt   r0, r2, lsr #2
        mov     r2, r2, asl #8
        andgt   r0, r0, #192
        and     r2, r2, #65280
        add     r0, r2, r0
        ldmfd   sp!, {r4, pc}
.balign	4
.ltorg										;@ Tell assembler ltorg data for this code can go here
.size	SD_GetClockDivider, .-SD_GetClockDivider


.section .text.SD_SetClockSpeed, "ax", %progbits
.balign	4			
.type SD_SetClockSpeed, %function
.syntax unified
.arm
;@"================================================================"
;@ SD_SetClockSpeed -- Pi1, 2 & 3 code
;@
;@ Internal Function: 
;@   Sets the SD clock speed to the nearest value it can legally do
;@
;@ Entry: R0 = Requested clock speed to set 
;@ Return: 0 for success, SD error values for failure id source
;@"================================================================"
SD_SetClockSpeed:
        stmfd   sp!, {r4, r5, r6, lr}
        ldr     r4, =RPi_IO_Base_Addr
        mov     r6, r0
        ldr     r3, [r4]
        add     r3, r3, #3145728
        ldr     r2, [r3, #36]
        tst     r2, #3
        beq     .L29sdSetClock
        ldr     r5, =#99999
.L30sdSetClock:
        mov     r0, #1
        mov     r1, #0
        bl      RPI_WaitMicroSeconds
        ldr     r3, [r4]
        add     r3, r3, #3145728
        ldr     r2, [r3, #36]
        tst     r2, #3
        bne     .L35sdSetClock
.L29sdSetClock:
        ldr     r2, [r3, #44]
        mov     r1, #0
        bic     r2, r2, #5
        str     r2, [r3, #44]
        mov     r0, #10
        bl      RPI_WaitMicroSeconds
        mov     r0, r6
        bl      SD_GetClockDivider
        ldr     r2, [r4]
        mov     r1, #0
        add     r2, r2, #3145728
        ldr     r3, [r2, #44]
        bic     r3, r3, #1044480
        bic     r3, r3, #4032
        orr     r3, r3, #917504
        orr     r0, r3, r0
        str     r0, [r2, #44]
        mov     r0, #10
        bl      RPI_WaitMicroSeconds
        ldr     r3, [r4]
        mov     r0, #10
        add     r3, r3, #3145728
        ldr     r2, [r3, #44]
        mov     r1, #0
        orr     r2, r2, #1
        str     r2, [r3, #44]
        bl      RPI_WaitMicroSeconds
        ldr     r3, [r4]
        add     r3, r3, #3145728
        ldr     r2, [r3, #44]
        add     r3, r3, #44
        tst     r2, #2
        bne     .L33sdSetClock
        ldr     r5, =#9999
.L34sdSetClock:
        mov     r0, #10
        mov     r1, #0
        bl      RPI_WaitMicroSeconds
        ldr     r3, [r4]
        add     r3, r3, #3145728
        ldr     r2, [r3, #44]
        add     r3, r3, #44
        tst     r2, #2
        beq     .L36sdSetClock
        cmp     r5, #0
        beq     .L37sdSetClock
.L33sdSetClock:
        orr     r2, r2, #4
        str     r2, [r3]
        mov     r0, #SD_OK
        ldmfd   sp!, {r4, r5, r6, pc}
.L35sdSetClock:
        subs    r5, r5, #1
        bne     .L30sdSetClock
        mov     r0, #SD_ERROR_INHIBIT
        ldmfd   sp!, {r4, r5, r6, pc}
.L36sdSetClock:
        subs    r5, r5, #1
        bcs     .L34sdSetClock
.L37sdSetClock:
        mov     r0, #SD_ERROR_CLOCK
        ldmfd   sp!, {r4, r5, r6, pc}
.balign	4
.ltorg										;@ Tell assembler ltorg data for this code can go here
.size	SD_SetClockSpeed, .-SD_SetClockSpeed


.section .text.SD_SendCmdProcessResponse, "ax", %progbits
.balign	4		
.type SD_SendCmdProcessResponse, %function
.syntax unified
.arm
;@"================================================================"
;@ SD_SendCmdProcessResponse -- Pi1, 2 & 3 code
;@
;@ Internal Function: 
;@   Sends a command and processes the response as title says
;@
;@ Entry: Long and complicated
;@ Return: 0 for success, SD error values for failure id source
;@"================================================================"
SD_SendCmdProcessResponse:
 		push	{r4, r5, r6, r7, r8, lr}
 		sub	sp, sp, #8
 		mov	r5, r0
 		mov	r7, r1
 		mov	r6, r2
 		bl	SD_WaitingOnCommand
 		cmp	r0, #SD_OK
 		movne	r0, #SD_BUSY
		beq	.L69sdSendCommandP
.L49sdSendCommandP:
		add	sp, sp, #8
 		pop	{r4, r5, r6, r7, r8, pc}
.L69sdSendCommandP:
 		ldr	r8, =RPi_IO_Base_Addr
 		mov	r4, r0
 		ldr	r3, [r8]
 		add	r3, r3, #3145728
 		ldr	r2, [r3, #48]
 		str	r2, [sp, #4]
 		ldr	r2, [sp, #4]
 		str	r2, [r3, #48]
 		ldr	r3, [r8]
 		add	r3, r3, #3145728
 		str	r7, [r3, #8]
 		ldr	r3, [r8]
 		ldr	r2, [r5]
 		add	r3, r3, #3145728
 		str	r2, [r3, #12]
 		ldr	r0, [r5, #8]
 		cmp	r0, #0
 		bne	.L70sdSendCommandP
.L51sdSendCommandP:
 		mov	r0, #1
 		bl	SD_WaitingOnInterrupt
 		cmp	r0, #0
 		bne	.L49sdSendCommandP
 		ldrh	r3, [r5, #4]
 		adds	r2, r3, #0
 		movne	r2, #1
 		cmp	r6, #0
 		movne	r2, #0
 		cmp	r2, #0
 		beq	.L71sdSendCommandP
.L52sdSendCommandP:
 		mov	r0, #SD_ERROR
 		b	.L49sdSendCommandP
.L70sdSendCommandP:
 		mov	r1, #0
 		bl	RPI_WaitMicroSeconds
 		b	.L51sdSendCommandP
.L71sdSendCommandP:
 		ldr	r2, [r8]
 		add	r2, r2, #3145728
 		ldr	r1, [r2, #16]
 		cmp	r3, #12
 		ldrls	pc, [pc, r3, asl #2]
 		b	.L52sdSendCommandP
.L54sdSendCommandP:
 		.word	.L64sdSendCommandP
 		.word	.L55sdSendCommandP
 		.word	.L56sdSendCommandP
 		.word	.L57sdSendCommandP
 		.word	.L52sdSendCommandP
 		.word	.L52sdSendCommandP
 		.word	.L58sdSendCommandP
 		.word	.L59sdSendCommandP
 		.word	.L52sdSendCommandP
 		.word	.L52sdSendCommandP
 		.word	.L52sdSendCommandP
 		.word	.L55sdSendCommandP
 		.word	.L56sdSendCommandP
.L59sdSendCommandP:
 		mov	r3, #0
 		cmp	r7, r1
 		strb	r3, [r6, #4]
 		strb	r3, [r6, #5]
 		strb	r3, [r6, #6]
 		strb	r3, [r6, #7]
 		bne	.L52sdSendCommandP
.L64sdSendCommandP:
 		mov	r0, r4
 		b	.L49sdSendCommandP
.L58sdSendCommandP:
 		mov	r4, #0
 		lsl	r2, r1, #8
 		lsl	r3, r1, #6
 		and	r0, r2, #4194304
  		lsl	r5, r1, #19
  		and	r3, r3, #524288
 		orr	r3, r3, r0
 		lsr	r5, r5, #19
 		and	r0, r2, #8388608
 		orr	r3, r3, r5
 		orr	r3, r3, r0
 		lsr	r0, r3, #8
 		strb	r0, [r6, #5]
 		lsr	r0, r3, #16
 		strb	r0, [r6, #6]
 		lsr	r0, r3, #24
 		lsr	r2, r1, #16
 		strb	r0, [r6, #7]
 		lsr	r1, r1, #9
  		ldr	r0, =#13107204
 		lsl	r2, r2, #16
 		and	r1, r1, #15
 		uxtb	r5, r2
 		strb	r3, [r6, #4]
 		strb	r1, [r6]
 		and	r0, r0, r3
 		lsr	r1, r1, #24
 		lsr	r3, r2, #16
		lsr	r2, r2, #24
  		mov	lr, r4
  		strb	r1, [r6, #3]
 		strb	r5, [r6, #8]
 		strb	r3, [r6, #10]
 		strb	r2, [r6, #11]
 		strb	r4, [r6, #9]
 		strb	r4, [r6, #1]
 		strb	r4, [r6, #2]
 		b	.L49sdSendCommandP
 .L57sdSendCommandP:
 		mov	r3, #0
 		lsr	lr, r1, #8
  		lsr	ip, r1, #16
 		lsr	r2, r1, #24
  		strb	r1, [r6, #12]
 		mov	r0, r4
 		strb	r3, [r6, #4]
 		strb	r3, [r6, #5]
  		strb	r3, [r6, #6]
 		strb	r3, [r6, #7]
 		strb	lr, [r6, #13]
 		strb	ip, [r6, #14]
 		strb	r2, [r6, #15]
  		b	.L49sdSendCommandP
.L56sdSendCommandP:
 		mov	r0, #0
 		strb	r0, [r6, #4]
 		strb	r0, [r6, #5]
 		strb	r0, [r6, #6]
 		strb	r0, [r6, #7]
 		cmp	r3, #2
  		ldr	r3, [r2, #28]
 		addeq	r6, r6, #16
 		addne	r6, r6, #32
 		str	r3, [r6]
 		ldr	r3, [r8]
 		mov	r0, r4
 		add	r3, r3, #3145728
 		ldr	r2, [r3, #24]
 		str	r2, [r6, #4]
 		ldr	r3, [r3, #20]
 		str	r1, [r6, #12]
 		str	r3, [r6, #8]
		b	.L49sdSendCommandP
.L55sdSendCommandP:
 		mov	r4, #0
 		lsr	r3, r1, #9
 		and	r3, r3, #15
 		ldr	r0, =#-409596
 		lsr	r5, r3, #24
 		lsr	ip, r1, #8
 		strb	r3, [r6]
 		lsr	r2, r1, #16
  		lsr	r3, r1, #24
 		mov	lr, r4
 		strb	r1, [r6, #4]
 		strb	r5, [r6, #3]
 		strb	r4, [r6, #1]
  		strb	r4, [r6, #2]
 		and	r0, r0, r1
 		strb	ip, [r6, #5]
 		strb	r2, [r6, #6]
 		strb	r3, [r6, #7]
 		b	.L49sdSendCommandP
.balign	4
.ltorg										;@ Tell assembler ltorg data for this code can go here
.size	SD_SendCmdProcessResponse, .-SD_SendCmdProcessResponse


.section .text.SD_SendAppCommand, "ax", %progbits
.balign	4			
.type SD_SendAppCommand, %function
.syntax unified
.arm
;@"================================================================"
;@ SD_SendAppCommand -- Pi1, 2 & 3 code
;@
;@ Internal Function: 
;@   Sends an extended SD_CMD55 App command
;@
;@ Entry: R0 = SDHandle* R1 = SDResponse*
;@ Return: 0 for success, SD error values for failure id source
;@"================================================================"
SD_SendAppCommand:
 		push	{r4, lr}
 		subs	r4, r0, #0
 		beq	.L2sdSendAppCommand
 		ldr	r1, [r4, #8]
 		cmp	r1, #0
 		bne	.L3sdSendAppCommand
.L2sdSendAppCommand:
 		mov	r2, #0
		ldr	r0, =sdCommandTable+(SD_CMD55*12)
 		mov	r1, r2
 		bl	SD_SendCmdProcessResponse
 		mov	r0, #0
 		pop	{r4, pc}
.L3sdSendAppCommand:
 		mov	r2, r4
 		ldr	r0, =sdCommandTable+(SD_CMD55_RCA*12)
 		bl	SD_SendCmdProcessResponse
 		cmp	r0, #0
 		ldreq	r0, [r4, #4]
		lsreq	r0, r0, #5
 		eoreq	r0, r0, #1
 		andeq	r0, r0, #1
		pop	{r4, pc}
.balign	4
.ltorg										;@ Tell assembler ltorg data for this code can go here
.size	SD_SendAppCommand, .-SD_SendAppCommand


.section .text.SD_SendCommand, "ax", %progbits
.balign	4		
.type SD_SendCommand, %function
.syntax unified
.arm
;@"================================================================"
;@ SD_SendCommand -- Pi1, 2 & 3 code
;@
;@ Internal Function: 
;@   Sends a normal SD_CMD immediately
;@
;@ Entry: R0 = SDHandle* R1 = SDResponse*
;@ Return: 0 for success, SD error values for failure id source
;@"================================================================"
SD_SendCommand:
 		cmp	r0, #SD_CMD55_EXT-1
 		push	{r4, r5, r6, lr}
 		mov	r4, r0
 		mov	r5, r1
 		bgt	.L20sdSendCommand
.L24sdSendCommand:
 		ldr	r0, =sdCommandTable
 		add	r3, r4, r4, lsl #1
 		add	r0, r0, r3, lsl #2
 		ldrb	r1, [r0, #6]	@ zero_extendqisi2
 		lsl	r1, r1, #16
 		ands	r1, r1, #65536
 		bne	.L21sdSendCommand
.L22sdSendCommand:
 		mov	r2, r5
 		bl	SD_SendCmdProcessResponse
 		cmp	r0, #0
 		popne	{r4, r5, r6, pc}
 		cmp	r5, #0
 		cmpne	r4, #SD_CMD55_EXT-1
 		pople	{r4, r5, r6, pc}
 		ldr	r3, [r5, #8]
 		cmp	r3, #0
 		popeq	{r4, r5, r6, pc}
 		ldr	r3, [r5, #4]
 		tst	r3, #32
 		moveq	r0, #10
 		pop	{r4, r5, r6, pc}
.L21sdSendCommand:
 		ldr	r1, [r5, #8]
 		b	.L22sdSendCommand
.L20sdSendCommand:
 		mov	r0, r1
 		bl	SD_SendAppCommand
 		cmp	r0, #0
 		beq	.L24sdSendCommand
 		pop	{r4, r5, r6, pc}
.balign	4
.ltorg										;@ Tell assembler ltorg data for this code can go here
.size	SD_SendCommand, .-SD_SendCommand


.section .text.sdSendCommandA, "ax", %progbits
.balign	4		
.type sdSendCommandA, %function
.syntax unified
.arm
;@"================================================================"
;@ SD_SendCommandA -- Pi1, 2 & 3 code
;@
;@ Internal Function: 
;@   Sends a normal SD_CMD with argument
;@
;@ Entry: R0 = SDHandle* R1 = SDResponse*
;@ Return: 0 for success, SD error values for failure id source
;@"================================================================"
SD_SendCommandA:
		cmp	r0, #SD_CMD55_EXT-1
 		push	{r4, r5, r6, lr}
 		mov	r4, r0
 		mov	r6, r1
 		mov	r5, r2
 		ble	.L5sdSendCommandA
 		mov	r0, r2
 		bl	SD_SendAppCommand
 		cmp	r0, #0
 		bne	.L15sdSendCommandA
.L5sdSendCommandA:
 		ldr	r3, =sdCommandTable
 		add	r0, r4, r4, lsl #1
 		mov	r1, r6
 		add	r0, r3, r0, lsl #2
 		mov	r2, r5
 		bl	SD_SendCmdProcessResponse
 		cmp	r0, #0
 		bne	.L16sdSendCommandA
 		cmp	r5, #0
 		cmpne	r4, #SD_CMD55_EXT-1
 		pople	{r4, r5, r6, pc}
 		ldr	r3, [r5, #8]
 		cmp	r3, #0
 		popeq	{r4, r5, r6, pc}
 		ldr	r3, [r5, #4]
 		tst	r3, #32
 		moveq	r0, #10
 		pop	{r4, r5, r6, pc}
.L16sdSendCommandA:
 		pop	{r4, r5, r6, pc}
.L15sdSendCommandA:
 		pop	{r4, r5, r6, pc}
.balign	4
.ltorg										;@ Tell assembler ltorg data for this code can go here
.size	SD_SendCommandA, .-SD_SendCommandA


.section .text.SD_AppSendOpCond, "ax", %progbits
.balign	4		
.type SD_AppSendOpCond, %function
.syntax unified
.arm
;@"================================================================"
;@ SD_AppSendOpCond -- Pi1, 2 & 3 code
;@
;@ Internal Function: 
;@   Sends a normal APP_SEND_OP_COND command
;@
;@ Entry: R0 = SDHandle* R1 = SDResponse*
;@ Return: 0 for success, SD error values for failure id source
;@"================================================================"
SD_AppSendOpCond:
 		push	{r4, r5, r6, r7, r8, r9, r10, lr}
 		subs	r5, r1, #0
 		beq	.L7sdAppSendOpCond
 		mov	r1, r0
 		mov	r8, r0
 		mov	r2, r5
 		mov	r0, #36
 		bl	SD_SendCommandA
 		bics	r9, r0, #2
 		popne	{r4, r5, r6, r7, r8, r9, r10, pc}
 		mov	r4, #7
 		mov	r10, #36
 		mov	r7, #0
 		ldr	r6, =#400000
.L3sdAppSendOpCond:
 		ldr	r3, [r5, #12]
 		cmp	r3, #0
 		blt	.L5sdAppSendOpCond
.L15sdAppSendOpCond:
 		subs	r4, r4, #1
 		beq	.L14sdAppSendOpCond
 		mov	r2, r5
 		mov	r1, r8
 		mov	r0, r10
 		bl	SD_SendCommandA
 		cmp	r0, #0
 		beq	.L3sdAppSendOpCond
 		cmp	r0, #2
 		popne	{r4, r5, r6, r7, r8, r9, r10, pc}
 		mov	r0, r6
 		mov	r1, r7
 		bl	RPI_WaitMicroSeconds
 		ldr	r3, [r5, #12]
 		cmp	r3, #0
 		bge	.L15sdAppSendOpCond
.L5sdAppSendOpCond:
 		ldr	r0, =#16744448
 		and	r0, r0, r3
 		cmp	r0, #0
 		movne	r0, r9
 		moveq	r0, #9
 		pop	{r4, r5, r6, r7, r8, r9, r10, pc}
.L14sdAppSendOpCond:
 		mov	r0, #2
 		pop	{r4, r5, r6, r7, r8, r9, r10, pc}
.L7sdAppSendOpCond:
 		mov	r0, #1
 		pop	{r4, r5, r6, r7, r8, r9, r10, pc}
.balign	4
.ltorg										;@ Tell assembler ltorg data for this code can go here
.size	SD_AppSendOpCond, .-SD_AppSendOpCond


.section .text.SD_ReadSCR, "ax", %progbits
.balign	4		
.type SD_ReadSCR, %function
.syntax unified
.arm
;@"================================================================"
;@ SD_ReadSCR -- Pi1, 2 & 3 code
;@
;@ Internal Function: 
;@   Reads the SCR register from the SD CARD
;@
;@ Entry: R0 = support*, R1 = SDResponse*
;@ Return: 0 for success, SD error values for failure id source
;@"================================================================"
SD_ReadSCR:
 		push	{r4, r5, r6, r7, r8, r9, r10, lr}
 		sub	sp, sp, #8
 		mov	r5, r0
 		mov	r4, r1
 		bl	SD_WaitingOnData
 		subs	r8, r0, #0
 		beq	.L32sdReadSCR
.L15sdReadSCR:
 		mov	r0, #2
.L1sdReadSCR:
 		add	sp, sp, #8
 		pop	{r4, r5, r6, r7, r8, r9, r10, pc}
.L32sdReadSCR:
 		ldr	r9, =RPi_IO_Base_Addr
 		ldr	r2, =#65544
 		ldr	r3, [r9]
 		mov	r1, r4
 		add	r3, r3, #3145728
 		str	r2, [r3, #4]
 		mov	r0, #SD_ACMD51
 		bl	SD_SendCommand
 		cmp	r0, #0
 		bne	.L1sdReadSCR
 		mov	r0, #32
 		bl	SD_WaitingOnInterrupt
 		cmp	r0, #0
 		bne	.L1sdReadSCR
 		ldr	r10, =#100000
 		mov	r4, r8
 		mov	r6, #1
 		mov	r7, #0
.L34sdReadSCR:
 		ldr	r3, [r3, #32]
 		cmp	r2, #1
 		str	r3, [r0, #-8]
 		bgt	.L33sdReadSCR
.L5sdReadSCR:
 		mov	r4, r2
.L3sdReadSCR:
 		ldr	r3, [r9]
 		add	r0, sp, #8
 		add	r3, r3, #3145728
 		ldr	r1, [r3, #36]
 		add	r2, r4, #1
 		tst	r1, #2048
		add	r0, r0, r4, lsl #2
  		bne	.L34sdReadSCR
 		mov	r0, r6
   		mov	r1, r7
 		bl	RPI_WaitMicroSeconds
 		subs	r10, r10, #1
 		beq	.L15sdReadSCR
 		mov	r2, r4
 		b	.L5sdReadSCR
.L33sdReadSCR:
 		cmp	r2, #2
 		bne	.L15sdReadSCR
 		cmp	r5, #0
 		beq	.L14sdReadSCR
 		ldr	r3, [sp]
 		tst	r3, #1024
 		ldrne	r2, [r5]
 		orrne	r2, r2, #536870912
 		strne	r2, [r5]
 		tst	r3, #256
 		ldrne	r2, [r5]
 		orrne	r2, r2, #268435456
 		strne	r2, [r5]
 		tst	r3, #33554432
 		ldrne	r2, [r5]
 		orrne	r2, r2, #-2147483648
 		strne	r2, [r5]
 		tst	r3, #16777216
 		beq	.L14sdReadSCR
 		ldr	r3, [r5]
 		mov	r0, r8
 		orr	r3, r3, #1073741824
 		str	r3, [r5]
 		b	.L1sdReadSCR
.L14sdReadSCR:
 		mov	r0, r8
 		b	.L1sdReadSCR
.balign	4
.ltorg										;@ Tell assembler ltorg data for this code can go here
.size	SD_ReadSCR, .-SD_ReadSCR


.section .text.SD_ParseCSD, "ax", %progbits
.balign	4			
.type SD_ParseCSD, %function
.syntax unified
.arm
;@"================================================================"
;@ SD_ParseCSD -- Pi1, 2 & 3 code
;@
;@ Internal Function: 
;@   Parses the CSD from the SD CARD
;@
;@ Entry: R0 = SDHANDLE*, R1 = SDResponse*
;@ Return: 0 for success, SD error values for failure id source
;@"================================================================"
SD_ParseCSD:
 		cmp	r1, #0
 		cmpne	r0, #0
 		push	{r4, r5, r6, r7, r8, r9, lr}
 		moveq	lr, #1
 		movne	lr, #0
 		popeq	{r4, r5, r6, r7, r8, r9, pc}
 		ldrb	r3, [r1, #34]	@ zero_extendqisi2
 		lsl	r3, r3, #16
 		tst	r3, #12582912
 		beq	.L23sdParseCSD
 		ldrb	ip, [r1, #41]	@ zero_extendqisi2
 		ldrb	r3, [r1, #40]	@ zero_extendqisi2
 		ldrb	r2, [r1, #42]	@ zero_extendqisi2
 		orr	r3, r3, ip, lsl #8
 		ldrb	ip, [r1, #43]	@ zero_extendqisi2
 		orr	r3, r3, r2, lsl #16
 		ldr	r2, =#4194303
 		orr	r3, r3, ip, lsl #24
		and	r2, r2, r3, lsr #8
 		mov	r3, #0
 		mov	r5, #2
 		mov	r4, #0
		adds	r2, r2, #1
 		adc	r3, r3, #0
 		lsl	r3, r3, #19
 		orr	r3, r3, r2, lsr #13
 		lsl	r2, r2, #19
 		lsr	ip, r2, #9
 		orr	ip, ip, r3, lsl #23
 		strb	lr, [r0, #24]
 		strb	lr, [r0, #26]
 		strb	lr, [r0, #27]
 		strb	lr, [r0, #8]
 		strb	lr, [r0, #23]
  		uxtb	lr, ip
 		strb	lr, [r0, #16]
  		lsr	lr, ip, #8
  		strb	lr, [r0, #17]
  		lsr	lr, ip, #16
 		lsr	ip, ip, #24
 		strb	lr, [r0, #18]
 		strb	ip, [r0, #19]
 		lsr	lr, r3, #8
 		lsr	ip, r3, #16
 		strb	lr, [r0, #13]
		strb	ip, [r0, #14]
 		lsr	lr, r3, #24
 		lsr	ip, r3, #9
 		strb	r3, [r0, #12]
 		strb	lr, [r0, #15]
 		strb	ip, [r0, #20]
 		lsr	lr, r3, #17
 		lsr	ip, r2, #16
 		lsr	r3, r3, #25
 		lsr	r2, r2, #24
 		strb	lr, [r0, #21]
 		strb	r3, [r0, #22]
 		strb	ip, [r0, #10]
 		strb	r2, [r0, #11]
 		strb	r5, [r0, #25]
 		strb	r4, [r0, #9]
.L21sdParseCSD:
 		ldrb	r3, [r1, #44]	@ zero_extendqisi2
 		and	r3, r3, #12
  		strb	r3, [r0, #42]
 		pop	{r4, r5, r6, r7, r8, r9, pc}
.L23sdParseCSD:
 		ldrb	r3, [r1, #37]	@ zero_extendqisi2
 		ldrb	lr, [r1, #36]	@ zero_extendqisi2
 		mov	r6, #1
 		ldrb	ip, [r1, #40]	@ zero_extendqisi2
 		orr	lr, lr, r3, lsl #8
 		ldrb	r3, [r1, #41]	@ zero_extendqisi2
  		ldrb	r5, [r1, #42]	@ zero_extendqisi2
  		orr	ip, ip, r3, lsl #8
 		orr	ip, ip, r5, lsl #16
 		mov	r5, #0
 		ldrb	r4, [r1, #38]	@ zero_extendqisi2
  		ldrb	r3, [r1, #43]	@ zero_extendqisi2
 		ldrb	r2, [r1, #39]	@ zero_extendqisi2
 		orr	ip, ip, r3, lsl #24
 		orr	lr, lr, r4, lsl #16
  		orr	lr, lr, r2, lsl #24
 		lsr	r3, ip, #7
 		lsl	r4, lr, #10
 		and	r3, r3, #7
 		and	r4, r4, #3072
 		add	r3, r3, #2
 		lsl	r3, r6, r3
 		add	r4, r4, ip, lsr #22
 		adds	r4, r4, #1
  		asr	r9, r3, #31
 		mul	ip, r4, r9
 		adc	r5, r5, #0
 		mla	ip, r3, r5, ip
 		umull	r4, r5, r4, r3
 		lsr	r2, lr, #8
 		and	r2, r2, #15
  		lsl	r2, r6, r2
 		add	r5, ip, r5
 		mov	r8, r3
 		mul	r3, r2, r5
 		asr	r7, r2, #31
 		mla	r3, r4, r7, r3
 		umull	r6, r7, r2, r4
 		add	r7, r3, r7
 		lsr	ip, r6, #8
 		lsr	r3, r6, #16
 		strb	ip, [r0, #9]
 		strb	r3, [r0, #10]
 		lsr	ip, r6, #24
 		lsr	r3, r7, #8
 		lsr	lr, r7, #24
 		strb	r6, [r0, #8]
 		strb	ip, [r0, #11]
 		lsr	r6, r7, #16
 		lsr	ip, r4, #8
 		strb	r3, [r0, #13]
 		lsr	r3, r4, #16
 		strb	r2, [r0, #24]
 		strb	r4, [r0, #16]
 		strb	r7, [r0, #12]
 		strb	r6, [r0, #14]
 		lsr	r7, r4, #24
 		strb	lr, [r0, #15]
 		lsr	r6, r5, #8
 		strb	ip, [r0, #17]
 		lsr	r4, r5, #16
 		lsr	ip, r2, #8
 		lsr	lr, r5, #24
		strb	r3, [r0, #18]
 		lsr	r3, r2, #16
  		lsr	r2, r2, #24
 		strb	r5, [r0, #20]
 		strb	r7, [r0, #19]
 		strb	r6, [r0, #21]
 		strb	r4, [r0, #22]
		strb	lr, [r0, #23]
 		strb	ip, [r0, #25]
 		strb	r3, [r0, #26]
 		strb	r2, [r0, #27]
 		b	.L21sdParseCSD
.balign	4
.ltorg										;@ Tell assembler ltorg data for this code can go here
.size	SD_ParseCSD, .-SD_ParseCSD


.section .text.SD_ParseCID, "ax", %progbits
.balign	4		
.type SD_ParseCID, %function
.syntax unified
.arm
;@"================================================================"
;@ SD_ParseCID -- Pi1, 2 & 3 code
;@
;@ Internal Function: 
;@   Parses the CID from the SD CARD
;@
;@ Entry: R0 = SDHANDLE*, R1 = SDResponse*
;@ Return: 0 for success, SD error values for failure id source
;@"================================================================"
SD_ParseCID:
 		cmp	r1, #0
 		cmpne	r0, #0
 		push	{r4, r5, r6, lr}
		moveq	lr, #1
 		movne	lr, #0
 		popeq	{r4, r5, r6, pc}
 		ldrb	r3, [r1, #18]	@ zero_extendqisi2
 		strb	r3, [r0, #43]
 		ldrb	r2, [r1, #21]	@ zero_extendqisi2
 		ldrb	r3, [r1, #20]	@ zero_extendqisi2
 		ldrb	ip, [r1, #22]	@ zero_extendqisi2
		orr	r3, r3, r2, lsl #8
 		ldrb	r2, [r1, #23]	@ zero_extendqisi2
 		orr	r3, r3, ip, lsl #16
 		orr	r3, r3, r2, lsl #24
 		lsr	r4, r3, #16
 		lsr	ip, r3, #8
		strb	r3, [r0, #47]
 		strb	r2, [r0, #44]
 		strb	r4, [r0, #45]
 		strb	ip, [r0, #46]
 		ldrb	ip, [r1, #27]	@ zero_extendqisi2
 		ldrb	r4, [r1, #26]	@ zero_extendqisi2
 		ldrb	r3, [r1, #24]	@ zero_extendqisi2
 		ldrb	r6, [r1, #25]	@ zero_extendqisi2
 		strb	ip, [r0, #48]
 		strb	lr, [r0, #49]
 		ldrb	r5, [r1, #29]	@ zero_extendqisi2
 		ldrb	r2, [r1, #28]	@ zero_extendqisi2
 		ldrb	lr, [r1, #30]	@ zero_extendqisi2
 		orr	r2, r2, r5, lsl #8
 		ldrb	r1, [r1, #31]	@ zero_extendqisi2
 		orr	r2, r2, lr, lsl #16
 		orr	r3, r3, r6, lsl #8
 		orr	r2, r2, r1, lsl #24
 		orr	r3, r3, r4, lsl #16
 		orr	r3, r3, ip, lsl #24
 		lsr	r1, r2, #16
 		add	r1, r1, r3, lsl #16
 		lsr	ip, r3, #20
 		lsr	r3, r3, #16
 		lsr	r5, r1, #8
 		lsr	r4, r1, #16
 		lsr	lr, r1, #24
 		and	ip, ip, #15
 		and	r3, r3, #15
 		strb	r1, [r0, #36]
 		lsr	r1, r2, #4
 		and	r2, r2, #15
 		strb	r5, [r0, #37]
 		strb	r4, [r0, #38]
 		strb	lr, [r0, #39]
 		strb	r1, [r0, #34]
 		strb	r2, [r0, #35]
 		strb	ip, [r0, #33]
 		strb	r3, [r0, #32]
 		pop	{r4, r5, r6, pc}
;@ NO ltorg for this code
.size	SD_ParseCID, .-SD_ParseCID


.section .text.SD_ResetCard, "ax", %progbits
.balign	4	
.type SD_ResetCard, %function
.syntax unified
.arm
;@"================================================================"
;@ SD_ResetCard -- Pi1, 2 & 3 code
;@
;@ Internal Function: 
;@   Software reset on the SD CARD
;@
;@ Entry: Nothing
;@ Return: 0 for success, SD error values for failure id source
;@"================================================================"
SD_ResetCard:
 		push	{r4, r5, r6, r7, r8, lr}
 		ldr	r7, =RPi_IO_Base_Addr
 		ldr	r2, [r7]		
 		add	r2, r2, #3145728
 		ldr	r1, [r2, #40]					;@ Fetch SD card register Control0
 		ldr r0, =#-118423872				;@ ~0x070F013F AKA ‭0xF8F0FEC0‬
		and r1, r1, r0						;@ Clear the bits
		orr r1, r1, #16777216				;@ 3.3V voltage settings bits set
 		str	r1, [r2, #40]					;@ Update SD card register Control0
		mov	r0, #10
		mov	r1, #0
 		bl	RPI_WaitMicroSeconds
 		ldr	r3, [r7]
 		add	r3, r3, #3145728
 		ldr	r2, [r3, #44]
 		tst	r2, #16777216
 		beq	.L58sdResetCard
 		mov	r4, #10
 		mov	r5, #0
 		ldr	r6, =#9999
 		b	.L51sdResetCard
.L60sdResetCard:
		subs	r6, r6, #1
 		bcc	.L53sdResetCard
 .L51sdResetCard:
 		mov	r0, r4
 		mov	r1, r5
 		bl	RPI_WaitMicroSeconds
 		ldr	r3, [r7]
		add	r3, r3, #3145728
 		ldr	r2, [r3, #44]
 		add	r3, r3, #44
 		tst	r2, #16777216
 		bne	.L60sdResetCard
 		cmp	r6, #0
 		bne	.L49sdResetCard
.L53sdResetCard:
 		mov	r0, #6
 		pop	{r4, r5, r6, r7, r8, pc}
.L58sdResetCard:
 		add	r3, r3, #44
.L49sdResetCard:
 		orr	r2, r2, #917504
 		orr	r2, r2, #1
 		str	r2, [r3]
 		mov	r0, #10
 		mov	r1, #0
 		bl	RPI_WaitMicroSeconds
 		ldr	r0, =#400000
 		bl	SD_SetClockSpeed
 		cmp	r0, #0
 		popne	{r4, r5, r6, r7, r8, pc}
 		mvn	ip, #0
 		ldr	r3, [r7]
 		mov	r2, r0
 		add	r3, r3, #3145728
 		str	ip, [r3, #56]
 		ldr	r3, [r7]
 		mov	r1, r0
 		pop	{r4, r5, r6, r7, r8, lr}
 		add	r3, r3, #3145728
 		str	ip, [r3, #52]
 		ldr	r0, =sdCommandTable
  		b	SD_SendCmdProcessResponse
.balign	4
.ltorg										;@ Tell assembler ltorg data for this code can go here
.size	SD_ResetCard, .-SD_ResetCard


/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{ 	 PUBLIC SD_CARD EMMC HELPER ROUTINES PROVIDE BY RPi-SmartStart API 	    }
{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/

/* "PROVIDE C FUNCTION: uint8_t RPI_sdHostVer (void);" */
.section .text.RPI_sdHostVer, "ax", %progbits
.balign	4
.globl RPI_sdHostVer;		
.type RPI_sdHostVer, %function
.syntax unified
.arm
;@"================================================================"
;@ RPI_sdHostVer -- Composite Pi1, Pi2 & Pi3 code
;@ C Function: uint8_t RPI_sdHostVer (void);
;@ Return: R0 SD Host version (00h = ver1, 01h = ver2, 02h = ver3)
;@"================================================================"
 RPI_sdHostVer:
        ldr     r3, =RPi_IO_Base_Addr
        ldr     r3, [r3]
        add     r3, r3, #3145728
        ldrb    r0, [r3, #254]				;@ Fetch byte offset two AKA byta at offset 0xFE
        bx      lr
.balign	4
.ltorg										;@ Tell assembler ltorg data for this code can go here
.size	RPI_sdHostVer, .-RPI_sdHostVer


/* "PROVIDE C FUNCTION: uint32_t RPI_sdInitCard (SDHANDLE* sdHandle);" */
.section .text.RPI_sdInitCard, "ax", %progbits
.balign	4
.globl RPI_sdInitCard;		
.type RPI_sdInitCard, %function
.syntax unified
.arm
;@"================================================================"
;@ RPI_sdInitCard -- Composite Pi1, Pi2 & Pi3 code
;@ C Function: uint32_t sdInitCard (SDHANDLE* sdHandle);
;@ Return: R0 = 0  for success,  SD Error value otherwise
;@"================================================================"
RPI_sdInitCard:
 		push	{r4, r5, lr}
 		subs	r4, r0, #0
		sub	sp, sp, #52
 		moveq	r5, #1
 		beq	.L18sdInitCard
 		bl	RPI_sdHostVer
 		mov	r3, #0
 		add	r0, r0, #1
 		lsr	ip, r0, #8
 		lsr	r1, r0, #16
 		lsr	r2, r0, #24
 		strb	r0, [r4]
 		strb	ip, [r4, #1]
 		strb	r1, [r4, #2]
 		strb	r2, [r4, #3]
 		strb	r3, [r4, #40]
 		strb	r3, [r4, #41]
 		bl	SD_ResetCard
 		subs	r5, r0, #0
 		beq	.L36sdInitCard
.L18sdInitCard:
 		mov	r0, r5
 		add	sp, sp, #52
 		pop	{r4, r5, pc}
.L36sdInitCard:
 		mov	r1, r5
 		mov	r2, #48
 		mov	r0, sp
 		bl	memset
 		mov	r2, sp
 		ldr	r1, =#426
 		ldr	r0, =sdCommandTable+(SD_CMD8*12)
 		bl	SD_SendCmdProcessResponse
 		subs	r5, r0, #0
 		beq	.L37sdInitCard
 		cmp	r5, #3
 		beq	.L18sdInitCard
 		ldr	r3, =RPi_IO_Base_Addr
 		ldr	r3, [r3]
 		add	r3, r3, #3145728
 		ldr	r3, [r3, #36]
 		tst	r3, #1
 		beq	.L25sdInitCard
 		bl	SD_ResetCard
 		subs	r5, r0, #0
 		bne	.L18sdInitCard
.L25sdInitCard:
 		mov	r1, sp
 		ldr	r0, =#33521664
 		bl	SD_AppSendOpCond
 		subs	r5, r0, #0
 		moveq	r3, #2
			
 		;@ strbeq	r3, [r4, #40] This is a bad instruction for some reason that escapes me so option 2 branch before 
		bne	.L18sdInitCard
		strb	r3, [r4, #40]

 		bne	.L18sdInitCard
.L22sdInitCard:
 		mov	r1, sp
		mov	r0, #1
 		bl	SD_SendCommand
 		subs	r5, r0, #0
 		bne	.L18sdInitCard
 		mov	r1, sp
 		mov	r0, #2
 		bl	SD_SendCommand
 		subs	r5, r0, #0
 		bne	.L18sdInitCard
 		mov	r1, sp
 		mov	r0, #7
 		bl	SD_SendCommand
 		subs	r5, r0, #0
 		bne	.L18sdInitCard
 		mov	r1, sp
 		mov	r0, r4
 		bl	SD_ParseCSD
 		ldr	r0, =#25000000					;@ 25Mhz as nnormal speed
 		bl	SD_SetClockSpeed
 		subs	r5, r0, #0
 		bne	.L18sdInitCard
 		mov	r1, sp
 		mov	r0, #5
 		bl	SD_SendCommand
 		subs	r5, r0, #0
 		bne	.L18sdInitCard
 		mov	r1, sp
 		add	r0, r4, #4
 		bl	SD_ReadSCR
 		subs	r5, r0, #0
 		bne	.L18sdInitCard
 		ldr	r1, [sp, #8]
 		ldrb	ip, [r4, #7]	@ zero_extendqisi2
 		lsr	r0, r1, #8
 		lsr	r2, r1, #16
 		lsr	r3, r1, #24
 		tst	ip, #32
 		strb	r1, [r4, #28]
 		strb	r0, [r4, #29]
 		strb	r2, [r4, #30]
 		strb	r3, [r4, #31]
 		beq	.L26sdInitCard
 		orr	r1, r1, #2
 		mov	r2, sp
 		mov	r0, #32
 		bl	SD_SendCommandA
 		subs	r5, r0, #0
 		bne	.L18sdInitCard
 		ldr	r3, =RPi_IO_Base_Addr
 		ldr	r3, [r3]
 		add	r3, r3, #3145728
 		ldrb	r2, [r3, #40]	@ zero_extendqisi2
 		orr	r2, r2, #2
 		strb	r2, [r3, #40]
.L26sdInitCard:
 		mov	r2, sp
 		mov	r1, #512
 		mov	r0, #13
 		bl	SD_SendCommandA
 		subs	r5, r0, #0
 		bne	.L18sdInitCard
 		mov	r1, sp
 		mov	r0, r4
 		bl	SD_ParseCID
 		b	.L18sdInitCard
.L37sdInitCard:
 		mov	r1, sp
 		ldr	r0, =#1375698944
 		bl	SD_AppSendOpCond
 		subs	r5, r0, #0
 		bne	.L18sdInitCard
 		ldr	r3, [sp, #12]
 		tst	r3, #1073741824
 		movne	r3, #4
 		moveq	r3, #3
 		strb	r3, [r4, #40]
 		b	.L22sdInitCard
.balign	4
.ltorg										;@ Tell assembler ltorg data for this code can go here
.size	RPI_sdInitCard, .-RPI_sdInitCard


/* "PROVIDE C FUNCTION: uint32_t RPI_sdTransferBlocks (SDHANDLE* sdHandle, uint32_t blockaddr, uint32_t numBlocks, uint8_t* buffer, bool write);" */
.section .text.RPI_sdTransferBlocks, "ax", %progbits
.balign	4
.globl RPI_sdTransferBlocks;		
.type RPI_sdTransferBlocks, %function
.syntax unified
.arm
;@"================================================================"
;@ RPI_sdTransferBlocks -- Composite Pi1, Pi2 & Pi3 code
;@ C Function: uint32_t RPI_sdTransferBlocks (SDHANDLE* sdHandle, uint32_t blockaddr, uint32_t numBlocks, uint8_t* buffer, bool write);
;@ Return: R0 = 0  for success,  SD Error value otherwise
;@"================================================================"
RPI_sdTransferBlocks:
 		push	{r4, r5, r6, r7, r8, r9, r10, fp, lr}
 		mov	r6, r0
 		sub	sp, sp, #52
 		mov	r5, r1
 		mov	r7, r2
 		mov	r0, sp
 		mov	r2, #48
 		mov	r1, #0
 		mov	r10, r3
 		ldrb	r4, [sp, #88]	@ zero_extendqisi2
 		bl	memset
 		cmp	r6, #0
 		moveq	r0, #1
 		beq	.L1sdTransferBlocks
 		ldrb	r2, [r6, #29]	@ zero_extendqisi2
 		ldrb	r3, [r6, #28]	@ zero_extendqisi2
 		ldrb	r1, [r6, #30]	@ zero_extendqisi2
 		orr	r3, r3, r2, lsl #8
 		ldrb	r2, [r6, #31]	@ zero_extendqisi2
 		orr	r3, r3, r1, lsl #16
 		orr	r3, r3, r2, lsl #24
 		str	r3, [sp, #8]
 		bl	SD_WaitingOnData
 		subs	r9, r0, #0
 		movne	r0, #2
 		beq	.L41sdTransferBlocks
.L1sdTransferBlocks:
 		add	sp, sp, #52
 		pop	{r4, r5, r6, r7, r8, r9, r10, fp, pc}
.L41sdTransferBlocks:
 		cmp	r4, #0
 		beq	.L42sdTransferBlocks
 		cmp	r7, #1
 		beq	.L27sdTransferBlocks
 		mov	r8, #16
 		mov	fp, #20
.L22sdTransferBlocks:
 		cmp	r7, #1
 		bls	.L37sdTransferBlocks
 		ldrb	r3, [r6, #7]	@ zero_extendqisi2
 		tst	r3, #128
 		bne	.L43sdTransferBlocks
.L37sdTransferBlocks:
 		mov	r0, fp
.L6sdTransferBlocks:
 		ldrb	r3, [r6, #40]	@ zero_extendqisi2
 		mov	r1, r5
 		cmp	r3, #3
 		lsleq	r1, r5, #9
 		ldr	r5, =RPi_IO_Base_Addr
 		lsl	r3, r7, #16
 		ldr	r2, [r5]
 		orr	r3, r3, #512
 		add	r2, r2, #3145728
 		str	r3, [r2, #4]
 		mov	r2, sp
 		bl	SD_SendCommandA
 		cmp	r0, #0
		bne	.L1sdTransferBlocks
 		cmp	r7, #0
 		beq	.L9sdTransferBlocks
 		mov	fp, r9
.L14sdTransferBlocks:
 		mov	r0, r8
 		bl	SD_WaitingOnInterrupt
 		cmp	r0, #0
 		bne	.L1sdTransferBlocks
 		tst	r10, #3
 		mov	r2, r10
 		beq	.L25sdTransferBlocks
 		mov	r3, #4
 		b	.L13sdTransferBlocks
.L44sdTransferBlocks:
 		ldrb	ip, [r2, #1]	@ zero_extendqisi2
 		ldrb	r1, [r2]	@ zero_extendqisi2
 		ldrb	r0, [r2, #2]	@ zero_extendqisi2
 		add	r1, r1, ip, lsl #8
 		add	r1, r1, r0, lsl #16
 		ldrb	ip, [r2, #3]	@ zero_extendqisi2
 		ldr	r0, [r5]
 		add	r3, r3, #4
 		add	r1, r1, ip, lsl #24
 		add	r0, r0, #3145728
 		cmp	r3, #516
 		str	r1, [r0, #32]
 		add	r2, r2, #4
 		beq	.L18sdTransferBlocks
.L13sdTransferBlocks:
		cmp	r4, #0
 		bne	.L44sdTransferBlocks
		ldr	r1, [r5]
 		add	r3, r3, #4
 		add	r1, r1, #3145728
 		ldr	r1, [r1, #32]
 		cmp	r3, #516
 		asr	ip, r1, #8
 		asr	r0, r1, #16
 		strb	r1, [r2]
 		lsr	r1, r1, #24
 		strb	ip, [r2, #1]
 		strb	r0, [r2, #2]
 		strb	r1, [r2, #3]
 		add	r2, r2, #4
 		bne	.L13sdTransferBlocks
.L18sdTransferBlocks:
 		add	fp, fp, #1
 		cmp	r7, fp
 		add	r10, r10, #512
 		bne	.L14sdTransferBlocks
.L45sdTransferBlocks:
 		cmp	r4, #0
 		bne	.L19sdTransferBlocks
.L21sdTransferBlocks:
 		cmp	fp, #1
 		bls	.L26sdTransferBlocks
 		ldrb	r3, [r6, #7]	@ zero_extendqisi2
 		tst	r3, #128
 		bne	.L26sdTransferBlocks
 		mov	r1, sp
 		mov	r0, #10
 		bl	SD_SendCommand
 		b	.L1sdTransferBlocks
.L42sdTransferBlocks:
 		cmp	r7, #1
 		beq	.L28sdTransferBlocks
 		mov	r8, #32
 		mov	fp, #15
 		b	.L22sdTransferBlocks
 .L25sdTransferBlocks:
  		mov	r3, #1
.L10sdTransferBlocks:
 		ldr	r1, [r5]
 		cmp	r4, #0
  		addeq	r1, r1, #3145728
 		ldrne	r0, [r2]
 		ldreq	r1, [r1, #32]
 		addne	r1, r1, #3145728
 		add	r3, r3, #1
 		streq	r1, [r2]
 		strne	r0, [r1, #32]
  		cmp	r3, #129
  		add	r2, r2, #4
 		bne	.L10sdTransferBlocks
 		add	fp, fp, #1
		cmp	r7, fp
 		add	r10, r10, #512
		bne	.L14sdTransferBlocks
 		b	.L45sdTransferBlocks
.L27sdTransferBlocks:
 		mov	r0, #19
 		mov	r8, #16
 		b	.L6sdTransferBlocks
.L28sdTransferBlocks:
 		mov	r0, #14
 		mov	r8, #32
 		b	.L6sdTransferBlocks
.L43sdTransferBlocks:
 		mov	r2, sp
 		mov	r1, r7
 		mov	r0, #18
  		bl	SD_SendCommandA
 		cmp	r0, #0
 		beq	.L37sdTransferBlocks
		b	.L1sdTransferBlocks
.L9sdTransferBlocks:
 		cmp	r4, #0
 		beq	.L1sdTransferBlocks
  		mov	fp, r7
 .L19sdTransferBlocks:
  		mov	r0, #2
  		bl	SD_WaitingOnInterrupt
		cmp	r0, #0
 		beq	.L21sdTransferBlocks
  		b	.L1sdTransferBlocks
.L26sdTransferBlocks:
 		mov	r0, r9
 		b	.L1sdTransferBlocks
.balign	4
.ltorg										;@ Tell assembler ltorg data for this code can go here
.size	RPI_sdTransferBlocks, .-RPI_sdTransferBlocks


/* "PROVIDE C FUNCTION: uint32_t RPI_sdEraseBlocks(SDHANDLE* sdHandle, uint32_t blockaddr, uint32_t numBlocks );" */
.section .text.RPI_sdEraseBlocks, "ax", %progbits
.balign	4
.globl RPI_sdEraseBlocks;		
.type RPI_sdEraseBlocks, %function
.syntax unified
.arm
;@"================================================================"
;@ RPI_sdEraseBlocks -- Composite Pi1, Pi2 & Pi3 code
;@ C Function: uint32_t RPI_sdEraseBlocks(SDHANDLE* sdHandle, uint32_t blockaddr, uint32_t numBlocks);
;@ Return: R0 = 0  for success,  SD Error value otherwise
;@"================================================================"
RPI_sdEraseBlocks:
 		push	{r4, r5, r6, r7, r8, lr}
 		mov	r4, r0
 		sub	sp, sp, #48
 		mov	r5, r1
 		mov	r0, sp
 		mov	r2, #48
 		mov	r1, #0
 		bl	memset
 		cmp	r4, #0
 		moveq	r0, #1
 		beq	.L1sdEraseBlocks
 		ldrb	r2, [r4, #29]	@ zero_extendqisi2
 		ldrb	r3, [r4, #28]	@ zero_extendqisi2
 		ldrb	r1, [r4, #30]	@ zero_extendqisi2
 		orr	r3, r3, r2, lsl #8
 		orr	r3, r3, r1, lsl #16
 		orr	r3, r3, r2, lsl #24
 		str	r3, [sp, #8]
 		bl	SD_WaitingOnData
 		subs	r6, r0, #0
 		beq	.L3sdEraseBlocks
.L6sdEraseBlocks:
 		mov	r0, #2
.L1sdEraseBlocks:
 		add	sp, sp, #48
		pop	{r4, r5, r6, r7, r8, pc}
.L3sdEraseBlocks:
 		ldrb	r3, [r4, #40]	@ zero_extendqisi2
 		mov	r2, sp
 		cmp	r3, #3
 		lsleq	r5, r5, #9
 		mov	r1, r5
 		mov	r0, #25
 		bl	SD_SendCommandA
 		cmp	r0, #0
 		bne	.L1sdEraseBlocks
 		mov	r1, r5
 		mov	r2, sp
 		mov	r0, #26
 		bl	SD_SendCommandA
 		cmp	r0, #0
 		bne	.L1sdEraseBlocks
 		mov	r1, sp
 		mov	r0, #27
 		bl	SD_SendCommand
 		cmp	r0, #0
 		bne	.L1sdEraseBlocks
 		ldr	r8, =RPi_IO_Base_Addr
 		ldr	r3, [r8]
 		add	r3, r3, #3145728
 		ldr	r3, [r3, #36]
 		tst	r3, #2
 		beq	.L9sdEraseBlocks
 		mov	r4, #10
 		mov	r5, #0
 		ldr	r7, =#999999
 		b	.L7sdEraseBlocks
.L8sdEraseBlocks:
 		beq	.L6sdEraseBlocks
.L7sdEraseBlocks:
 		mov	r0, r4
 		mov	r1, r5
 		bl	RPI_WaitMicroSeconds
 		ldr	r3, [r8]
 		add	r3, r3, #3145728
 		ldr	r3, [r3, #36]
 		tst	r3, #2
 		bne	.L8sdEraseBlocks
.L9sdEraseBlocks:
 		mov	r0, r6
 		b	.L1sdEraseBlocks
.balign	4
.ltorg										;@ Tell assembler ltorg data for this code can go here
.size	RPI_sdEraseBlocks, .-RPI_sdEraseBlocks


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

