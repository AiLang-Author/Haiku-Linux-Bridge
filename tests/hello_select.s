/*
 * Probe: Linux pipe2 + select.
 *   select(read, 0-timeout) on empty pipe → 0
 *   write 1 byte; select again → 1, bit set
 * Success: SELECTOK. Failure: SELECTFAIL.
 * License: Public Domain / CC0 1.0 Universal
 */

.intel_syntax noprefix
.global _start

.section .data
	.align 8
fds:
	.long 0
	.long 0
	.align 8
readfds:
	.quad 0
	.quad 0
tv:
	.quad 0
	.quad 0
oneb:
	.byte 65

.section .rodata
msg_ok:
	.ascii "SELECTOK\n"
	msg_ok_len = . - msg_ok
msg_fail:
	.ascii "SELECTFAIL\n"
	msg_fail_len = . - msg_fail

.section .text
_start:
	.att_syntax prefix
	leaq	fds(%rip), %rdi
	xorq	%rsi, %rsi
	movq	$293, %rax
	.intel_syntax noprefix
	syscall
	test	rax, rax
	jnz	.Lfail

	/* readfds bit = fds[0] */
	mov	eax, dword ptr [fds]
	cmp	eax, 63
	ja	.Lfail
	mov	ecx, eax
	mov	rax, 1
	shl	rax, cl
	mov	qword ptr [readfds], rax

	/* select(fd+1, readfds, 0, 0, {0,0}) → 0 */
	mov	edi, dword ptr [fds]
	inc	edi
	.att_syntax prefix
	leaq	readfds(%rip), %rsi
	xorq	%rdx, %rdx
	xorq	%r10, %r10
	leaq	tv(%rip), %r8
	movq	$23, %rax
	.intel_syntax noprefix
	syscall
	test	rax, rax
	jnz	.Lfail

	/* write(fds[1], "A", 1) */
	mov	edi, dword ptr [fds + 4]
	.att_syntax prefix
	leaq	oneb(%rip), %rsi
	movq	$1, %rdx
	movq	$1, %rax
	.intel_syntax noprefix
	syscall
	cmp	rax, 1
	jne	.Lfail

	/* restore bit; select again → 1 */
	mov	eax, dword ptr [fds]
	mov	ecx, eax
	mov	rax, 1
	shl	rax, cl
	mov	qword ptr [readfds], rax
	mov	edi, dword ptr [fds]
	inc	edi
	.att_syntax prefix
	leaq	readfds(%rip), %rsi
	xorq	%rdx, %rdx
	xorq	%r10, %r10
	leaq	tv(%rip), %r8
	movq	$23, %rax
	.intel_syntax noprefix
	syscall
	cmp	rax, 1
	jne	.Lfail
	mov	rax, qword ptr [readfds]
	test	rax, rax
	jz	.Lfail

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
