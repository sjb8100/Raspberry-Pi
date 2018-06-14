#ifndef _MMU_
#define _MMU_

#ifdef __cplusplus								// If we are including to a C++
extern "C" {									// Put extern C directive wrapper around
#endif
#include <stdint.h>								// Needed for uint8_t, uint32_t, etc

extern uint32_t table_loaded;

void init_page_table (void);

void mmu_init (void);
uint64_t virtualmap(uint32_t phys_addr);

#ifdef __cplusplus								// If we are including to a C++ file
}												// Close the extern C directive wrapper
#endif

#endif
