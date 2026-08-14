/*
 * Static x86_64 Linux ELF: sys_rseq register, IDs, EBUSY, unregister.
 * License: Public Domain / CC0 1.0 Universal
 */

.intel_syntax noprefix
.global _start

.section .data
.align 32
rseq_area:
	.zero 32

.section .rodata
msg_ok:
	.ascii "RSEQOK\n"
	msg_ok_len = . - msg_ok
msg_fail:
	.ascii "RSEQFAIL\n"
	msg_fail_len = . - msg_fail

.section .text
_start:
	/* rseq(&rseq_area, 32, 0, RSEQ_SIG=0x53053053) */
	lea	rdi, [rseq_area]
	.att_syntax prefix
	movq	$32, %rsi
	xorq	%rdx, %rdx
	movq	$0x53053053, %r10
	movq	$334, %rax
	.intel_syntax noprefix
	syscall
	test	rax, rax
	jnz	.Lfail

	/* cpu_id and cpu_id_start must match and not be -1 / -2. */
	mov	eax, dword ptr [rseq_area + 4]
	cmp	eax, -1
	je	.Lfail
	cmp	eax, -2
	je	.Lfail
	mov	ebx, dword ptr [rseq_area]
	cmp	eax, ebx
	jne	.Lfail

	/* Second register of the same area: -EBUSY. */
	lea	rdi, [rseq_area]
	.att_syntax prefix
	movq	$32, %rsi
	xorq	%rdx, %rdx
	movq	$0x53053053, %r10
	movq	$334, %rax
	.intel_syntax noprefix
	syscall
	cmp	rax, -16
	jne	.Lfail

	/* Unregister. */
	lea	rdi, [rseq_area]
	.att_syntax prefix
	movq	$32, %rsi
	movq	$1, %rdx
	movq	$0x53053053, %r10
	movq	$334, %rax
	.intel_syntax noprefix
	syscall
	test	rax, rax
	jnz	.Lfail

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
