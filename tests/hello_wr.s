/*
 * Tiny static x86_64 Linux ELF: write(1, "WRPROBE\n", 8); exit_group(0).
 * License: Public Domain / CC0 1.0 Universal
 */
	.intel_syntax noprefix
	.global _start
	.text
_start:
	mov	rax, 1
	mov	rdi, 1
	lea	rsi, [rip + msg]
	mov	rdx, 8
	syscall
	mov	rax, 231
	xor	rdi, rdi
	syscall
	hlt
	.section .rodata
msg:
	.ascii	"WRPROBE\n"
