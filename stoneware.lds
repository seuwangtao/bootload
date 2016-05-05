/*
 */

OUTPUT_FORMAT("elf32-littlearm", "elf32-littlearm", "elf32-littlearm")
OUTPUT_ARCH(arm)
ENTRY(_start)
SECTIONS
{
	. = 0x10000000;
	.text : {
		pbsw_start.o
		*.text
		*.rodata
		. = ALIGN(16); 
	}

	.data : {
		* (.data)
		. = ALIGN(16); 
	}

	.bss : {
	    __bss_start = ABSOLUTE(.);
	    *	(.bss)
		. = ALIGN(16); 
		__bss_end = ABSOLUTE(.);
	}
}
