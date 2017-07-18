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


extern uint64_t RPi_IO_Base_Addr;									// RPI IO base address auto-detected by SmartStart.S


#ifdef __cplusplus								// If we are including to a C++ file
}												// Close the extern C directive wrapper
#endif

#endif

