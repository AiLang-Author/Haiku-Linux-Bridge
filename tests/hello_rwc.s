/*
 * Static x86_64 Linux ELF: read(0) + write(1) + close(3) + exit.
 * Stdin is inherited from the Haiku loader (same team fds).
 * License: Public Domain / CC0 1.0 Universal
 */

.intel_syntax noprefix
.global _start

.section .bss
buf:
	.space 64

.section .text
_start:
	/* read(0, buf, 64) — immediates via AT&T so gas does not load [64] */
	xor	eax, eax
	xor	rdi, rdi
	lea	rsi, [buf]
	.att_syntax prefix
	movq	$64, %rdx
	.intel_syntax noprefix
	syscall
	mov	r12, rax		/* bytes read */

	/* write(1, buf, n) */
	.att_syntax prefix
	movq	$1, %rax
	movq	$1, %rdi
	.intel_syntax noprefix
	lea	rsi, [buf]
	mov	rdx, r12
	syscall

	/* close(0) — stdin only, keep stdout for the shell wrapper */
	.att_syntax prefix
	movq	$3, %rax
	.intel_syntax noprefix
	xor	rdi, rdi
	syscall

	/* exit(0) */
	.att_syntax prefix
	movq	$60, %rax
	.intel_syntax noprefix
	xor	rdi, rdi
	syscall
