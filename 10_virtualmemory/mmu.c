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


// granularity
#define PT_PAGE     0b11        // 4k granule
#define PT_BLOCK    0b01        // 2M granule

// accessibility
#define PT_KERNEL   (0<<6)      // privileged, supervisor EL1 access only
#define PT_USER     (1<<6)      // unprivileged, EL0 access allowed
#define PT_RW       (0<<7)      // read-write
#define PT_RO       (1<<7)      // read-only
#define PT_AF       (1<<10)     // accessed flag
#define PT_NX       (1UL<<54)   // no execute

// shareability
#define PT_OSH      (2<<8)      // outter shareable
#define PT_ISH      (3<<8)      // inner shareable

// defined in MAIR register
#define PT_MEM      (0<<2)      // normal memory
#define PT_DEV      (1<<2)      // device MMIO
#define PT_NC       (2<<2)      // non-cachable


/* The Level 3 ... 1 to 1 mapping */
/* This will have 1024 entries x 2M so a full range of 2GB */
static __attribute__((aligned(4096))) uint64_t L3map1to1[1024] = { 0 };

/* The Level 2 .... 1 to 1 mapping */
static __attribute__((aligned(4096))) uint64_t L2map1to1[512] = { 0 };

/* The Level 3 ... Virtual mapping ... basic minimum of a single table */
static __attribute__((aligned(4096))) uint64_t L3virtual[512] = { 0 };

/* The Level 2 ... Virtual mapping ... basic minimum of a single table */
static __attribute__((aligned(4096))) uint64_t L2virtual[512] = { 0 };

/* The Level 1 ... Virtual mapping ... basic minimum of a single table */
static __attribute__((aligned(4096))) uint64_t L1virtual[512] = { 0 };


void init_page_table(void) {
	uint32_t base = 0;

	// initialize 1:1 mapping for TTBR0
	// 1024MB of ram memory (some belongs to the VC)
	// default: 880 MB ARM ram, 128MB VC


	/* 880Mb of ram */
	for (base = 0; base < 440; base++) {
		// Each block descriptor (2 MB)
		L3map1to1[base] = base << 21 | 0x0000000000000621ul;
	}

	/* VC ram up to 0x3F000000 */
	for (; base < 512 - 8; base++) {
		// Each block descriptor (2 MB)
		L3map1to1[base] = base << 21 | 0x0000000000000665ul;
	}

	/* 16 MB peripherals at 0x3F000000 - 0x40000000*/
	for (; base < 512; base++) {
		// Each block descriptor (2 MB)
		L3map1to1[base] = base << 21 | 0x0000000000000665ul;
	}
	
	// 2 MB for mailboxes at 0x40000000
	// shared device, never execute
	L3map1to1[512] = 512 << 21 | 0x0000000000000665ul;
	++base;

	// unused up to 0x7FFFFFFF
	for (base = 513; base < 1024; base++) {
		L3map1to1[base] = 0;
	}

	// Just 2 valid entries mapping the 2GB in L3
	L2map1to1[0] = (uintptr_t)&L3map1to1[0] | 0x8000000000000003ul;
	L2map1to1[1] = (uintptr_t)&L3map1to1[512] | 0x8000000000000003ul;
	// All the rest of L2 entries are empty 
	for (base = 2; base < 512; base++) {
		L2map1to1[base] = 0;
	}


	// initialize virtual mapping for TTBR1 .. basic 1 page  .. 512 entries x 4096
	// 1024MB of ram memory memory  0xFFFFFFFFFFE00000 to 0xFFFFFFFFFFFFFFFF
	
	// Initially no valid entry maps in 512 entries in L1 virtual table we will add them via virtualmap call
	for (base = 0; base < 512; base++) {
		L1virtual[base] = 0;
	}


	// L3 maps to just 1 valid entry (the last) of the 512 entries pointing to the L1 virtual table
	L3virtual[511] = (uintptr_t)&L1virtual[0] | 0x8000000000000003ul;
	for (base = 0; base < 511; base++) {
		L3virtual[base] = 0;
	}

	// L2 maps has just 1 valid entry (the last) of 512 entries pointing to the L3 virtual table
	L2virtual[511] = (uintptr_t)&L3virtual[0] | 0x8000000000000003ul;
	for (base = 0; base < 511; base++) {
		L2virtual[base] = 0;
	}

}


