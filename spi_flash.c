#include "./include/types.h"

#define SYSMISCCLKCTL   0x40100120

#define BOOTSPI_BASE    0x40200000 

#define BOOTSPI_ADDR          0x00
#define BOOTSPI_BCMD          0x08
#define BOOTSPI_BTIM          0x0c
#define BOOTSPI_CTRL          0x10
#define BOOTSPI_CLKDIV        0x14
#define BOOTSPI_STS           0x18
#define BOOTSPI_MISC          0x1c
#define BOOTSPI_INTEN         0x20
#define BOOTSPI_CLKDIV1       0x24
#define BOOTSPI_RWDATA        0x30

#define BOOTSPI_CMD0          0x08
#define BOOTSPI_CMD1          0x09
#define BOOTSPI_CMD2          0x0a
#define BOOTSPI_CMD3          0x0b


//spi control reg
#define spi_en       (1<<0)

#define spi_busy                (1<<0)

#define FLASH_PAGE_SiZE 256

extern int nc_printf(const char *format, ...);

void wait_for_spi_not_busy (void) 
{
  while( (*(tPVU8)(BOOTSPI_BASE + BOOTSPI_STS) ) & spi_busy) ;
  return;
}


void bootspi_program_command(tU32 address, tU32 command)
{
	//nc_printf("Addr is %x Cmd is %x\n",address, command);
	if(address != 0xFFFFFFFF){
		*(tPVU32)(BOOTSPI_BASE + BOOTSPI_ADDR) = address;
	}
	*((tPVU32) (BOOTSPI_BASE + BOOTSPI_CMD0)) = command;
	wait_for_spi_not_busy();
}



void bootspi_check_status(tU8 status_bit, tU32 command){
	tU8 data=0;
	*(tPVU32) (BOOTSPI_BASE + BOOTSPI_CMD0) = command;
	wait_for_spi_not_busy();

	data = *(tPVU8) (BOOTSPI_BASE + BOOTSPI_RWDATA);
	
	if(status_bit) {	
		while((data & (1<<status_bit)) != (1<<status_bit))
		{
			data = *(tPVU8) (BOOTSPI_BASE + BOOTSPI_RWDATA);
			//nc_printf("SPI STS : %x\n", data);
		};
	} else {
		while((data & (1<<status_bit)) == (1<<status_bit))
		{
			data = *(tPVU8) (BOOTSPI_BASE + BOOTSPI_RWDATA);
			//nc_printf("SPI STS : %x\n", data);
		};
	}
	//bootspi_change_acessmode_tomem();
}


int bootspi_init(void)
{
    tU32 temp;
    tU32 id_value;
    
    /*init clk*/
    *(tPVU8)(BOOTSPI_BASE + BOOTSPI_CTRL) &= (~(spi_en)); 

    temp = *(tPVU32) (SYSMISCCLKCTL);
    temp &= 0xfffffff0;
    temp |= 4;
    *(tPVU32) (SYSMISCCLKCTL) = temp;

    *(tPVU32) (BOOTSPI_BASE + BOOTSPI_MISC) = 0x05151008;
    *(tPVU16) (BOOTSPI_BASE + BOOTSPI_CLKDIV) = 2;

    *(tPVU8)(BOOTSPI_BASE + BOOTSPI_CTRL) |= (spi_en);

    /*read ID*/
    *(tPVU32)(BOOTSPI_BASE + BOOTSPI_ADDR) = 0x0;
    bootspi_program_command(0xFFFFFFFF, 0x8000019F);
    id_value = *(tPVU32)(BOOTSPI_BASE + BOOTSPI_RWDATA);
    nc_printf("ID is %x\n", id_value);
    if ((id_value& 0xffffff) != 0x1920C2) {
        nc_printf("ID ERROR!\n");
        return -1;
    }

    /*Enable the 4 byte support by default*/
    *(tPVU32) (BOOTSPI_BASE + BOOTSPI_MISC) |= 0x01000000;
    *((tPVU32) (0x40100190)) |= 0x10000;
    bootspi_program_command(0xFFFFFFFF, 0x80001106);
    bootspi_program_command(0xFFFFFFFF, 0x800011b7);

    return 0;
}


void bootspi_write(tU32 to, tU32 from, tU32 len)
{
	int i,j;
	tU32 nopgs;
	tU32 wr_ind;
  	nopgs = len/FLASH_PAGE_SiZE;
	tU32 loopsize = 0;
	tU32 start_address = to;

    if ((len%FLASH_PAGE_SiZE) != 0)
        nopgs = nopgs + 1;

    for(j=0; j<(nopgs); j++){
		bootspi_program_command(0xFFFFFFFF, 0x80001106);
		bootspi_program_command(to,  0x80001502);

		nc_printf(".");
		loopsize = ((len>= FLASH_PAGE_SiZE)? FLASH_PAGE_SiZE:len);
		wr_ind = to - start_address;

		for(i=0; i<loopsize; i++){
			*(tPVU8) (BOOTSPI_BASE + BOOTSPI_RWDATA) = *(((tPVU8)(from)) + wr_ind + i);  
		}          

		len -= (i-1);
		to += FLASH_PAGE_SiZE;
		bootspi_check_status(0, 0x80002105);         
	}

	return;
}	

void bootspi_read(tPU32 from, tPU8 rd_dat)
{
    bootspi_program_command(from, 0x80000503); 

   *((tPVU8)(rd_dat)) = *(tPVU8) (BOOTSPI_BASE + BOOTSPI_RWDATA);

   bootspi_check_status(0, 0x80002105);    
}

int bootspi_update(tU32 dest, tU32 source, tU32 size)
{
    tU32 erasesects,chk;
	tU32 address = source;
    int i;
    tU8 rd_dat= 0;

    /*eraser secects*/
    if(size>(64*1024)){
                erasesects=(size/(64*1024));
                if ((size % (64*1024)) != 0){
                    erasesects++;
                }
        }else{
                erasesects=1;
    }
    nc_printf("Erasing %d sects from %x\n", erasesects,dest);

    for(i=0; i < erasesects; i++){
        bootspi_program_command(0xFFFFFFFF, 0x80001106);
        bootspi_program_command((dest+(i<<16)), 0x800015D8);
        bootspi_check_status(0, 0x80002105);
        nc_printf(".");
    }
    nc_printf("\n");

    nc_printf("Flashing");
    bootspi_write(dest, address, size);

    nc_printf("\nReading");
    for(chk=0; chk< size; chk++){
        bootspi_read(dest+chk, &rd_dat);
        if(*((tPVU8)(address+chk)) != rd_dat){
            nc_printf("ERR at %x , %x != %x \n", chk, rd_dat, *((tPVU8)(address+chk)));
            return -1;
        }
	 //nc_printf("%c",rd_dat);
     if (chk%4096 == 0) nc_printf(".");
    }

    nc_printf("\nSUCCESS\n");
    return 0;
}

