/*
 * Static x86_64 Linux ELF: time + gettimeofday + clock_gettime.
 * Prints DATEOK <unix_sec> or DATEFAIL.
 * License: Public Domain / CC0 1.0 Universal
 */

.intel_syntax noprefix
.global _start

.section .bss
.align 16
tloc:
	.space 8
tv:
	.space 16
ts:
	.space 16
numbuf:
	.space 32

.section .rodata
msg_ok:
	.ascii "DATEOK "
	msg_ok_len = . - msg_ok
msg_fail:
	.ascii "DATEFAIL\n"
	msg_fail_len = . - msg_fail
msg_nl:
	.ascii "\n"

.section .text
_start:
	/* time(NULL) */
	.att_syntax prefix
	movq	$201, %rax
	xorq	%rdi, %rdi
	.intel_syntax noprefix
	syscall
	cmp	rax, -38
	je	.Lfail
	test	rax, rax
	jle	.Lfail
	mov	r12, rax
	/* Must be after 2020-01-01 (1577836800) */
	mov	rdx, 1577836800
	cmp	r12, rdx
	jb	.Lfail

	/* time(&tloc) must match */
	.att_syntax prefix
	movq	$201, %rax
	.intel_syntax noprefix
	lea	rdi, [tloc]
	syscall
	cmp	rax, r12
	jl	.Lfail
	sub	rax, r12
	cmp	rax, 2
	ja	.Lfail
	mov	rax, qword ptr [tloc]
	sub	rax, r12
	cmp	rax, 2
	ja	.Lfail

	/* gettimeofday(&tv, NULL) */
	.att_syntax prefix
	movq	$96, %rax
	.intel_syntax noprefix
	lea	rdi, [tv]
	xor	rsi, rsi
	syscall
	cmp	rax, -38
	je	.Lfail
	test	rax, rax
	jnz	.Lfail
	mov	rax, qword ptr [tv]
	sub	rax, r12
	cmp	rax, 2
	ja	.Lfail

	/* clock_gettime(CLOCK_REALTIME, &ts) */
	.att_syntax prefix
	movq	$228, %rax
	xorq	%rdi, %rdi
	.intel_syntax noprefix
	lea	rsi, [ts]
	syscall
	test	rax, rax
	jnz	.Lfail
	mov	rax, qword ptr [ts]
	sub	rax, r12
	cmp	rax, 2
	ja	.Lfail

	/* print DATEOK <sec>\n */
	.att_syntax prefix
	movq	$1, %rax
	movq	$1, %rdi
	.intel_syntax noprefix
	lea	rsi, [msg_ok]
	.att_syntax prefix
	movq	$msg_ok_len, %rdx
	.intel_syntax noprefix
	syscall

	/* decimal r12 into numbuf */
	lea	rdi, [numbuf + 30]
	mov	byte ptr [rdi], 10
	dec	rdi
	mov	rax, r12
	mov	rcx, 10
1:
	xor	rdx, rdx
	div	rcx
	add	dl, '0'
	mov	[rdi], dl
	dec	rdi
	test	rax, rax
	jnz	1b
	inc	rdi
	lea	rdx, [numbuf + 31]
	sub	rdx, rdi
	mov	rsi, rdi
	.att_syntax prefix
	movq	$1, %rax
	movq	$1, %rdi
	.intel_syntax noprefix
	syscall

	.att_syntax prefix
	movq	$60, %rax
	.intel_syntax noprefix
	xor	rdi, rdi
	syscall

.Lfail:
	.att_syntax prefix
	movq	$1, %rax
	movq	$1, %rdi
	.intel_syntax noprefix
	lea	rsi, [msg_fail]
	.att_syntax prefix
	movq	$msg_fail_len, %rdx
	.intel_syntax noprefix
	syscall
	.att_syntax prefix
	movq	$60, %rax
	movq	$1, %rdi
	.intel_syntax noprefix
	syscall
