/*
 * Probe: Linux file mmap of /boot/home/hello_min.
 * MAP_PRIVATE PROT_READ; first 4 bytes must be ELF 7f 45 4c 46.
 * Success: MMAPFOK. Failure: MMAPFFAIL.
 * License: Public Domain / CC0 1.0 Universal
 */

.intel_syntax noprefix
.global _start

.section .rodata
path:
	.asciz "/boot/home/hello_min"
msg_ok:
	.ascii "MMAPFOK\n"
	msg_ok_len = . - msg_ok
msg_fail:
	.ascii "MMAPFFAIL\n"
	msg_fail_len = . - msg_fail

.section .text
_start:
	/* open(path, O_RDONLY) */
	.att_syntax prefix
	leaq	path(%rip), %rdi
	xorq	%rsi, %rsi
	xorq	%rdx, %rdx
	movq	$2, %rax
	.intel_syntax noprefix
	syscall
	test	rax, rax
	js	.Lfail
	mov	r12, rax

	/* mmap(NULL, 4096, PROT_READ, MAP_PRIVATE, fd, 0) */
	xor	rdi, rdi
	mov	rsi, 4096
	mov	rdx, 1
	mov	r10, 2
	mov	r8, r12
	xor	r9, r9
	.att_syntax prefix
	movq	$9, %rax
	.intel_syntax noprefix
	syscall
	test	rax, rax
	js	.Lfail
	cmp	byte ptr [rax], 0x7f
	jne	.Lfail
	cmp	byte ptr [rax + 1], 0x45
	jne	.Lfail
	cmp	byte ptr [rax + 2], 0x4c
	jne	.Lfail
	cmp	byte ptr [rax + 3], 0x46
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
