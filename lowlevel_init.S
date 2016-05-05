/* Low level initialization for the board */
/* Copyright (c) American Megatrends, Inc */
/* Modified by Server Engines for P3*/


.extern pilot3hornet_init
/*----------------------------- Setting up the memory and Flash ----------------------*/
.globl lowlevel_init
lowlevel_init:

	ldr	r13,=0x10007ffc	@temp stack in local memory
	stmfd    r13!,{r0-r12,r14}

	/* Disabling intrusion  interrupt,this is must for warmboot but no harm in doing always */
    ldr r0,=0x40428014
    ldrb    r1,[r0]
    bic r1,r1,#0x4
    strb    r1,[r0]


	bl      pilot3hornet_init

	/* Return Back to caller */
	ldmfd  r13!,{r0-r12,r15}

