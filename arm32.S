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
	@ Invalidate Data cache
	@ to make the code general purpose, we calculate the
	@ cache size first and loop through each set + way
	MRC p15, 1, r0, c0, c0, 0

	LDR r3, =0x1ff
	AND r0, r3, r0, LSR #13
	MOV r1, #0

	MOV r3, #0
set_loop:
	MOV r2, r1, LSL #30
	ORR r2, r3, LSL #5
	MCR p15, 0, r2, c7, c6, 2
	ADD r3, r3, #1
	CMP r0, r3
	BGT set_loop


	b	.
