CC=arm-linux-gnueabi-gcc -v 
LD=arm-linux-gnueabi-ld

CFLAGS=-g -Os -fno-common -gdwarf-2  -DTEXT_BASE=0x10000000 -fno-builtin -ffreestanding -nostdinc -isystem /opt/ilomtools/crosscompiler/gcc-4.4__110228/arm/lib/gcc/arm-linux-gnueabi/4.4.5/include \
              -marm  -mabi=aapcs-linux -mno-thumb-interwork -march=armv5te -pipe  -Wall -fno-strict-aliasing
LFLAGS=-L /opt/ilomtools/crosscompiler/gcc-4.4__110228/arm/lib/gcc/arm-linux-gnueabi/4.4.5 -lgcc

S_OBJS    = $(patsubst %.S,%.o,$(wildcard *.S))
C_OBJS    = $(patsubst %.c,%.o,$(wildcard *.c))
build_obj = $(S_OBJS) $(C_OBJS)

all : stoneware.elf stoneware.lod

%.o : %.S
	$(CC)  $(CFLAGS)  -o $@ $< -c

%.o : %.c
	$(CC)  $(CFLAGS)  -o $@ $< -c

stoneware.elf : $(build_obj)
	$(LD) -Bstatic -T stoneware.lds -Ttext 0x10000000 $(build_obj) $(LFLAGS) -Map $(@:.elf=.map) -o $@
	arm-linux-gnueabi-objcopy --gap-fill=0xff -O binary --pad-to 0x0 stoneware.elf stoneware.bin

stoneware.lod : stoneware.bin
	$(PWD)/lod.pl --objname=$< > $@


clean:
	@rm -rf *.lod *.elf *.o *.bin *.map
