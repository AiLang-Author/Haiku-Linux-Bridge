/*
 * Static x86_64 Linux ELF: mmap ANON + write + munmap + brk query.
 * License: Public Domain / CC0 1.0 Universal
 *
 * Expects the loader to have handed the trampoline a brk/mmap arena.
 * Prints MMAPOK / BRKOK (or MMAPFAIL / BRKFAIL).
 */

.intel_syntax noprefix
.global _start

.section .rodata
msg_ok:
	.ascii "MMAPOK\n"
	msg_ok_len = . - msg_ok
msg_fail:
	.ascii "MMAPFAIL\n"
	msg_fail_len = . - msg_fail
msg_brk_ok:
	.ascii "BRKOK\n"
	msg_brk_ok_len = . - msg_brk_ok
msg_brk_fail:
	.ascii "BRKFAIL\n"
	msg_brk_fail_len = . - msg_brk_fail

.section .text
_start:
	/* mmap(NULL, 4096, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0) */
	.att_syntax prefix
	movq	$9, %rax
	xorq	%rdi, %rdi
	movq	$4096, %rsi
	movq	$3, %rdx
	movq	$0x22, %r10
	movq	$-1, %r8
	xorq	%r9, %r9
	.intel_syntax noprefix
	syscall
	mov	r13, rax
	/* fail if rax is negative (high bit) */
	test	r13, r13
	js	.Lfail

	/* write "MMAPOK\n" into the page, then to stdout */
	mov	rcx, 7
	lea	rsi, [msg_ok]
	mov	rdi, r13
	rep	movsb

	.att_syntax prefix
	movq	$1, %rax
	movq	$1, %rdi
	.intel_syntax noprefix
	mov	rsi, r13
	.att_syntax prefix
	movq	$7, %rdx
	.intel_syntax noprefix
	syscall

	/* munmap(addr, 4096) */
	.att_syntax prefix
	movq	$11, %rax
	.intel_syntax noprefix
	mov	rdi, r13
	.att_syntax prefix
	movq	$4096, %rsi
	.intel_syntax noprefix
	syscall

	/* brk(0) — query current break */
	.att_syntax prefix
	movq	$12, %rax
	xorq	%rdi, %rdi
	.intel_syntax noprefix
	syscall
	test	rax, rax
	jz	.Lbrkfail
	js	.Lbrkfail

	.att_syntax prefix
	movq	$1, %rax
	movq	$1, %rdi
	.intel_syntax noprefix
	lea	rsi, [msg_brk_ok]
	.att_syntax prefix
	movq	$msg_brk_ok_len, %rdx
	.intel_syntax noprefix
	syscall
	jmp	.Lexit

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

.Lbrkfail:
	.att_syntax prefix
	movq	$1, %rax
	movq	$1, %rdi
	.intel_syntax noprefix
	lea	rsi, [msg_brk_fail]
	.att_syntax prefix
	movq	$msg_brk_fail_len, %rdx
	.intel_syntax noprefix
	syscall

.Lexit:
	.att_syntax prefix
	movq	$60, %rax
	.intel_syntax noprefix
	xor	rdi, rdi
	syscall
