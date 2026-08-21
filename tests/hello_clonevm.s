/*
 * Probe: Linux clone(CLONE_VM, stack). Child writes a shared flag.
 * Parent waits for the flag. Same address space, no wait4.
 * Success: CLONEVMOK. Failure: CLONEVMFAIL.
 * License: Public Domain / CC0 1.0 Universal
 */

.intel_syntax noprefix
.global _start

.section .bss
	.align 16
cstack:
	.space 8192
	.align 8
ts:
	.space 16

.section .data
	.align 8
flag:
	.long 0

.section .rodata
msg_ok:
	.ascii "CLONEEXOK\n"
	msg_ok_len = . - msg_ok
msg_fail:
	.ascii "CLONEVMFAIL\n"
	msg_fail_len = . - msg_fail

.section .text
_start:
	/* clone(CLONE_VM, cstack+8192) */
	mov	rdi, 0x100
	lea	rsi, [cstack + 8192]
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

	/* parent: wait up to ~1s for flag */
	mov	r12, 200
.Lwait:
	cmp	dword ptr [flag], 1
	je	.Lseen
	/* nanosleep 5ms */
	mov	qword ptr [ts], 0
	mov	qword ptr [ts + 8], 5000000
	lea	rdi, [ts]
	xor	rsi, rsi
	.att_syntax prefix
	movq	$35, %rax
	.intel_syntax noprefix
	syscall
	dec	r12
	jnz	.Lwait
	jmp	.Lfail

.Lseen:
	/* Child should have thread-exited. Pause then print. */
	mov	qword ptr [ts], 0
	mov	qword ptr [ts + 8], 20000000
	lea	rdi, [ts]
	xor	rsi, rsi
	.att_syntax prefix
	movq	$35, %rax
	.intel_syntax noprefix
	syscall

.Lok:
	.att_syntax prefix
	movq	$1, %rax
	movq	$1, %rdi
	.intel_syntax noprefix
	lea	rsi, [msg_ok]
	.att_syntax prefix
	movq	$msg_ok_len, %rdx
	.intel_syntax noprefix
	syscall
	.att_syntax prefix
	movq	$60, %rax
	xorq	%rdi, %rdi
	.intel_syntax noprefix
	syscall

.Lchild:
	mov	dword ptr [flag], 1
	/* Linux exit(60): extra thread, not exit_group. */
	.att_syntax prefix
	movq	$60, %rax
	xorq	%rdi, %rdi
	.intel_syntax noprefix
	syscall
.Lhang:
	jmp	.Lhang

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
