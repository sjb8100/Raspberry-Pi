// To keep this in the first portion of the binary.
.section ".text.boot", "x"
.globl _start

_start:
	ldr pc, reset_handler
	ldr pc, undefined_handler
	ldr pc, swi_handler
	ldr pc, prefetch_handler
	ldr pc, data_handler
	ldr pc, unused_handler
	ldr pc, irq_handler
	ldr pc, fiq_handler
reset_handler:      .word reset
undefined_handler:  .word hang
swi_handler:        .word hang
prefetch_handler:   .word hang
data_handler:       .word hang
unused_handler:     .word hang
irq_handler:        .word irq
fiq_handler:        .word hang

;//=================================================================
;@ .BSS section of C compiler will be declared by linker script
;//=================================================================
.extern __bss_start
.extern __bss_end

;//=================================================================
;@ We will return the RPi_IO_Base_Addr in this data memory variable
;//=================================================================
.globl RPi_IO_Base_Addr;
.globl RPi_CpuId;
.data
RPi_IO_Base_Addr: .word 0;
RPi_CpuId: .word 0;

reset:
;//=================================================================
;@ Read the Arm Main CPUID register => sets RPi_CpuId
;//=================================================================
	ldr r7, =RPi_CpuId
	mrc p15,0, r0,c0,c0,0 ;			// Read Main ID Register
	str r0, [r7]

;//=================================================================
;@ Auto-Detect Raspberry PI IO base address => sets RPi_IO_Base_Addr
;//=================================================================
	ldr r4, =#0x61757830
	ldr r7, =#0x20215010
	ldr r3, [r7];		// Fetch value at 0x20215010 being uart0
	cmp r3, r4;			// Check if we have the value the uart0 will be at reset
	bne .not_pi_1

;@ **** Detected Pi at Pi1 address being 0x20000000 ******
	ldr r7, =RPi_IO_Base_Addr
	mov	r3, #0x20000000
	str	r3, [r7]
	b .autodetect_done;

.not_pi_1:
	ldr r7, =#0x3f215010
	ldr r3, [r7];		// Fetch value at 0x3f215010
	cmp r3, r4;			// Check if we have the value the uart0 will be at reset
	beq .pi_found

;@ **** Auto-Detected failed it is not safe to do anything but deadloop  ******
.pi_detect_fail:
	b .pi_detect_fail

;@ **** Detected Pi at Pi2/3 address being 0x3f000000 ******
.pi_found:
;@ Pi2 address 0x3f000000
	ldr r7, =RPi_IO_Base_Addr
	mov	r3, #0x3f000000
	str	r3, [r7]

.autodetect_done:

;//=================================================================
;@ Clear the .BSS segment
;//=================================================================
	ldr   r0, =__bss_start
	ldr   r1, =__bss_end	
	mov   r2, #0

.clear_bss:
    cmp   r0, r1
    bge   .clear_bss_exit
    str   r2, [r0]
	add   r0, r0, #4
    b .clear_bss

.clear_bss_exit:

;//=================================================================
;@ Bring fpu online
;//=================================================================

;@ global acces to fpu for everyone
	mrc p15, 0, r0, c1, c1, 2
	orr r0, r0, #3<<10
	mcr p15, 0, r0, c1, c1, 2

;@ enable fpu
	mrc p15,0,r0,c1,c0, #2			// R0 = Access Control Register
	orr r0, #(0x300000 + 0xC00000)	// Enable Single & Double Precision
	mcr p15,0,r0,c1,c0, #2			// Access Control Register = R0
	mov r0, #0x40000000				// R0 = Enable VFP
	vmsr fpexc,r0					// FPEXC = R0


.if (BCM2836 == 1 || BCM2837 == 1)
	mrc  p15, 0, r0, c0, c0, 5
	ands r0, r0, #0x3
	beq  reset_single_c0
reset_single_cn:
	wfi
	b    reset_single_cn
reset_single_c0:
.endif

.if (BCM2836 == 1) || (BCM2837 == 1)
	/* non-secure */
	mrc p15, 0, r0, c1, c1, 0
	orr r0, r0, #0x1
	mcr p15, 0, r0, c1, c1, 0
.endif

.if BCM2837 == 1
	/* stop caching */
	mov r12, #0
	mcr p15, 0, r12, c7, c10, 1
	dsb
	mov r12, #0
	mcr p15, 0, r12, c7, c5, 0
	mov r12, #0
	mcr p15, 0, r12, c7, c5, 6
	dsb
	isb
.endif

;//=================================================================
;@ Enable L1 Cache
;//=================================================================
	mrc p15, 0, r0, c1, c0, 0	;@ r0 = System Control Register
	orr r0, #0x0004			;@ Data Cache (Bit 2)
	orr r0, #0x0800			;@ Branch Prediction (Bit 11)
	orr r0, #0x1000			;@ Instruction Caches (Bit 12)
	mcr p15, 0, r0, c1, c0, 0	;@ System Control Register = R0


