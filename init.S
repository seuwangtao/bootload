/***************************************************************************
#
# CONFIDENTIAL
#
# Copyright (c) 2004 Server Engines 2004
# All rights reserved
#
#       Project  : Pilot
#       Filename : init.s
#
# Modified for U-Boot by American Megatrends Inc.
# Set TAB Spaces to 4 for proper view of the source
#
#****************************************************************************
*/
#include "./include/ddr_misc.h"
SCLKSTS                   =        0x40100104
SCLKCTL                   =        0x40100108
STANDBYINT          =       1<<27
SYS_PLLLOCK =            (1<<14)
DDR_PLLLOCK  =           (1<<29)
PLLLOCK       =          (SYS_PLLLOCK + DDR_PLLLOCK)
VIC                        =       0x40000000   
stbyint_sts         = (1<<2)
stbyint_en          = (1<<3)
	.global pilot3hornet_init

remap_vectors:
        B   .
        B   .
        B   .
        B   .
        B   .
        B   .
        ldr  pc,_IRQHandler_LOCAL

_IRQHandler_LOCAL:
        .word (IRQHandler_LOCAL)

remap_vectors_offset:
        .word (remap_vectors)

        .align
RELOADLPCADDR   =   0x40100200      @ 128Bytes of Scratch Area

	.align

/*
#************************************************************************
#              Called from lowlevelinit.s to initialize DDR
#************************************************************************
*/
pilot3hornet_init:

	stmfd  r13!,{r0-r12,r14}
@Enable Boot SPI Prefetch
	ldr	r0,=0x40200010
	ldr	r1,[r0]
	orr	r1,r1,#0x10
	str	r1,[r0]


@Enable  ARM Interrupts for Clk Switching
	mrs       r2,cpsr
    bic       r2,r2,#0x80
    msr        cpsr,r2

@default ddr pll to 800mhz,though ddr pll comes up with 800mhz,we still needs to write this,as the register at 0x40100110 does not
@have correct reset values,so at later point if we are doing Read modify writes to change ddr frequency for low power we may end u
@writting in-correct values to PLL,to avoid this scenario we are correcting default value by overwiting them.
        ldr     r0, =0x40100110
        ldr     r1, =0x78001F00
        str     r1, [r0]


/*
# Move the vectors to scratchpad and remap
# this allows us to have our own irq handler for clock switching.
# unmap at the end 
*/
@@@@load handlers at remap address
        ldr     r0,remap_vectors_offset
        ldr     r1,=RELOADLPCADDR
        ldmia   r0!,{r2-r9}
        stmia   r1!,{r2-r9}

    ldr r0,=SYSCONTROL
    ldr r1,[r0]
    orr r1,r1,#1
    str r1,[r0]               @ remap

@programing pll to switch clock to higher clock rate
@to do that we put arm into stanby mode and we programme h/w such that it will
@generate interrupt after clock is switched to bring ARM out of standby
	@Reset the Phy clock synchronizer
        ldr     r0, =0x40300010
        mov     r1, #0
	str     r1, [r0]

        ldr     r0, =0x40100110
        ldr     r1, =0x78001F00
        str      r1, [r0]

@G2PE
    ldr r0,=0x40100130
	ldr r1,[r0]
	orr r1,r1,#0x80
	str r1,[r0]

@enable stanby interrupt,hw will generate interrupt once clock is switched
	bl	Enable_stby_intr_vic
	bl	Enable_standbyfi_intr
	bl	Wait_For_PLLock
	bl	Switch_Clk_Pll

        mov     r3, pc
	bl	Disable_standbyfi_intr

	ldr	r0,=SYSCONTROL		@ restore remap irq vectors back to zero
	ldr	r2,=0xfffffff6		@ and disable clock switch interrupt
	ldr	r1,[r0]
	and	r1,r1,r2
	str	r1,[r0]

@Disable ARM Interrupts
	mrs       r2,cpsr
        orr       r2,r2,#0x80
        msr        cpsr,r2



