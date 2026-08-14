/*
 * Static x86_64 Linux ELF: fcntl GET/SET FL/FD + DUPFD + statx.
 * License: Public Domain / CC0 1.0 Universal
 */

.intel_syntax noprefix
.global _start

.section .bss
.align 16
stx:
	.space 256
stbuf:
	.space 144

.section .rodata
path_tmp:
	.asciz "/tmp/fcntl.tmp"
payload:
	.ascii "FCNT\n"
	payload_len = . - payload
msg_ok:
	.ascii "FCNTOK\n"
	msg_ok_len = . - msg_ok
msg_fail:
	.ascii "FCNTFAIL "
	msg_fail_len = . - msg_fail
msg_nl:
	.ascii "\n"

.section .text
_start:
	/* openat create RDWR */
	.att_syntax prefix
	movq	$257, %rax
	movq	$-100, %rdi
	.intel_syntax noprefix
	lea	rsi, [path_tmp]
	.att_syntax prefix
	movq	$0x242, %rdx
	movq	$0644, %r10
	.intel_syntax noprefix
	syscall
	test	rax, rax
	js	.LfailF
	mov	r15, rax

	/* write 5 bytes */
	.att_syntax prefix
	movq	$1, %rax
	.intel_syntax noprefix
	mov	rdi, r15
	lea	rsi, [payload]
	.att_syntax prefix
	movq	$payload_len, %rdx
	.intel_syntax noprefix
	syscall

	/* fcntl F_GETFL=3 */
	.att_syntax prefix
	movq	$72, %rax
	.intel_syntax noprefix
	mov	rdi, r15
	.att_syntax prefix
	movq	$3, %rsi
	.intel_syntax noprefix
	xor	rdx, rdx
	syscall
	cmp	rax, -38
	je	.LfailC
	test	rax, rax
	js	.LfailC
	and	eax, 3
	cmp	eax, 2			/* O_RDWR */
	jne	.LfailC

	/* fcntl F_SETFL=4 O_APPEND=0x400 */
	.att_syntax prefix
	movq	$72, %rax
	.intel_syntax noprefix
	mov	rdi, r15
	.att_syntax prefix
	movq	$4, %rsi
	movq	$0x400, %rdx
	.intel_syntax noprefix
	syscall
	cmp	rax, -38
	je	.LfailC
	test	rax, rax
	jnz	.LfailC

	/* F_GETFL must now have APPEND */
	.att_syntax prefix
	movq	$72, %rax
	.intel_syntax noprefix
	mov	rdi, r15
	.att_syntax prefix
	movq	$3, %rsi
	.intel_syntax noprefix
	xor	rdx, rdx
	syscall
	test	eax, 0x400
	jz	.LfailC

	/* F_SETFD=2 FD_CLOEXEC=1 ; F_GETFD=1 */
	.att_syntax prefix
	movq	$72, %rax
	.intel_syntax noprefix
	mov	rdi, r15
	.att_syntax prefix
	movq	$2, %rsi
	movq	$1, %rdx
	.intel_syntax noprefix
	syscall
	test	rax, rax
	jnz	.LfailD
	.att_syntax prefix
	movq	$72, %rax
	.intel_syntax noprefix
	mov	rdi, r15
	.att_syntax prefix
	movq	$1, %rsi
	.intel_syntax noprefix
	xor	rdx, rdx
	syscall
	cmp	rax, 1
	jne	.LfailD

	/* F_DUPFD=0 min=10 */
	.att_syntax prefix
	movq	$72, %rax
	.intel_syntax noprefix
	mov	rdi, r15
	xor	rsi, rsi
	.att_syntax prefix
	movq	$10, %rdx
	.intel_syntax noprefix
	syscall
	cmp	rax, 10
	jl	.LfailU
	mov	r14, rax

	/* fadvise64(fd,0,0,0) must not ENOSYS */
	.att_syntax prefix
	movq	$221, %rax
	.intel_syntax noprefix
	mov	rdi, r15
	xor	rsi, rsi
	xor	rdx, rdx
	xor	r10, r10
	syscall
	cmp	rax, -38
	je	.LfailA

	/* statx(AT_FDCWD, path, 0, BASIC, &stx) */
	.att_syntax prefix
	movq	$332, %rax
	movq	$-100, %rdi
	.intel_syntax noprefix
	lea	rsi, [path_tmp]
	xor	rdx, rdx
	.att_syntax prefix
	movq	$0x7ff, %r10
	.intel_syntax noprefix
	lea	r8, [stx]
	syscall
	cmp	rax, -38
	je	.LfailX
	test	rax, rax
	jnz	.LfailX
	/* stx_size @40, stx_mode @28 */
	mov	rax, qword ptr [stx + 40]
	cmp	rax, payload_len
	jne	.LfailX
	movzx	eax, word ptr [stx + 28]
	and	eax, 0xF000
	cmp	eax, 0x8000
	jne	.LfailX

	/* close + unlink */
	.att_syntax prefix
	movq	$3, %rax
	.intel_syntax noprefix
	mov	rdi, r15
	syscall
	.att_syntax prefix
	movq	$3, %rax
	.intel_syntax noprefix
	mov	rdi, r14
	syscall
	.att_syntax prefix
	movq	$87, %rax
	.intel_syntax noprefix
	lea	rdi, [path_tmp]
	syscall

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
	.intel_syntax noprefix
	xor	rdi, rdi
	syscall

.LfailF:
	mov	bl, 'F'
	jmp	.Lfail
.LfailC:
	mov	bl, 'C'
	jmp	.Lfail
.LfailD:
	mov	bl, 'D'
	jmp	.Lfail
.LfailU:
	mov	bl, 'U'
	jmp	.Lfail
.LfailA:
	mov	bl, 'A'
	jmp	.Lfail
.LfailX:
	mov	bl, 'X'
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
	mov	byte ptr [stbuf], bl
	.att_syntax prefix
	movq	$1, %rax
	movq	$1, %rdi
	.intel_syntax noprefix
	lea	rsi, [stbuf]
	.att_syntax prefix
	movq	$1, %rdx
	.intel_syntax noprefix
	syscall
	.att_syntax prefix
	movq	$1, %rax
	movq	$1, %rdi
	.intel_syntax noprefix
	lea	rsi, [msg_nl]
	.att_syntax prefix
	movq	$1, %rdx
	.intel_syntax noprefix
	syscall
	.att_syntax prefix
	movq	$60, %rax
	movq	$1, %rdi
	.intel_syntax noprefix
	syscall