.if (BCM2835 == 0) && (MULTI_CPU == 1)
	/* core branch */
	mrc p15, 0, r0, c0, c0, 5
	and r0, r0, #0x3
	cmp r0, #1
	beq reset_c1
	cmp r0, #2
	beq reset_c2
	cmp r0, #3
	beq reset_c3
.endif


.if (BCM2835 == 1) || (HYP_MODE == 1)
	/* copy vector */
	mov r0,#0x8000
	mov r1,#0x0000
	ldmia r0!,{r2-r9}
	stmia r1!,{r2-r9}
	ldmia r0!,{r2-r9}
	stmia r1!,{r2-r9}
.endif

.if (HYP_MODE == 1)
	mov r1, #0	/* start address */
	/* Core 1 wakeup (WPI sleeping -> interrupt) */
	ldr r0, =0x4000009C	/* Core 1 Mailbox 3 write-set */
	str r1, [r0]
	/* Core 2 wakeup (WPI sleeping -> interrupt) */
	ldr r0, =0x400000AC	/* Core 2 Mailbox 3 write-set */
	str r1, [r0]
	/* Core 3 wakeup (WPI sleeping -> interrupt) */
	ldr r0, =0x400000BC	/* Core 3 Mailbox 3 write-set */
	str r1, [r0]
.endif

	/* set IRQ stack */
	mov r0, #0xD2
	msr cpsr_c, r0	;@ (PSR_IRQ_MODE|PSR_FIQ_DIS|PSR_IRQ_DIS)
	mov sp, #0x8000
	/* set FIQ stack */
	mov r0, #0xD1
	msr cpsr_c, r0	;@ (PSR_FIQ_MODE|PSR_FIQ_DIS|PSR_IRQ_DIS)
	mov sp, #0x4000
	/* set SVC stack */
	mov r0, #0xD3
	msr cpsr_c, r0	;@ (PSR_SVC_MODE|PSR_FIQ_DIS|PSR_IRQ_DIS)
	ldr r0, =stack_top
	mov sp, r0


bl  kernel_main

hang:
  b hang

reset_c1:
	/* set IRQ stack */
	mov r0, #0xD2
	msr cpsr_c, r0	;@ (PSR_IRQ_MODE|PSR_FIQ_DIS|PSR_IRQ_DIS)
	mov sp, #0x7000
	/* set FIQ stack */
	mov r0, #0xD1
	msr cpsr_c, r0	;@ (PSR_FIQ_MODE|PSR_FIQ_DIS|PSR_IRQ_DIS)
	mov sp, #0x3000
	/* set SVC stack */
	mov r0, #0xD3
	msr cpsr_c, r0	;@ (PSR_SVC_MODE|PSR_FIQ_DIS|PSR_IRQ_DIS)
	ldr r0, =0x7F80000
	mov sp, r0

	bl kernel_main
	b hang

reset_c2:
	/* set IRQ stack */
	mov r0, #0xD2
	msr cpsr_c, r0	;@ (PSR_IRQ_MODE|PSR_FIQ_DIS|PSR_IRQ_DIS)
	mov sp, #0x6000
	/* set FIQ stack */
	mov r0, #0xD1
	msr cpsr_c, r0	;@ (PSR_FIQ_MODE|PSR_FIQ_DIS|PSR_IRQ_DIS)
	mov sp, #0x2000
	/* set SVC stack */
	mov r0, #0xD3
	msr cpsr_c, r0	;@ (PSR_SVC_MODE|PSR_FIQ_DIS|PSR_IRQ_DIS)
	ldr r0, =0x7F00000
	mov sp, r0

	bl kernel_main
	b hang

reset_c3:
	/* set IRQ stack */
	mov r0, #0xD2
	msr cpsr_c, r0	;@ (PSR_IRQ_MODE|PSR_FIQ_DIS|PSR_IRQ_DIS)
	mov sp, #0x5000
	/* set FIQ stack */
	mov r0, #0xD1
	msr cpsr_c, r0	;@ (PSR_FIQ_MODE|PSR_FIQ_DIS|PSR_IRQ_DIS)
	mov sp, #0x1000
	/* set SVC stack */
	mov r0, #0xD3
	msr cpsr_c, r0	;@ (PSR_SVC_MODE|PSR_FIQ_DIS|PSR_IRQ_DIS)
	ldr r0, =0x7E80000
	mov sp, r0
	bl kernel_main
	b hang

irq:
    push {r0,r1,r2,r3,r4,r5,r6,r7,r8,r9,r10,r11,r12,lr}
    bl c_irq_handler
    pop  {r0,r1,r2,r3,r4,r5,r6,r7,r8,r9,r10,r11,r12,lr}
    subs pc,lr,#4