@Enable Tx delay and Program Tx Delay 800ps  for MAC0 (1gig)
@Disable Rx delay
@MAC_RGMII_CTRL      =  0x40100188
	ldr	r0,=0x40100188
	ldr	r1,=0x3ff
	ldrh	r2,[r0]
	bic	r2,r2,r1
	ldr	r1,=0x220
@	ldr	r1,=0x293
	orr	r2,r2,r1
	strh	r2,[r0]

@Do clk switch for mac0 and mac1
        ldr     r0,=0x40100108
        ldr     r1,[r0]
        ldr     r2,=0x1E00000
        orr     r2,r2,r1
        str     r2,[r0]


@enble option rom for graphics
	 ldr     r6,=SYSCONTROL            @0x40100054
         ldr     r4, [r6,#0x54]
 	 ldr     r5,=0x00000200
	 orr     r4, r4,r5
         str     r4, [r6,#0x54]

@ Do DDR Initializtaion
@	mov     r0,#0x0
@       bl      ddrinit_asic


    ldr r0,=0x40100920
    ldr r1,=0xAAAAA
    str r1,[r0]

	ldmfd  r13!,{r0-r12,r15}


	b    .

@--------------------------------------------------------------------
@ clk switching intr handler
@--------------------------------------------------------------------
IRQHandler_LOCAL:
	ldr		r2,=stbyint_sts
	ldr		r0,=SYSCONTROL
	ldr		r1,[r0]
	orr		r1,r1,r2
	str		r1,[r0]
        ldr             r0,=0x10000000
        ldr             r1,=0xdeadbabe
        str             r1,[r0]
   	subs   	r15, r14, #4

@--------------------------------------------------------------------
@enable stby interrupt at VIC level
@--------------------------------------------------------------------
	.global Enable_stby_intr_vic
Enable_stby_intr_vic:
	ldr    	r0,=STANDBYINT
	ldr		r1,=VIC
	ldr    	r2,[r1]
	orr    	r0,r0,r2
	str		r0,[r1]
	mov    	pc,r14

	.global Enable_standbyfi_intr
Enable_standbyfi_intr:

	ldr	r0,=SYSCONTROL

@clear any of previous standby interrupt status
	ldr	r2,=stbyint_sts

03:
	ldr	r1,[r0]
	orr	r1,r1,r2
	str	r1,[r0]

	ldr	r1,[r0]
	tst     r1,#stbyint_sts
	bne	03b

@enable stby intr
	ldr	r2,=stbyint_en
	ldr	r1,[r0]
	orr	r1,r1,r2
	str	r1,[r0]

	mov    	pc,r14

@Waits till PLL is stable
	.global Wait_For_PLLock
Wait_For_PLLock:
	ldr     r0,=SCLKSTS
	ldr     r2,=PLLLOCK
01:
	ldr     r1,[r0]
	and     r1,r1,r2
	cmp     r1,r2
	bne     01b
	mov    	pc,r14


@make sure that Enable_standbyfi_intr is called before this subroutine and appropriate handler is available
@This subroutine switches mux to PLL(500/400Mhz) mode
	.global Switch_Clk_Pll
Switch_Clk_Pll:
	ldr   r1,=SCLKCTL
	ldrb   r0,[r1]
	ldr    r2,=0xffffffff
	orr   r0,r0,r2
	str   r0,[r1]

	MCR    15, 0, r0, c7, c0, 4
	mov    	pc,r14

	.global Disable_standbyfi_intr
Disable_standbyfi_intr:
	ldr	r0,=SYSCONTROL
	ldr	r2,=stbyint_en
	ldr	r1,[r0]
	bic	r1,r1,r2
	str	r1,[r0]

@clear any of previous standby interrupt status
	ldr	r0,=SYSCONTROL
	ldr	r2,=stbyint_sts

03:
	ldr	r1,[r0]
	orr	r1,r1,r2
	str	r1,[r0]

	ldr	r1,[r0]
	tst     r1,#stbyint_sts
	bne	03b
	mov    	pc,r3

    .ltorg
	.end