/**
 * Set up page translation tables and enable virtual memory
 */
void mmu_init()
{
    uint64_t r, b;

    /* create MMU translation tables  */
	init_page_table();

    /* okay, now we have to set system registers to enable MMU */

    // first, set Memory Attributes array, indexed by PT_MEM, PT_DEV, PT_NC in our example
    r=  (0xFF << 0) |    // AttrIdx=0: normal, IWBWA, OWBWA, NTR
        (0x04 << 8) |    // AttrIdx=1: device, nGnRE (must be OSH too)
        (0x44 <<16);     // AttrIdx=2: non cacheable
    asm volatile ("msr mair_el1, %0" : : "r" (r));

	// check for 4k granule and at least 36 bits physical address bus */
	asm volatile ("mrs %0, id_aa64mmfr0_el1" : "=r" (r));
	b = r & 0xF;
	if (r&(0xF << 28)/*4k*/ || b<1/*36 bits*/) {
		/* ERROR: 4k granule or 36 bit address space not supported */
		return;
	}

    // next, specify mapping characteristics in translate control register
    r=  (0b00LL << 37) | // TBI=0, no tagging
        (b << 32) |      // IPS=autodetected
        (0b10LL << 30) | // TG1=4k
        (0b11LL << 28) | // SH1=3 inner
        (0b01LL << 26) | // ORGN1=1 write back
        (0b01LL << 24) | // IRGN1=1 write back
        (0b0LL  << 23) | // EPD1 enable higher half
        (25LL   << 16) | // T1SZ=25, 3 levels (512G)
        (0b00LL << 14) | // TG0=4k
        (0b11LL << 12) | // SH0=3 inner
        (0b01LL << 10) | // ORGN0=1 write back
        (0b01LL << 8) |  // IRGN0=1 write back
        (0b0LL  << 7) |  // EPD0 enable lower half
        (25LL   << 0);   // T0SZ=25, 3 levels (512G)
    asm volatile ("msr tcr_el1, %0; isb" : : "r" (r));

    // tell the MMU where our translation tables are. TTBR_ENABLE bit not documented, but required
    // lower half, user space
	asm volatile ("mov	x0, xzr\n tlbi	aside1is, x0\n"); // Invalidate any L1 table 
    
	asm volatile ("msr ttbr0_el1, %0" : : "r" ((uintptr_t)&L2map1to1[0]));

	// upper half, kernel space AKA the virtual memory
	asm volatile ("msr ttbr1_el1, %0" : : "r" ((uintptr_t)&L2virtual[0]));
	
	// finally, toggle some bits in system control register to enable page translation
    asm volatile ("isb; mrs %0, sctlr_el1" : "=r" (r));
    r|=0xC00800;     // set mandatory reserved bits
    r&=~((1<<25) |   // clear EE, little endian translation tables
         (1<<24) |   // clear E0E
         (1<<19) |   // clear WXN
         (1<<12) |   // clear I, no instruction cache
         (1<<4) |    // clear SA0
         (1<<3) |    // clear SA
         (1<<2) |    // clear C, no cache at all
         (1<<1));    // clear A, no aligment check
    r|=  (1<<0);     // set M, enable MMU
    asm volatile ("msr sctlr_el1, %0; isb" : : "r" (r));
}

uint64_t virtualmap (uint32_t phys_addr) {
	uint64_t addr = 0;
	for (int i = 0; i < 512; i++)
	{
		if (L1virtual[i] == 0) {					// Find the first vacant L1 table slot
			uint64_t offset;
			L1virtual[i] = (uint64_t)(phys_addr) |  // physical address
										 PT_PAGE |
										 PT_AF   |   // accessed flag
						                 PT_OSH  |   // outter shareable
										 PT_DEV;     // device memory
			asm volatile ("dmb sy" ::: "memory");
			offset = ((512 - i) * 4096) - 1;
			addr = 0xFFFFFFFFFFFFFFFFul;
			addr = addr - offset;
			return(addr);
		}
	}
	return (addr);   // error
}
