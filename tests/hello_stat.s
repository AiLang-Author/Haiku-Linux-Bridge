/*
 * Static x86_64 Linux ELF: newfstatat + fstat. Proof that the layer
 * translates Haiku read_stat instead of faking S_IFDIR.
 * License: Public Domain / CC0 1.0 Universal
 */

.intel_syntax noprefix
.global _start

.section .bss
.align 16
stbuf:
	.space 144
stbuf2:
	.space 144

.section .rodata
path_home:
	.asciz "/boot/home"
path_bb:
	.asciz "/boot/home/busybox"
msg_ok:
	.ascii "STATOK\n"
	msg_ok_len = . - msg_ok
msg_fail:
	.ascii "STATFAIL\n"
	msg_fail_len = . - msg_fail

.section .text
_start:
	/* newfstatat(AT_FDCWD, "/boot/home", stbuf, 0) */
	.att_syntax prefix
	movq	$-100, %rdi
	.intel_syntax noprefix
	lea	rsi, [path_home]
	lea	rdx, [stbuf]
	xor	r10, r10
	.att_syntax prefix
	movq	$262, %rax
	.intel_syntax noprefix
	syscall
	test	rax, rax
	jnz	.Lfail
	/* mode @24 must be S_IFDIR (0040000) */
	mov	eax, dword ptr [stbuf + 24]
	and	eax, 0xF000
	cmp	eax, 0x4000
	jne	.Lfail

	/* newfstatat(AT_FDCWD, "/boot/home/busybox", stbuf, 0) */
	.att_syntax prefix
	movq	$-100, %rdi
	.intel_syntax noprefix
	lea	rsi, [path_bb]
	lea	rdx, [stbuf]
	xor	r10, r10
	.att_syntax prefix
	movq	$262, %rax
	.intel_syntax noprefix
	syscall
	test	rax, rax
	jnz	.Lfail
	/* mode @24 must be S_IFREG (0100000) */
	mov	eax, dword ptr [stbuf + 24]
	and	eax, 0xF000
	cmp	eax, 0x8000
	jne	.Lfail
	/* size @48 must be nonzero (fake fillstat left size=0) */
	mov	rax, qword ptr [stbuf + 48]
	test	rax, rax
	jz	.Lfail

	/* openat(AT_FDCWD, busybox, O_RDONLY) then fstat */
	.att_syntax prefix
	movq	$-100, %rdi
	.intel_syntax noprefix
	lea	rsi, [path_bb]
	xor	rdx, rdx
	.att_syntax prefix
	movq	$257, %rax
	.intel_syntax noprefix
	syscall
	test	rax, rax
	js	.Lfail
	mov	r12, rax
	mov	rdi, r12
	lea	rsi, [stbuf2]
	.att_syntax prefix
	movq	$5, %rax
	.intel_syntax noprefix
	syscall
	test	rax, rax
	jnz	.Lfail
	mov	eax, dword ptr [stbuf2 + 24]
	and	eax, 0xF000
	cmp	eax, 0x8000
	jne	.Lfail
	mov	rax, qword ptr [stbuf2 + 48]
	cmp	rax, qword ptr [stbuf + 48]
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
	jmp	.Lexit

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
