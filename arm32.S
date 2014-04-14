#define __HVC(imm16) .long ((0xE1400070 | (((imm16) & 0xFFF0) << 4) | ((imm16) & 0x000F)) & 0xFFFFFFFF)
#define XEN_IMM 0xEA1
#define __HYPERVISOR_console_io           18

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
.align 4

reset:
	@ Fill in the top-level translation table (at page_dir). Based on Mini-OS code.
	@ Populate the whole pagedir with 1MB section descriptors.
	@ TEX[2:0] C B = 001 1 1 (outer and inner write-back, write-allocate)
	ldr	r0, =(0x2 +  		/* Section entry */ \
		      0xc +  		/* C B */ \
		      (3 << 10) + 	/* Read/write */ \
		      (1 << 12) +	/* TEX */ \
		      (1 << 16) +	/* Sharable */ \
		      (1<<19))		/* Non-secure */
	ldr	r1, =page_dir
	add	r2, r1, #(4*4*1024) 	@ Limit (4 GB address space, 4 byte entries)

1:
	str	r0, [r1],#4		@ write the section entry
	add	r0, r0, #(1 << 20) 	@ next physical page
	cmp	r1, r2
	bne	1b

	@ Tell the system where our new table is located.
	ldr	r2, =page_dir
	mcr	p15, 0, r2, c2, c0, 0	@ set ttbr0

	@ Set access permission for domains
	@ Domains are deprecated, but we have to configure them anyway.
	@ We mark every page as being domain 0 and set domain 0 to "client mode"
	@ (client mod = use access flags in page table).
	mov	r0, #1			@ 1 = client
	mcr	p15, 0, r0, c3, c0, 0	@ DACR

	@ Invalidate TLB
	mcr	p15, 0, r1, c8, c7, 0	@ TLBIALL

	@ enable mmu / sctlr
	mrc	p15, 0, r1, c1, c0, 0	@ read sctlr
	orr	r1, r1, #0x7		@ (dcache, barriers, MMU)
	orr	r1, r1, #3 << 11	@ (icache, branch prediction)
	mcr	p15, 0, r1, c1, c0, 0	@ write sctlr
	isb

	@ Write buffer to console
	mov	r0, #0
	mov	r1, #4			@ write first 4 bytes
	ldr	r2, =buffer
        mov	r12, #__HYPERVISOR_console_io
        __HVC(XEN_IMM)

	@ Fill buffer2 with +
	ldr	r2, =buffer2
	add	r1, r2, #(buffer_end2 - buffer2 - 2)
	mov	r0, #'+'
1:
	strb	r0, [r2], #1
	cmp	r2, r1
	bne	1b

	@ Write buffer2
	mov	r0, #0
	mov	r1, #buffer_end2 - buffer2
	ldr	r2, =buffer2
        mov	r12, #__HYPERVISOR_console_io
        __HVC(XEN_IMM)

	b	.

.pushsection .data
.align	14	@ Page table must be aligned to a 16 KB boundary.
page_dir:
	@ This is the (short-descriptor format) first-level translation table.
	@ Each 4-byte entry describes one 1 MB region of the 4 GB address space.
	.fill (4*1024), 4, 0x0

.align	6
buffer:
	.string "012\n456789abcdefB123456789abcdefC123456789abcdefD123456789a" @ 60 bytes
buffer_end:
buffer2:
	.string "..........................\n"
buffer_end2:
.popsection

