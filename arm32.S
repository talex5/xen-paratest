#define __HVC(imm16) .long ((0xE1400070 | (((imm16) & 0xFFF0) << 4) | ((imm16) & 0x000F)) & 0xFFFFFFFF)
#define XEN_IMM 0xEA1
#define __HYPERVISOR_console_io           18

#define MMU_ENABLE    (1 << 0)
#define DCACHE_ENABLE (1 << 2)

.section .text

.globl _start
_start:
	@ zImage header
.rept   8
        mov     r0, r0
.endr
        b       reset
        .word   0x016f2818      @ Magic numbers to help the loader
        .word   _start		@ absolute load/run zImage address
        .word   _end - _start   @ zImage size
	@ end of zImage header
greeting:
	.string "paratest/arm32 starting...\n"
greeting_end:
.align 4

@ Called at startup. Reset the CPU to a sane state, then call main.
@ See: http://xenbits.xen.org/docs/unstable/hypercall/arm/include,public,xen.h.html#incontents_startofday
@
@ => r2 -> DTD (from hypervisor)
@    Running in SVC mode?
@ <= Doesn't return.
reset:
	@ Initialize ACTLR core register
	@ (what does this do?)
	mrc p15, 0, r0, c1, c0, 1
	orr r0, r0, #1 << 6
	mcr p15, 0, r0, c1, c0, 1

	@ Save dtb pointer passed by the hypervisor
	mov	r4, r2

	@ Reset sequence from "Example 13-3 Setting up caches, MMU and branch predictors"

	@ Disable MMU
	MRC p15, 0, r1, c1, c0, 0		@ Read Control Register configuration data
	BIC r1, r1, #0x1
	MCR p15, 0, r1, c1, c0, 0		@ Write Control Register configuration data

	@ Disable L1 Caches
	MRC p15, 0, r1, c1, c0, 0		@ Read Control Register configuration data
	BIC r1, r1, #(0x1 << 12)		@ Disable I Cache
	BIC r1, r1, #(0x1 << 2)                 @ Disable D Cache
	MCR p15, 0, r1, c1, c0, 0               @ Write Control Register configuration data
	
	@ Invalidate L1 Caches
	@ Invalidate Instruction cache
	MOV r1, #0
	MCR p15, 0, r1, c7, c5, 0

	@ Invalidate Data cache
	@ to make the code general purpose, we calculate the
	@ cache size first and loop through each set + way
	MRC p15, 1, r0, c0, c0, 0
	LDR r3, =0x1ff
	AND r0, r3, r0, LSR #13
	MOV r1, #0
way_loop:
	MOV r3, #0
set_loop:
	MOV r2, r1, LSL #30
	ORR r2, r3, LSL #5
	MCR p15, 0, r2, c7, c6, 2
	ADD r3, r3, #1
	CMP r0, r3
	BGT set_loop
	ADD r1, r1, #1
	CMP r1, #4

	BNE way_loop 			@ if not, iterate way_loop

	/*
	@ Invalidate TLB
	MCR p15, 0, r1, c8, c7, 0

	@ Branch Prediction Enable
	MOV r1, #0
	MRC p15, 0, r1, c1, c0, 0	@ Read Control Register configuration data
	ORR r1, r1, #(0x1 << 11)        @ Global BP Enable bit
	MCR p15, 0, r1, c1, c0, 0       @ Write Control Register configuration data
	
	@ Fill in the top-level translation table (at page_dir).
	@ Populate the whole pagedir with 1MB section descriptors for now (1-1 mapping)
	@ldr 	r0, =0b00000000000000000000110111100010
	ldr	r0, =(0x2 + (3 << 10) + (1 << 16) + (1<<19)) @ section entry + read/write + sharable + non-secure.
	orr r0, r0, #4	@ XN
	ldr	r1, =page_dir
	add	r2, r1, #(4*4*1024) 	@ Limit (4 GB address space, 4 byte entries)

1:
	str	r0, [r1],#4		@ write the section entry

	add	r0, r0, #(1 << 20) 	@ next physical page
	cmp	r1, r2
	bne	1b

	@ Tell the system where our new table is located.
	ldr	r2, =page_dir
	MCR	p15, 0, r2, c2, c0, 0	@ set ttbr0

	@ Set access permission for domains
	@ Domains are deprecated, but we have to configure them anyway.
	@ We mark every page as being domain 0 and set domain 0 to "client mode"
	@ (client mod = use access flags in page table).
	mov	r0, #1			@ 1 = client
	MCR	p15, 0, r0, c3, c0, 0	@ DACR
	isb

	@ Flush TLB?
	@ Invalidate TLB
	MCR p15, 0, r1, c8, c7, 0
	
	@ enable mmu / sctlr
	mrc	p15, 0, r1, c1, c0, 0	@ read sctlr
	orr	r1, r1, #0x7		@ (dcache, barriers, MMU)
	orr	r1, r1, #3 << 11	@ (icache, branch prediction)
	mcr	p15, 0, r1, c1, c0, 0	@ write sctlr
	isb
	*/

	@ set VBAR = exception_vector_table
	@ SCTLR.V = 0
	adr	r0, exception_vector_table
	mcr	p15, 0, r0, c12, c0, 0

	@ Display banner
	mov r0, #0		@ write
	mov r1, #greeting_end - greeting
	adr r2, greeting
        mov r12, #__HYPERVISOR_console_io
        __HVC(XEN_IMM)

	b	.


.pushsection .data
.align 13
irqstack:
	.fill (1024), 4, 0x0
.globl shared_info_page
.align 13
shared_info_page:
	.fill (1024), 4, 0x0

.align	14	@ Page table must be aligned to a 16 KB boundary.
page_dir:
	@ This is the (short-descriptor format) first-level translation table.
	@ Each 4-byte entry describes one 1 MB region of the 4 GB address space.
	.fill (4*1024), 4, 0x0

fault_s: .string "Fault! Stopped.\n"
fault_s_end:
.popsection

halt:
	wfi
	b	halt

@ If anything strange happens, write to the Xen console and halt.
fault:
	mov	r0, #0		@ write
	mov	r1, #fault_s_end - fault_s
	ldr	r2, =fault_s
        mov	r12, #__HYPERVISOR_console_io
        __HVC(XEN_IMM)
	b 	halt

@ exception base address
.align 5
.globl exception_vector_table
exception_vector_table:
	b	fault @ reset
	b	fault @ undefined instruction
	b	fault @ supervisor call
	b	fault @ prefetch call
	b	fault @ prefetch abort
	b	fault @ data abort //FIXME CLREX
	b	fault @ irq
	b	fault @ firq
