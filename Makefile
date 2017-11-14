###############################################################################
#	makefile
#	by Leon de Boer
#
#	A makefile script for use from command line or VS2017
###############################################################################

# The toolchain to use. arm-none-eabi works, but there does exist 
# arm-bcm2708-linux-gnueabi.
ARMGNU ?= arm-none-eabi

Pi3: AFLAGS = -mfpu=neon-vfpv4 -mfloat-abi=hard -march=armv8-a
Pi3: CFLAGS = -Wall -O3 -mfpu=neon-vfpv4 -mfloat-abi=hard -march=armv8-a -mtune=cortex-a53 -mno-unaligned-access -fno-tree-loop-vectorize -fno-tree-slp-vectorize -Wnonnull
Pi3: IMGFILE = kernel8-32.img

Pi2: CFLAGS = -Wall -O3 -mfpu=neon -mfloat-abi=hard -march=armv7ve -mtune=cortex-a7 -mno-unaligned-access -fno-tree-loop-vectorize -fno-tree-slp-vectorize -Wnonnull
Pi2: IMGFILE = kernel7.img

Pi1: CFLAGS = -Wall -O3 -mfpu=vfp -mfloat-abi=hard -march=armv6zk -mtune=arm1176jzf-s -mno-unaligned-access -fno-tree-loop-vectorize -fno-tree-slp-vectorize -Wnonnull
Pi1: IMGFILE = kernel.img

LDFLAGS = -nostdlib -nodefaultlibs -nostartfiles -ffreestanding -fno-asynchronous-unwind-tables -fomit-frame-pointer

LIBFLAGS=-lc -lm -lgcc

LINKERFLAGS=-Wl,-gc-sections -Wl,--build-id=none -Wl,-Bdynamic

# The directory in which source files are stored.
SOURCE = source/

# The name of the assembler listing file to generate.
LIST = kernel.list

# The name of the map file to generate.
MAP = kernel.map

# The directory SmartStart files are in
SMARTSTARTDIR = $(SOURCE)SmartStart/

# The name of the linker script to use.
LINKERFILE = $(SMARTSTARTDIR)rpi32.ld

# The SmartStart bootloader file.
SMARTSTARTC := $(wildcard $(SMARTSTARTDIR)*.c)
SMARTSTART = $(SMARTSTARTDIR)SmartStart32.s $(SMARTSTARTC)

# The names of all object files that must be generated. Deduced from the 
# assembly code files in source.
OBJECTS := $(wildcard $(SOURCE)*.c)

# Rule to make everything.
Pi3 Pi2 Pi1: $(LIST)
	
# Rule to remake everything. Does not include clean.
all: Pi3 Pi2 Pi1

# Rule to make the image & listing files.
$(LIST) : kernel.elf
	$(ARMGNU)-objdump -d kernel.elf > $(LIST)
	$(ARMGNU)-objcopy kernel.elf -O binary DiskImg/$(IMGFILE)
	$(ARMGNU)-nm -n kernel.elf > $(MAP)

# Rule to make the elf file.
kernel.elf : $(OBJECTS) 
	$(ARMGNU)-gcc $(CFLAGS) $(LDFLAGS) $(LINKERFLAGS) -Wl,-T,$(LINKERFILE) -I $(SOURCE) $(SMARTSTART) $(OBJECTS) -o $@ $(LIBFLAGS)

# Rule to clean Pi1 files.
Pi1clean : clean
	-rm -f DiskImg/kernel.img

# Rule to clean Pi2 files.
Pi2clean : clean
	-rm -f DiskImg/kernel7.img

# Rule to clean Pi2 files.
Pi3clean : clean
	-rm -f DiskImg/kernel8-32.img

clean:
	-rm -f $(MAP)
	-rm -f kernel.elf
	-rm -f $(LIST)

Pi3Rebuild: clean Pi3
Pi2Rebuild: clean Pi2
Pi1Rebuild: clean Pi1
	
