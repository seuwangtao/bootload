#include "./include/hwmap.h"
#include "./include/hwreg.h"

LMEMSTART = 0x10000000
	.extern        pbsw_main
	.globl _start
	.align
_start:
		B	reset
        B   .
        B   .
        B   .
        B   .
        B   .
        B   IRQHandler_LOCAL



LOADFGB:
        ldr pc,ROMResetFGB
        ldr pc,UndefHandlerFGB
            ldr pc,SWIHandlerFGB
        ldr pc,PrefAbortHandlerFGB
        ldr pc,DataAbortHandlerFGB
        ldr pc,AddrExceptHandlerFGB
        ldr pc,IRQHandlerFGB
        ldr pc,FIQHandlerFGB

ROMResetFGB:        .word       LMEMSTART + 0x00000000  @ 0x04000000
UndefHandlerFGB:        .word       LMEMSTART + 0x00000004  @ 0x04000004
SWIHandlerFGB:      .word       LMEMSTART + 0x00000008  @ 0x04000008
PrefAbortHandlerFGB:    .word       LMEMSTART + 0x0000000c  @ 0x0400000c
DataAbortHandlerFGB:    .word       LMEMSTART + 0x00000010  @ 0x04000010
AddrExceptHandlerFGB:   .word       LMEMSTART + 0x00000014  @ 0x04000014
IRQHandlerFGB:      .word       LMEMSTART + 0x00000018  @ 0x04000018
FIQHandlerFGB:      .word       LMEMSTART + 0x0000001c  @ 0x0400001c
LOADFGBEND:

                .align

doingclkswitching:      .asciz  "Doing init......\n"
				.align


.globl	_bss_start_abs
_bss_start_abs:
	.word	__bss_start		@ absolute address (not in flash)

.globl	_bss_end_abs
_bss_end_abs:
	.word	__bss_end		@ absolute address

				.align

reset:
	mrs r0, cpsr
	bic r0, r0, #0x1f
	orr r0, r0, #0xd3
	msr cpsr, r0

//	ldr	r0, =0x1f
//	msr	cpsr, r0

#if 1
	ldr r1 , =0x40431000
	ldr r2 , =0x40431014
01:
	ldr r3, [r2]
	tst r3, #0x20
	beq 01b
	mov r0, #0x61
	strb r0, [r1]


02:
	ldr r3, [r2]
	tst r3, #0x20
	beq 02b
	mov r0, #13
	strb r0, [r1]
#endif
	

#define SE_UART_BASE  SE_UART_3_BASE
#define CONFIG_BAUDRATE 115200 

        ldr     r9,=SE_UART_BASE
        mov     r11, #7
        strb    r11, [r9, #8]
        mov     r10, #131
        strb    r10, [r9, #12]
#if (CONFIG_BAUDRATE == 115200)
        mov     r11, #1
#else
        // assume 9600
        mov     r11, #12
#endif
        strb    r11, [r9]
        mov     r10, #3
        strb    r10, [r9, #12]
        mov     r11, #42
        strb    r11, [r9]

		ldr r9, =0x4010012C
		ldr r10,[r9]
		orr r10,r10,#3
		str r10, [r9]


		ldr r13, =0x10007ffc
    //    ldr     r0,=doingclkswitching       
	//	bl      AsmWriteStrLOCAL


	/* Our cpu_init_crit() does not chain to lowlevel_init().
	 */
	bl	cpu_init_crit


	/* Set clock rates, config. flash controller, fix GPIOF pin mapping.
	 * Since FP is negative, lowlevel_init does not change GPIOA0
	 * (SP_ERROR_LED, should float high) nor init the DRAM controller.
	 */
	bl	lowlevel_init

	/* Initialize stack pointer and global-data ptr (R8).
	 * Store sizes (in KiB) of heap portion and entire cache-as-RAM.
	 */

clear_cache_as_ram:
        ldr     r0, _bss_start_abs
        ldr     r1, _bss_end_abs          /* stop here                        */
        mov     r2, #0x00000000          /* clear                            */
clsram_l:str     r2, [r0]                /* clear loop...                    */
        add     r0, r0, #4
        cmp     r0, r1
        ble     clsram_l                 /* (Sun) Clears 1 word too far (use 'bmi'). */

	/* Clear some words at top of stack since cpu/$(CPU)/start.S does.
	 * FIXME: Check ARM ABI.  Clear high registers R9-R12.
	 */
	ldr	sp, =0x10007ffc		@ RAM was cleared earlier.

	/* Call pbsw_main(); it should not return. */
	mov	r0, #0
	mov	r1, #0
	bl pbsw_main

	b .
	/* That was fun.  Now undo all that and start U-Boot the old way.
	 */


stbyint_sts         = (1<<2)
stbyint_en          = (1<<3)

IRQHandler_LOCAL:
    ldr r2,=stbyint_sts
    ldr r0,=0x40100100
    ldr r1,[r0]
    orr r1,r1,r2
    str r1,[r0]    
        subs    r15, r14, #4    
    

/*****************************************************************************
 * Initialize critical CPU registers
 *****************************************************************************/
cpu_init_crit:
        /*
         * flush v4 I/D caches
         */
        mov     r0, #0
        mcr     p15, 0, r0, c7, c7, 0   /* flush v3/v4 cache */
        mcr     p15, 0, r0, c8, c7, 0   /* flush v4 TLB */

        /*
         * disable MMU stuff and caches
         */
        mrc     p15, 0, r0, c1, c0, 0
        bic     r0, r0, #0x00002300     /* clear bits 13, 9:8 (--V- --RS) */
        bic     r0, r0, #0x00000087     /* clear bits 7, 2:0 (B--- -CAM) */
        orr     r0, r0, #0x00000002     /* set bit 2 (A) Align */
        orr     r0, r0, #0x00001000     /* set bit 12 (I) I-Cache */
        mcr     p15, 0, r0, c1, c0, 0

        mov     pc, lr          /* back to my caller */


NEWLINEL        =       '\n'
RETURNL         =       '\r

   .global AsmWriteStrLOCAL
AsmWriteStrLOCAL:
       stmfd    r13!,{r0-r5,lr}

    mov r5,r0

       ldr      r3,=SE_UART_3_BASE
       add      r2,r3,#0x14
01:
       ldr      r1,[r2]
       tst      r1,#0x20
       beq      01b 
       ldrb     r4,[r0],#1
       cmp      r4,#NEWLINEL
       beq      02f 
       strb     r4,[r3]
       b        01b 
02:
       strb     r4,[r3]
       mov      r4,#RETURNL
       strb     r4,[r3]

    
       ldmfd    r13!,{r0-r5,pc}

