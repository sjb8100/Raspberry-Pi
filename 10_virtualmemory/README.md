AARCH64 MMU on Raspberry Pi 3
========================================

This is a correction and simplification of the tutorial 10 from bzt it maintains the use of 4K granuals.
https://github.com/bztsrc/raspi3-tutorial/tree/master/10_virtualmemory

TRBR0 is mapped directly to a L2 and L3 table implementation which provide 1:1 translation. 

The L2 sections are 2M and there are maxium of 512 entries per table so each table entry covers a range of 1GB.
1GB = 0x40000000 which covers most of the Pi3 memory space just leaving out the hardware block at 0x40000000+ as detailed on QA7_rev3.4.pdf. Hence we require two entries.

With that in mind the L3 table must be 2 * 512 = 1024 entries in size. The first entry from the L2 table will point to L3[0] and the second entry will point to L3[512].

TBR1 is mapped to a 3 stage L2, L3 , L1 table implementation which covers virtual memory.
I have setup a basic single table page at the L2, L3 and l1 levels in which to create virtual memory allocations.

We start by simply mapping the last entry of the L2 table to the L3 table.
We then map the last entry of the L3 table to the first L1 table.

There are 512 entries each of 4K in size for the L1 table so it covers a range of 2M.
As we have mapped the last page of both the L2 and l3 tables it will mean all FF's at the top of the virtual address

So essentially we have 512, 4K virtual pages available for the 2MB of address range from
0xFFFFFFFFFFE00000 to 0xFFFFFFFFFFFFFFFF

So if you call the function 
uint64_t virtualmap (uint32_t phys_addr);
It will allocate the first unused L1 table entry to the physical Pi address you provide and return the virtual address to you.

In operation the first call will always return 0xFFFFFFFFFFE00000, the second call 0xFFFFFFFFFFE01000, the 3rd 0xFFFFFFFFFFE01000.

Now it's obvious that it is setup  to have an unmap function where the L1 table entry is simply zeroed marking it not in use.


The provided sample "main.c" copies bzt, sample and simply virtual maps the PL011 uart address and hits it using the virtual memory address to prove it's working. 
