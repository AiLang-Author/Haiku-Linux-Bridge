/*
 * Static x86_64 Linux ELF: arch_prctl(ARCH_SET_FS) then read %fs:0.
 * License: Public Domain / CC0 1.0 Universal
 */

.intel_syntax noprefix
.global _start

.section .bss
tls:
	.space 64

.section .rodata
msg_ok:
	.ascii "FSOK\n"
	msg_ok_len = . - msg_ok
msg_fail:
	.ascii "FSFAIL\n"
	msg_fail_len = . - msg_fail

.section .text
_start:
	/* tls[0] = 0xA11CE5F5 */
	.att_syntax prefix
	movq	$0xA11CE5F5, %rax
	.intel_syntax noprefix
	lea	rdi, [tls]
	mov	[rdi], rax

	/* arch_prctl(ARCH_SET_FS, tls) */
	.att_syntax prefix
	movq	$158, %rax
	movq	$0x1002, %rdi
	.intel_syntax noprefix
	lea	rsi, [tls]
	syscall
	test	rax, rax
	jnz	.Lfail

	/* rax = %fs:0 */
	mov	rax, [fs:0]
	.att_syntax prefix
	movq	$0xA11CE5F5, %rbx
	.intel_syntax noprefix
	cmp	rax, rbx
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
