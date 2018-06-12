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

SECTIONS
{
    . = 0x80000;
	
	/* If init section exists must conform to the bootloader's expectation by putting this code first */
	.init : {
		KEEP(*(.init))
	}
	
	/* Next comes the code data including any boot section which is the other name for init */
    .text : { 
		__text_start__ = .;			/* Label in case we want address of text section start */
		KEEP(*(.text.boot)) *(.text .text.* .gnu.linkonce.t*)
		__text_end__ = .;      		/* Label in case we want address of text section end */
	}

	/* Next comes the constant data  */
    .rodata : { 
		__rodata_start__ = .;		/* Label in case we want address of rodata section start */
		*(.rodata .rodata.* .gnu.linkonce.r*)
		__rodata_end__ = .;			/* Label in case we want address of rodata section start */
	}
    
	. = ALIGN(4096);
    PROVIDE(_data = .);
	
	/* Next comes data section  */
    .data : { 
		__data_start__ = .;     	/* Label in case we want address of data section start */
		*(.data .data.* .gnu.linkonce.d*)
		__data_end__ = .;     		/* Label in case we want address of data section end */
	}

	/* Next comes data1 which is align16 data section  */
    .data1 : { 
		. = ALIGN(16);
		__data1_start__ = .;     	/* Label in case we want address of data1 section start */
		*(.data1 .data1.*)
		__data1_end__ = .;     		/* Label in case we want address of data1 section end */
	}

	/* Next comes BSS section  */
    .bss (NOLOAD) : {
        . = ALIGN(16);
        __bss_start = .;
		__bss_start__ = .;
        *(.bss .bss.*)
        *(COMMON)
        __bss_end = .;
		__bss_end__ = .;
    }
    . = ALIGN(4096);
    _end = .;

   /DISCARD/ : { *(.comment) *(.gnu*) *(.note*) *(.eh_frame*) }
}
__bss_size = (__bss_end - __bss_start)>>3;
