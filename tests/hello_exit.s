/*
 * Tiny static x86_64 Linux ELF: exit_group(42).
 * Proves the trap passes a non-zero status with no glibc, no argv.
 * License: Public Domain / CC0 1.0 Universal
 */
	.intel_syntax noprefix
	.global _start
	.text
_start:
	mov	rax, 231		/* Linux exit_group */
	mov	rdi, 42
	syscall
	hlt
