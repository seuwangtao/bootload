#include "./include/types.h"
#include "./include/hwmap.h"
#include "./include/serreg.h"

#define SE_UART_BASE  SE_UART_3_BASE

#define serial_inw(addr)                (*((volatile tU32 *)(addr)))
#define serial_outw(addr, value)        (*((volatile tU32 *)(addr)) = value)

void serial_putc(const char c)
{
    unsigned int status;
    if (c == '\n') {
        do {
            status = serial_inw(SE_UART_BASE + SERIAL_LSR);
            // wait until Tx ready
        } while (!((status & SERIAL_LSR_THRE)==SERIAL_LSR_THRE));
        serial_outw(SE_UART_BASE + SERIAL_THR, '\r');
    }   
    do {
        status = serial_inw(SE_UART_BASE + SERIAL_LSR);
        // wait until Tx ready
    } while (!((status & SERIAL_LSR_THRE)==SERIAL_LSR_THRE));
    serial_outw(SE_UART_BASE + SERIAL_THR, c); 
}

void serial_puts(const char *s) 
{

    const char *cp;

    for(cp = s; *cp != 0; cp++) {
        serial_putc(*cp);
    }   
}

void nc_printchar(unsigned char c)
{

  tU32 uartBase;
  tU32 uart_lsr;
  tU32 uart_thr;
  tU32 cnt=0;

    uartBase = 0x40431000;


    uart_lsr = (uartBase + 0x14);
    uart_thr = (uartBase);

    cnt=0;
    while ((*((volatile unsigned char *) uart_lsr) & 0x20) != 0x20){
		cnt++;
		if(cnt>8000)
			break;
	}

  *((volatile unsigned char *) uart_thr) = c;
  if(c == '\n'){
		nc_printchar('\r');
  }

}
