/*
 * Probe: clone(CLONE_VM|SETTLS|PARENT_SETTID|CHILD_CLEARTID).
 * Child checks fs:0 == magic, then exit(60).
 * Parent checks ptid, flag, then ctid cleared to 0.
 * Success: CLONETLSOK. Failure: CLONETLSFAIL.
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
ts:
	.quad 0
	.quad 5000000

.section .rodata
msg_ok:
	.ascii "CLONETLSOK\n"
	msg_ok_len = . - msg_ok
msg_fail:
	.ascii "CLONETLSFAIL\n"
	msg_fail_len = . - msg_fail
msg_fptid:
	.ascii "Fptid\n"
	msg_fptid_len = . - msg_fptid
msg_fflag:
	.ascii "Fflag\n"
	msg_fflag_len = . - msg_fflag
msg_fctid:
	.ascii "Fctid\n"
	msg_fctid_len = . - msg_fctid

.section .text
_start:
	/* CLONE_VM|SETTLS|PARENT_SETTID|CHILD_CLEARTID = 0x380100 */
	mov	rdi, 0x380100
	lea	rsi, [cstack + 8192]
	lea	rdx, [ptid]
	lea	r10, [ctid]
	lea	r8, [tls]
	.att_syntax prefix
	movq	$56, %rax
	.intel_syntax noprefix
	syscall
	test	rax, rax
	js	.Lfail
	jz	.Lchild
	mov	r13, rax
	cmp	dword ptr [ptid], 0
	je	.Lfptid
	cmp	dword ptr [ptid], r13d
	jne	.Lfptid

	mov	r12, 200
.Lwaitf:
	cmp	dword ptr [flag], 1
	je	.Lseen
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
	jmp	.Lfflag

.Lseen:
	mov	r12, 200
.Lwaitc:
	cmp	dword ptr [ctid], 0
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
	jnz	.Lwaitc
	jmp	.Lfctid

.Lok:
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
	mov	rax, qword ptr fs:[0]
	mov	rdx, 0xA11A11A1A11A11A1
	cmp	rax, rdx
	jne	.Lhang
	mov	dword ptr [flag], 1
	.att_syntax prefix
	movq	$60, %rax
	xorq	%rdi, %rdi
	.intel_syntax noprefix
	syscall
.Lhang:
	jmp	.Lhang

.Lfptid:
	lea	rsi, [msg_fptid]
	mov	rdx, msg_fptid_len
	jmp	.Lfailw
.Lfflag:
	lea	rsi, [msg_fflag]
	mov	rdx, msg_fflag_len
	jmp	.Lfailw
.Lfctid:
	lea	rsi, [msg_fctid]
	mov	rdx, msg_fctid_len
	jmp	.Lfailw
.Lfail:
	lea	rsi, [msg_fail]
	mov	rdx, msg_fail_len
.Lfailw:
	.att_syntax prefix
	movq	$1, %rax
	movq	$1, %rdi
	.intel_syntax noprefix
	syscall
	.att_syntax prefix
	movq	$60, %rax
	movq	$1, %rdi
	.intel_syntax noprefix
	syscall
