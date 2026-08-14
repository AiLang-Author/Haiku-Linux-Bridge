/*
 * Static x86_64 Linux ELF: clone(SIGCHLD, NULL) + wait4.
 * License: Public Domain / CC0 1.0 Universal
 */

.intel_syntax noprefix
.global _start

.section .bss
wstatus:
	.space 8

.section .rodata
msg_ok:
	.ascii "FORKOK\n"
	msg_ok_len = . - msg_ok
msg_child:
	.ascii "CHILD\n"
	msg_child_len = . - msg_child
msg_fail:
	.ascii "FORKFAIL\n"
	msg_fail_len = . - msg_fail

.section .text
_start:
	/* clone(SIGCHLD, NULL) */
	.att_syntax prefix
	movq	$17, %rdi
	.intel_syntax noprefix
	xor	rsi, rsi
	xor	rdx, rdx
	xor	r10, r10
	xor	r8, r8
	.att_syntax prefix
	movq	$56, %rax
	.intel_syntax noprefix
	syscall
	test	rax, rax
	js	.Lfail
	jz	.Lchild

	/* parent: wait4(pid, &wstatus, 0, 0). Child only exits —
	 * no write to the Terminal PTY from the child team. */
	mov	rdi, rax
	lea	rsi, [wstatus]
	xor	rdx, rdx
	xor	r10, r10
	.att_syntax prefix
	movq	$61, %rax
	.intel_syntax noprefix
	syscall
	test	rax, rax
	jle	.Lfail
	mov	eax, dword ptr [wstatus]
	test	eax, 0x7f
	jnz	.Lfail

	.att_syntax prefix
	movq	$1, %rax
	movq	$1, %rdi
	.intel_syntax noprefix
	lea	rsi, [msg_ok]
	.att_syntax prefix
	movq	$msg_ok_len, %rdx
	.intel_syntax noprefix
	syscall
	jmp	.Lexit

.Lchild:
	/* exit(0) only — first Linux syscall stamps this CR3. */
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

.Lexit:
	.att_syntax prefix
	movq	$60, %rax
	.intel_syntax noprefix
	xor	rdi, rdi
	syscall
