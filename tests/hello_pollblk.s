/*
 * Probe: blocking Linux poll(..., -1) on a pipe.
 * Child nanosleeps 200ms then writes one byte.
 * Parent poll(read, POLLIN, -1), then nonblock read of that byte.
 * Success: POLLBLKOK. Failure: POLLBLKFAIL.
 * License: Public Domain / CC0 1.0 Universal
 */

.intel_syntax noprefix
.global _start

.section .bss
	.align 8
wstatus:
	.space 8
rbuf:
	.space 8

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
	.align 8
ts:
	.quad 0
	.quad 200000000
oneb:
	.byte 65

.section .rodata
msg_ok:
	.ascii "POLLBLKOK\n"
	msg_ok_len = . - msg_ok
msg_fail:
	.ascii "POLLBLKFAIL\n"
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

	/* clone(SIGCHLD) */
	mov	rdi, 17
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

	/* parent: close write end */
	mov	r13, rax
	mov	edi, dword ptr [fds + 4]
	.att_syntax prefix
	movq	$3, %rax
	.intel_syntax noprefix
	syscall

	/* pfd.fd = fds[0] */
	mov	eax, dword ptr [fds]
	mov	dword ptr [pfd], eax
	mov	word ptr [pfd + 6], 0

	/* poll(pfd, 1, -1) */
	.att_syntax prefix
	leaq	pfd(%rip), %rdi
	movq	$1, %rsi
	movq	$-1, %rdx
	movq	$7, %rax
	.intel_syntax noprefix
	syscall
	cmp	rax, 1
	jne	.Lfail
	movzx	eax, word ptr [pfd + 6]
	test	eax, 1
	jz	.Lfail

	/* fcntl F_SETFL O_NONBLOCK so a false POLLIN is EAGAIN */
	mov	edi, dword ptr [fds]
	.att_syntax prefix
	movq	$4, %rsi
	movq	$0x800, %rdx
	movq	$72, %rax
	.intel_syntax noprefix
	syscall
	test	rax, rax
	js	.Lfail

	/* read 1 byte, expect 'A' */
	mov	edi, dword ptr [fds]
	lea	rsi, [rbuf]
	.att_syntax prefix
	movq	$1, %rdx
	xorq	%rax, %rax
	.intel_syntax noprefix
	syscall
	cmp	rax, 1
	jne	.Lfail
	cmp	byte ptr [rbuf], 65
	jne	.Lfail

	mov	rdi, r13
	lea	rsi, [wstatus]
	xor	rdx, rdx
	xor	r10, r10
	.att_syntax prefix
	movq	$61, %rax
	.intel_syntax noprefix
	syscall
	test	rax, rax
	jle	.Lfail

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
	/* nanosleep 200ms, write 'A', exit */
	.att_syntax prefix
	leaq	ts(%rip), %rdi
	xorq	%rsi, %rsi
	movq	$35, %rax
	.intel_syntax noprefix
	syscall
	mov	edi, dword ptr [fds + 4]
	.att_syntax prefix
	leaq	oneb(%rip), %rsi
	movq	$1, %rdx
	movq	$1, %rax
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
