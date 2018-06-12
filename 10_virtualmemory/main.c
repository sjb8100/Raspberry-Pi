/*
 * Copyright (C) 2018 bzt (bztsrc@github)
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use, copy,
 * modify, merge, publish, distribute, sublicense, and/or sell copies
 * of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 *
 */
#include <stdint.h>
#include "rpi-SmartStart.h"
#include "emb-stdio.h"
#include "mmu.h"


void main()
{
	Init_EmbStdio(Embedded_Console_WriteChar);						// Initialize embedded stdio
	PiConsole_Init(0, 0, 0, printf);								// Auto resolution console, message to screen
	displaySmartStart(printf);										// Display smart start details
	ARM_setmaxspeed(printf);										// ARM CPU to max speed

    char *s="Writing through MMIO mapped in higher half!\r\n";


    // set up serial console
	pl011_uart_init(9600);
    
    // setup mmu
    mmu_init();

	// Map the PL011 uart to first available 4K virtual page
	uintptr_t virtaddr = virtualmap(RPi_IO_Base_Addr + 0x00201000);

	// Create pointers to DR and FR registers via virtual mapping
	volatile __attribute__((aligned(4))) uint32_t* virt_DR = (uint32_t*)virtaddr;
	volatile __attribute__((aligned(4))) uint32_t* virt_FR = (uint32_t*)(virtaddr + 0x18ul);

	// There is something clunky with my 64 bit pointer in emb-stdio .. need to fix
	// This is tehvirtual address allocated
	printf("virtual address allocated: %08p:%08p\n", (void*)(virtaddr >> 32), (void*)(virtaddr & 0xFFFFFFFFul));


    // test 1:1 mapping
    pl011_uart_puts("Writing through identity mapped MMIO.\r\n");

    // test virtual mapping
    while(*s) {
        /* wait until we can send */
        do{asm volatile("nop");}while(*virt_FR & 0x20);
        /* write the character to the buffer */
        *virt_DR=*s++;
    }

    // echo everything back
    while(1) {
        pl011_uart_putc(pl011_uart_getc());
    }
}
