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
	@ Based on "Example 13-3 Setting up caches, MMU and branch predictors"
	@ from the "ARM Cortex -A Series Programmer’s Guide", version 4.0
	mrc p15, 1, r0, c0, c0, 0		@ CCSIDR, Cache Size ID Registers

	ldr r3, =0x1ff
	and r0, r3, r0, lsr #13			@ r0 = NumSets = (Number of sets in cache) - 1 (i.e. last set)

	mov r1, #0				@ Way
	mov r3, #0				@ Set
set_loop:
	mov r2, r1, lsl #30
	orr r2, r3, lsl #5
	mcr p15, 0, r2, c7, c6, 2		@ DCISW, Invalidate data cache line by set/way
	add r3, r3, #1
	cmp r0, r3
	bgt set_loop				@ Should be "bge"?

	b	.
