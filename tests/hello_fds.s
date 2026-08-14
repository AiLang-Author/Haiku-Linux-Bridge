/*
 * Static x86_64 Linux ELF: open + lseek + openat + creat-style open.
 * License: Public Domain / CC0 1.0 Universal
 *
 * Expects /tmp/opentest to contain at least "ABCDEFGHIJ".
 * Writes "DEFGABC" to stdout, creates /tmp/created with "CREATED\n".
 */

.intel_syntax noprefix
.global _start

.section .bss
buf:
	.space 64

.section .rodata
path_in:
	.asciz "/tmp/opentest"
path_out:
	.asciz "/tmp/created"
msg_created:
	.ascii "CREATED\n"
	msg_created_len = . - msg_created

.section .text
_start:
	/* open("/tmp/opentest", O_RDONLY=0) */
	.att_syntax prefix
	movq	$2, %rax
	.intel_syntax noprefix
	lea	rdi, [path_in]
	xor	rsi, rsi
	xor	rdx, rdx
	syscall
	mov	r13, rax		/* fd */

	/* lseek(fd, 3, SEEK_SET=0) */
	.att_syntax prefix
	movq	$8, %rax
	.intel_syntax noprefix
	mov	rdi, r13
	.att_syntax prefix
	movq	$3, %rsi
	.intel_syntax noprefix
	xor	rdx, rdx
	syscall

	/* read(fd, buf, 4) -> DEFG */
	xor	eax, eax
	mov	rdi, r13
	lea	rsi, [buf]
	.att_syntax prefix
	movq	$4, %rdx
	.intel_syntax noprefix
	syscall
	mov	r12, rax

	/* write(1, buf, n) */
	.att_syntax prefix
	movq	$1, %rax
	movq	$1, %rdi
	.intel_syntax noprefix
	lea	rsi, [buf]
	mov	rdx, r12
	syscall

	/* close(fd) */
	.att_syntax prefix
	movq	$3, %rax
	.intel_syntax noprefix
	mov	rdi, r13
	syscall

	/* openat(AT_FDCWD=-100, "/tmp/opentest", O_RDONLY) */
	.att_syntax prefix
	movq	$257, %rax
	movq	$-100, %rdi
	.intel_syntax noprefix
	lea	rsi, [path_in]
	xor	rdx, rdx
	xor	r10, r10
	syscall
	mov	r13, rax

	/* read(fd, buf, 3) -> ABC */
	xor	eax, eax
	mov	rdi, r13
	lea	rsi, [buf]
	.att_syntax prefix
	movq	$3, %rdx
	.intel_syntax noprefix
	syscall
	mov	r12, rax

	/* write(1, buf, n) */
	.att_syntax prefix
	movq	$1, %rax
	movq	$1, %rdi
	.intel_syntax noprefix
	lea	rsi, [buf]
	mov	rdx, r12
	syscall

	/* close(fd) */
	.att_syntax prefix
	movq	$3, %rax
	.intel_syntax noprefix
	mov	rdi, r13
	syscall

	/* open("/tmp/created", O_CREAT|O_WRONLY|O_TRUNC=0x241, 0644) */
	.att_syntax prefix
	movq	$2, %rax
	.intel_syntax noprefix
	lea	rdi, [path_out]
	.att_syntax prefix
	movq	$0x241, %rsi
	movq	$0x1a4, %rdx
	.intel_syntax noprefix
	syscall
	mov	r13, rax

	/* write(fd, "CREATED\n", 8) */
	.att_syntax prefix
	movq	$1, %rax
	.intel_syntax noprefix
	mov	rdi, r13
	lea	rsi, [msg_created]
	.att_syntax prefix
	movq	$msg_created_len, %rdx
	.intel_syntax noprefix
	syscall

	/* close(fd) */
	.att_syntax prefix
	movq	$3, %rax
	.intel_syntax noprefix
	mov	rdi, r13
	syscall

	/* exit(0) */
	.att_syntax prefix
	movq	$60, %rax
	.intel_syntax noprefix
	xor	rdi, rdi
	syscall
