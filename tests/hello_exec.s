/*
 * Probe: Linux execve("/boot/home/hello_min").
 * Success: hello_min prints its line. Failure: EXECFAIL.
 * License: Public Domain / CC0 1.0 Universal
 */

.intel_syntax noprefix
.global _start

.section .rodata
path:
	.asciz "/boot/home/hello_min"
arg0:
	.asciz "hello_min"
msg_fail:
	.ascii "EXECFAIL\n"
	msg_fail_len = . - msg_fail

.section .data
argv:
	.quad arg0
	.quad 0

.section .text
_start:
	.att_syntax prefix
	leaq	path(%rip), %rdi
	leaq	argv(%rip), %rsi
	xorq	%rdx, %rdx
	movq	$59, %rax
	.intel_syntax noprefix
	syscall
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
