#include "./include/hwmap.h"
#include "./include/hwreg.h"
#include "./include/types.h"

extern void serial_puts(const char *s);
extern tU32 ddrinit_asic(void);
extern int nc_printf(const char *format, ...);
extern int bootspi_init(void);
extern int bootspi_update(tU32 dest, tU32 source, tU32 size);
#define UART3 0x40431000

tU8 p_readbyte(void){
	tU8 val;
	while(1) {   
		val = *(tPVU8)(UART3+0x14); 
		if(val&0x1) {   
			return(*(tPVU8)(UART3));
		}
    
	}  
}

int raise (int signum)
{
		    return 0;
}


void pbsw_main(void)
{
        char input, status = 0;
        char *store_base_addr = (char *)0x80000000;
        char *paddr;
        unsigned int count=0,i;
        unsigned int timer;
        int ret;

	serial_puts("\nx5 repair tool\n");
	nc_printf("version 1.0 \n");

	ddrinit_asic();

	paddr = store_base_addr;
	*paddr++ = 'I';
	*paddr++ = 'L';
	*paddr++ = 'O';
	*paddr++ = 'M';
	*paddr++ = '\n';

	paddr = store_base_addr;
	nc_printf("%c",*paddr++);
	nc_printf("%c",*paddr++);
	nc_printf("%c",*paddr++);
	nc_printf("%c",*paddr++);
	nc_printf("%c",*paddr++);

	nc_printf("init Norflash...\n");
	ret = bootspi_init();	
	if(ret < 0) {
		nc_printf("Norflash init error\n");
		return;
	}

	nc_printf("1. Please send preboot binary file...\n");
	paddr = store_base_addr;
	timer = 0x8ffffff;
	while(!(status&0x1))
		status=(char)(*(tPVU32)(UART3+0x14));

	while(timer) {
		while(status & 0x1) {
			input = (char)(*(tPVU32)(UART3));
			//input = p_readbyte();
			//nc_printf("%c", input);
			*paddr++ = input;
			++count;	
			status=(char)(*(tPVU32)(UART3+0x14));
		}
		timer--;
		status=(char)(*(tPVU32)(UART3+0x14));
	}
	nc_printf("Receive %d bytes\n",count);

#if 1
        paddr = store_base_addr;
        i = 20;
        while(i--)
            nc_printf("%x",*paddr++);
        nc_printf("\n");

        nc_printf("....................\n");
        i = 20;
		paddr = store_base_addr + count -20;
        while(i--)
            nc_printf("%x",*paddr++);
        nc_printf("\n");
#endif

	nc_printf("2. update Norflash...\n");
	bootspi_update(0, store_base_addr, count);
	nc_printf("3. Finished!\n");

	nc_printf("1. Please send u-boot binary file...\n");
	paddr = store_base_addr;
	timer = 0x2fffffff;
	while(!(status&0x1))
		status=(char)(*(tPVU32)(UART3+0x14));

	while(timer) {
		while(status & 0x1) {
			input = (char)(*(tPVU32)(UART3));
			//input = p_readbyte();
			//nc_printf("%c", input);
			*paddr++ = input;
			++count;	
			status=(char)(*(tPVU32)(UART3+0x14));
		}
		timer--;
		status=(char)(*(tPVU32)(UART3+0x14));
	}
	nc_printf("Receive %d bytes\n",count);

#if 1
        paddr = store_base_addr;
        i = 20;
        while(i--)
            nc_printf("%x",*paddr++);
        nc_printf("\n");

        nc_printf("....................\n");
        i = 20;
		paddr = store_base_addr + count -20;
        while(i--)
            nc_printf("%x",*paddr++);
        nc_printf("\n");
#endif
	nc_printf("2. update Norflash...\n");
	bootspi_update(0x40000, store_base_addr, count);
	nc_printf("3. Finished!\n");


	return;
}
