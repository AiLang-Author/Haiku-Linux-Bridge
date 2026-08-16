/*
 * Probe: Linux futex WAIT/WAKE in one process.
 *   WAIT val mismatch → -EAGAIN
 *   WAKE with no waiters → 0
 *   WAIT matching + 1ms timeout → -ETIMEDOUT
 * Success: FUTEXOK. Failure: FUTEXFAIL.
 * License: Public Domain / CC0 1.0 Universal
 */

.intel_syntax noprefix
.global _start

.section .data
	.align 4
word:
	.long 0

.section .rodata
ts_short:
	.quad 0
	.quad 1000000
msg_ok:
	.ascii "FUTEXOK\n"
	msg_ok_len = . - msg_ok
msg_fail:
	.ascii "FUTEXFAIL\n"
	msg_fail_len = . - msg_fail

.section .text
_start:
	/* futex(word, WAIT, 1, NULL) — word is 0 → -EAGAIN (11) */
	.att_syntax prefix
	leaq	word(%rip), %rdi
	movq	$0, %rsi
	movq	$1, %rdx
	xorq	%r10, %r10
	xorq	%r8, %r8
	xorq	%r9, %r9
	movq	$202, %rax
	.intel_syntax noprefix
	syscall
	cmp	rax, -11
	jne	.Lfail

	/* futex(word, WAKE, 1) → 0 */
	.att_syntax prefix
	leaq	word(%rip), %rdi
	movq	$1, %rsi
	movq	$1, %rdx
	xorq	%r10, %r10
	xorq	%r8, %r8
	xorq	%r9, %r9
	movq	$202, %rax
	.intel_syntax noprefix
	syscall
	test	rax, rax
	jnz	.Lfail

	/* futex(word, WAIT, 0, 1ms) — matches, times out → -ETIMEDOUT (110) */
	.att_syntax prefix
	leaq	word(%rip), %rdi
	movq	$0, %rsi
	xorq	%rdx, %rdx
	leaq	ts_short(%rip), %r10
	xorq	%r8, %r8
	xorq	%r9, %r9
	movq	$202, %rax
	.intel_syntax noprefix
	syscall
	cmp	rax, -110
	jne	.Lfail

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
