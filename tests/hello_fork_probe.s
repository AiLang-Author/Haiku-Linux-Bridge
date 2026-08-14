/*
 * Probe: clone, parent writes PRE, both sides spin. No Linux exit.
 * PRE => _kern_fork returned. Reboot => fork_team or child sysret iframe.
 * License: Public Domain / CC0 1.0 Universal
 */

.intel_syntax noprefix
.global _start

.section .rodata
msg_pre:
	.ascii "PRE\n"
	msg_pre_len = . - msg_pre

.section .text
_start:
	.att_syntax prefix
	movq	$17, %rdi
	.intel_syntax noprefix
	xor	rsi, rsi
	xor	rdx, rdx
	xor	r10, r10
	xor	r8, r8
	.att_syntax prefix
	movq	$56, %rax
	.intel_syntax noprefix
	syscall
	test	rax, rax
	jle	.Lspin

	.att_syntax prefix
	movq	$1, %rax
	movq	$1, %rdi
	.intel_syntax noprefix
	lea	rsi, [msg_pre]
	.att_syntax prefix
	movq	$msg_pre_len, %rdx
	.intel_syntax noprefix
	syscall
.Lspin:
	pause
	jmp	.Lspin
