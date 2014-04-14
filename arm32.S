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

	b	.
