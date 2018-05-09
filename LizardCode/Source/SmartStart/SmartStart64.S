.section ".init", "ax", %progbits
.balign	4
.globl _start
_start:	

//"================================================================"
//  Initilize MPID/MPIDR registers for all Cores
//"================================================================"
	mrs	x0, midr_el1
	mrs	x1, mpidr_el1
	msr	vpidr_el2, x0
	msr	vmpidr_el2, x1

//"================================================================"
//  Disable coprocessor traps for all Cores
//"================================================================"
	mov	x0, #0x33ff
	msr	cptr_el2, x0						// Disable coprocessor traps to EL2
	msr	hstr_el2, xzr						// Disable coprocessor traps to EL2
	mov	x0, #3 << 20
	msr	cpacr_el1, x0						// Enable FP/SIMD at EL1


	mrs 	x1, mpidr_el1 // Read core id on AARCH64
	and 	x1, x1, #0x3  // Make core 2 bit bitmask in x1
	cbz  	x1, 2f	      // Core 0 jumps out to label 2
	cmp 	x1, #1        // Check for core1
	beq  	1f

    b hang

1:
   
    ldr     x1, =(_start-0x10000)
	mov     sp, x1

	b       core1_main

	 b hang

// core0 main
2:	
    ldr     x1, =_start
	mov     sp, x1


//"================================================================"
//  About to go to into C kernel clear BSS (Core0 only)
//"================================================================"
	ldr x3, =__bss_end__
	ldr x0, =__bss_start__
	cmp	x0, x3
	bcs	.bss_cleared
.bss_zero_loop:
	str	wzr, [x0], 4
	cmp	x3, x0
	bhi	.bss_zero_loop
.bss_cleared:

//"================================================================"
// Code required to be done by core0 for smartstart .. not important
//"================================================================"
	adr x12, _start							// Hold boot address in high register R12
	ldr x1, =RPi_BootAddr					// Address of RPi_BootAddr
	str w12, [x1]							// Store the boot address

	ldr	x0, =0x3F000000						// No need to detect address in 64bit mode it has to be 0x3F000000 on Pi3
	ldr x1, =RPi_IO_Base_Addr				// Address of RPi_IO_Base_Addr
	str w0, [x1]							// Store the IO base address

	mov x0, #1								// Multicore support starts as 1 core
	ldr x1, =RPi_CoresReady					// Address of RPi_CoresReady
	str w0, [x1]							// Store the CoresReady count as 1

	mov x0, #0x98							// Compiled for ARM8 CPU in AARCH64 and supports 4 cores
	ldr x1, =RPi_CompileMode				// Address of RPi_CompileMode
	str w0, [x1]							// Store the compiler mode  

	mrs	x0, midr_el1						// Read CPU Id register
	ldr x1, =RPi_CpuId						// Address of RPi_CpuId
	str w0, [x1]							// Store the CPU id 

//"================================================================"
// Finally that all done Core0 jumps to the C compiler entry point
//"================================================================"
	b kernel_main							// Jump out to C kernel 

/*================================================================"
      Just safety incase C code ever returns back
"================================================================*/
hang:
	b hang
.balign	4
.ltorg										/* Tell assembler ltorg data for code above can go here */


/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{				IRQ HELPER ROUTINES PROVIDE BY RPi-SmartStart API		    }
{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/

/* "PROVIDE C FUNCTION: TimerIrqHandler setTimerIrqAddress ( TimerIrqHandler* ARMaddress);" */
.section .text.setTimerIrqAddress, "ax", %progbits
.balign	4
.globl setTimerIrqAddress;
.type setTimerIrqAddress, %function
setTimerIrqAddress:
	msr daifset,#2							// Disable irq interrupts as we are clearly changing call
	ldr x1, =RPi_TimerIrqAddr				// Load address of function to call on interrupt 
	ldr x2, [x1]							// Load current irq call address
	str x0, [x1]							// Store the new function pointer address we were given
	mov x0, x2								// return the old call function
	ret										// Return
.balign	4
.ltorg										// Tell assembler ltorg data for this code can go here
.size setTimerIrqAddress, .-setTimerIrqAddress

/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{			VC4 ADDRESS HELPER ROUTINES PROVIDE BY RPi-SmartStart API	    }
{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/

/* "PROVIDE C FUNCTION: uint32_t ARMaddrToGPUaddr (void* ARMaddress);" */
.section .text.ARMaddrToGPUaddr, "ax", %progbits
.balign	4
.globl ARMaddrToGPUaddr;		
.type ARMaddrToGPUaddr, %function
//"================================================================"
// ARMaddrToGPUaddr -- AARCH64 Pi3 code
// C Function: uint32_t ARMaddrToGPUaddr (void* ARMaddress);
// Entry: x0 will have ARMAddress value
//"================================================================"
ARMaddrToGPUaddr:
	mov x1, #0xC0000000						// ARM to VC conversion value
	orr x0, x0, x1							// Create bus address
	ret										// Return
.balign	4
.ltorg										// Tell assembler ltorg data for this code can go here
.size	ARMaddrToGPUaddr, .-ARMaddrToGPUaddr


/* "PROVIDE C FUNCTION: uint32_t GPUaddrToARMaddr (uint32_t BUSaddress);" */
.section .text.GPUaddrToARMaddr, "ax", %progbits
.balign	4
.globl GPUaddrToARMaddr;		
.type GPUaddrToARMaddr, %function
//"================================================================"
// GPUaddrToARMaddr -- AARCH64 Pi3 code
// C Function: uint32_t GPUaddrToARMaddr (uint32_t BUSaddress);
// Entry: x0 will have GPUAddress value
//"================================================================"
GPUaddrToARMaddr:
	mov x1, #0xC0000000						// ARM to VC conversion value	
	bic x0, x0, x1							// Create arm address
	ret										// Return
.balign	4
.ltorg										// Tell assembler ltorg data for this code can go here
.size	GPUaddrToARMaddr, .-GPUaddrToARMaddr


/****************************************************************
       	   DATA FOR SMARTSTART64  EXPOSED TO INTERFACE 
****************************************************************/
.section ".data.smartstart64", "aw"
.balign 4

.globl RPi_IO_Base_Addr;				// Make sure Pi_IO_Base_Addr label is global
RPi_IO_Base_Addr : .4byte 0;			// Peripheral Base addr is 4 byte variable in 64bit mode

.globl RPi_BootAddr;					// Make sure RPi_BootAddr label is global
RPi_BootAddr : .4byte 0;				// CPU boot address is 4 byte variable in 64bit mode

.globl RPi_CoresReady;					// Make sure RPi_CoresReady label is global
RPi_CoresReady : .4byte 0;				// CPU cores ready for use is 4 byte variable in 32bit mode

.globl RPi_CPUBootMode;					// Make sure RPi_CPUBootMode label is global
RPi_CPUBootMode : .4byte 0;				// CPU Boot Mode is 4 byte variable in 64bit mode

.globl RPi_CpuId;						// Make sure RPi_CpuId label is global
RPi_CpuId : .4byte 0;					// CPU Id is 4 byte variable in 64bit mode

.globl RPi_CompileMode;					// Make sure RPi_CompileMode label is global
RPi_CompileMode : .4byte 0;				// Compile mode is 4 byte variable in 64bit mode

/****************************************************************
       	   DATA FOR SMARTSTART64  NOT EXPOSED TO INTERFACE 
****************************************************************/
RPi_TimerIrqAddr : .8byte 0;			// Timer Irq Address