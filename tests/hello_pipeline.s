/*
 * Combined probe: clone + pipe + poll + execve(hello_min).
 * Child dups the pipe to stdout and execs hello_min.
 * Parent polls, reads "Hello", wait4.
 * Success: PIPELINEOK. Failure: PIPELINEFAIL.
 * License: Public Domain / CC0 1.0 Universal
 */

.intel_syntax noprefix
.global _start

.section .bss
	.align 8
wstatus:
	.space 8
buf:
	.space 128

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

.section .rodata
path:
	.asciz "/boot/home/hello_min"
arg0:
	.asciz "hello_min"
	.align 8
argv:
	.quad arg0
	.quad 0
msg_ok:
	.ascii "PIPELINEOK\n"
	msg_ok_len = . - msg_ok
msg_fail:
	.ascii "PIPELINEFAIL\n"
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

	/* parent: close write, poll read, read, wait4 */
	mov	r13, rax
	mov	edi, dword ptr [fds + 4]
	.att_syntax prefix
	movq	$3, %rax
	.intel_syntax noprefix
	syscall
	mov	eax, dword ptr [fds]
	mov	dword ptr [pfd], eax
	.att_syntax prefix
	leaq	pfd(%rip), %rdi
	movq	$1, %rsi
	movq	$5000, %rdx
	movq	$7, %rax
	.intel_syntax noprefix
	syscall
	test	rax, rax
	jle	.Lfail
	mov	edi, dword ptr [fds]
	lea	rsi, [buf]
	mov	rdx, 64
	.att_syntax prefix
	movq	$0, %rax
	.intel_syntax noprefix
	syscall
	cmp	rax, 5
	jl	.Lfail
	cmp	byte ptr [buf], 'H'
	jne	.Lfail
	cmp	byte ptr [buf + 1], 'e'
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
	/* dup2(pipe_w, 1); close both; execve hello_min */
	mov	edi, dword ptr [fds + 4]
	mov	esi, 1
	.att_syntax prefix
	movq	$33, %rax
	.intel_syntax noprefix
	syscall
	test	rax, rax
	js	.Lfail
	mov	edi, dword ptr [fds]
	.att_syntax prefix
	movq	$3, %rax
	.intel_syntax noprefix
	syscall
	mov	edi, dword ptr [fds + 4]
	.att_syntax prefix
	movq	$3, %rax
	.intel_syntax noprefix
	syscall
	.att_syntax prefix
	leaq	path(%rip), %rdi
	leaq	argv(%rip), %rsi
	xorq	%rdx, %rdx
	movq	$59, %rax
	.intel_syntax noprefix
	syscall
	jmp	.Lfail

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
