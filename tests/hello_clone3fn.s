/*
 * Probe: clone3 like glibc __clone3(args,size,fn,arg).
 * Child: trampoline SETTLS, call fn(arg). fn checks fs:0 magic,
 * stores 42 at arg, returns 0x55. Parent waits for 42.
 * Success: CLONE3FNOK.
 * License: Public Domain / CC0 1.0 Universal
 */

.intel_syntax noprefix
.global _start

.section .bss
	.align 16
cstack:
	.space 8192

.section .data
	.align 8
tls:
	.quad 0xA11A11A1A11A11A1
flag:
	.long 0
ptid:
	.long 0
ctid:
	.long 0x7e
	.align 8
args:
	.quad 0x3d0f00		/* flags: pthread set */
	.quad 0			/* pidfd */
	.quad 0			/* child_tid — filled */
	.quad 0			/* parent_tid — filled */
	.quad 0			/* exit_signal */
	.quad 0			/* stack — filled */
	.quad 8192		/* stack_size */
	.quad 0			/* tls — filled */
	.align 8
ts:
	.quad 0
	.quad 5000000

.section .rodata
msg_ok:
	.ascii "CLONE3FNOK\n"
	msg_ok_len = . - msg_ok
msg_fail:
	.ascii "CLONE3FNFAIL\n"
	msg_fail_len = . - msg_fail
msg_fflag:
	.ascii "Fflag\n"
	msg_fflag_len = . - msg_fflag
msg_ffs:
	.ascii "Ffs\n"
	msg_ffs_len = . - msg_ffs

.section .text
fn:
	mov	rax, qword ptr fs:[0]
	movabs	r11, 0xA11A11A1A11A11A1
	cmp	rax, r11
	jne	.Lfnbad
	mov	dword ptr [rdi], 42
	mov	eax, 0x55
	ret
.Lfnbad:
	mov	dword ptr [rdi], 0xbad
	mov	eax, 1
	ret

_start:
	lea	rax, [cstack]
	mov	qword ptr [args + 40], rax	/* stack */
	lea	rax, [ptid]
	mov	qword ptr [args + 24], rax	/* parent_tid */
	lea	rax, [ctid]
	mov	qword ptr [args + 16], rax	/* child_tid */
	lea	rax, [tls]
	mov	qword ptr [args + 56], rax	/* tls */

	lea	rdi, [args]
	mov	rsi, 64
	lea	rdx, [fn]
	lea	rcx, [flag]
	mov	r8, rcx			/* glibc: arg in r8 across syscall */
	.att_syntax prefix
	movq	$435, %rax
	.intel_syntax noprefix
	syscall
	test	rax, rax
	js	.Lfail
	jz	.Lchild

	mov	r12, 200
.Lwaitf:
	cmp	dword ptr [flag], 42
	je	.Lok
	mov	qword ptr [ts], 0
	mov	qword ptr [ts + 8], 5000000
	lea	rdi, [ts]
	xor	rsi, rsi
	.att_syntax prefix
	movq	$35, %rax
	.intel_syntax noprefix
	syscall
	dec	r12
	jnz	.Lwaitf
	cmp	dword ptr [flag], 0xbad
	je	.Lffs
	jmp	.Lfflag

.Lchild:
	xor	ebp, ebp
	mov	rdi, r8
	call	rdx
	mov	rdi, rax
	.att_syntax prefix
	movq	$60, %rax
	.intel_syntax noprefix
	syscall
	jmp	.Lchild

.Lok:
	.att_syntax prefix
	movq	$1, %rax
	movq	$1, %rdi
	leaq	msg_ok(%rip), %rsi
	movq	$msg_ok_len, %rdx
	.intel_syntax noprefix
	syscall
	xor	edi, edi
	.att_syntax prefix
	movq	$60, %rax
	.intel_syntax noprefix
	syscall

.Lffs:
	.att_syntax prefix
	movq	$1, %rax
	movq	$1, %rdi
	leaq	msg_ffs(%rip), %rsi
	movq	$msg_ffs_len, %rdx
	.intel_syntax noprefix
	syscall
	jmp	.Lfail2

.Lfflag:
	.att_syntax prefix
	movq	$1, %rax
	movq	$1, %rdi
	leaq	msg_fflag(%rip), %rsi
	movq	$msg_fflag_len, %rdx
	.intel_syntax noprefix
	syscall

.Lfail:
	.att_syntax prefix
	movq	$1, %rax
	movq	$1, %rdi
	leaq	msg_fail(%rip), %rsi
	movq	$msg_fail_len, %rdx
	.intel_syntax noprefix
	syscall
.Lfail2:
	mov	edi, 1
	.att_syntax prefix
	movq	$60, %rax
	.intel_syntax noprefix
	syscall
