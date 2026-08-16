/*
 * Probe: Linux pipe2 + poll.
 *   poll(read, POLLIN, 0) on empty pipe → 0
 *   write 1 byte; poll again → 1, revents has POLLIN
 * Success: POLLOK. Failure: POLLFAIL.
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
pfd:
	.long -1
	.short 1
	.short 0
oneb:
	.byte 65

.section .rodata
msg_ok:
	.ascii "POLLOK\n"
	msg_ok_len = . - msg_ok
msg_fail:
	.ascii "POLLFAIL\n"
	msg_fail_len = . - msg_fail

.section .text
_start:
	/* pipe2(fds, 0) */
	.att_syntax prefix
	leaq	fds(%rip), %rdi
	xorq	%rsi, %rsi
	movq	$293, %rax
	.intel_syntax noprefix
	syscall
	test	rax, rax
	jnz	.Lfail

	/* pfd.fd = fds[0] */
	mov	eax, dword ptr [fds]
	mov	dword ptr [pfd], eax

	/* poll(pfd, 1, 0) → 0 */
	.att_syntax prefix
	leaq	pfd(%rip), %rdi
	movq	$1, %rsi
	xorq	%rdx, %rdx
	movq	$7, %rax
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

	/* poll again → 1, POLLIN */
	mov	word ptr [pfd + 6], 0
	.att_syntax prefix
	leaq	pfd(%rip), %rdi
	movq	$1, %rsi
	xorq	%rdx, %rdx
	movq	$7, %rax
	.intel_syntax noprefix
	syscall
	cmp	rax, 1
	jne	.Lfail
	movzx	eax, word ptr [pfd + 6]
	test	eax, 1
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
