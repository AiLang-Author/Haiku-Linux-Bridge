/*
 * Static x86_64 Linux ELF: rename/link/symlink/readlink/stat/lstat/
 * clock_gettime/dup/fsync/utimensat. Proof for real Linux sysutils.
 * License: Public Domain / CC0 1.0 Universal
 */

.intel_syntax noprefix
.global _start

.section .bss
.align 16
stbuf:
	.space 144
tsbuf:
	.space 16
rbuf:
	.space 64

.section .rodata
path_src:
	.asciz "/tmp/util.src"
path_hard:
	.asciz "/tmp/util.hard"
path_ren:
	.asciz "/tmp/util.ren"
path_sym:
	.asciz "/tmp/util.sym"
want_link:
	.ascii "/tmp/util.src"
	want_link_len = . - want_link
payload:
	.ascii "UTIL\n"
	payload_len = . - payload
msg_ok:
	.ascii "UTILOK\n"
	msg_ok_len = . - msg_ok
msg_fail:
	.ascii "UTILFAIL "
	msg_fail_len = . - msg_fail
msg_nl:
	.ascii "\n"
	msg_nl_len = . - msg_nl

.section .text
_start:
	/* clock_gettime(CLOCK_REALTIME, tsbuf) — must not be ENOSYS, sec>1e9 */
	.att_syntax prefix
	movq	$228, %rax
	xorq	%rdi, %rdi
	.intel_syntax noprefix
	lea	rsi, [tsbuf]
	syscall
	cmp	rax, -38
	je	.LfailT
	test	rax, rax
	jnz	.LfailT
	mov	rax, qword ptr [tsbuf]
	mov	rdx, 1000000000
	cmp	rax, rdx
	jb	.LfailT

	/* openat(AT_FDCWD, /tmp/util.src, O_RDWR|O_CREAT|O_TRUNC, 0644) */
	.att_syntax prefix
	movq	$257, %rax
	movq	$-100, %rdi
	.intel_syntax noprefix
	lea	rsi, [path_src]
	.att_syntax prefix
	movq	$0x242, %rdx
	movq	$0644, %r10
	.intel_syntax noprefix
	syscall
	test	rax, rax
	js	.LfailF
	mov	r15, rax

	/* write payload */
	.att_syntax prefix
	movq	$1, %rax
	.intel_syntax noprefix
	mov	rdi, r15
	lea	rsi, [payload]
	.att_syntax prefix
	movq	$payload_len, %rdx
	.intel_syntax noprefix
	syscall
	cmp	rax, payload_len
	jne	.LfailF

	/* fsync */
	.att_syntax prefix
	movq	$74, %rax
	.intel_syntax noprefix
	mov	rdi, r15
	syscall
	cmp	rax, -38
	je	.LfailY

	/* close */
	.att_syntax prefix
	movq	$3, %rax
	.intel_syntax noprefix
	mov	rdi, r15
	syscall

	/* link(src, hard) — BFS may return EPERM; ENOSYS is the real miss. */
	.att_syntax prefix
	movq	$86, %rax
	.intel_syntax noprefix
	lea	rdi, [path_src]
	lea	rsi, [path_hard]
	syscall
	cmp	rax, -38
	je	.LfailL
	mov	r12, rax

	/* symlink(src, sym) */
	.att_syntax prefix
	movq	$88, %rax
	.intel_syntax noprefix
	lea	rdi, [path_src]
	lea	rsi, [path_sym]
	syscall
	cmp	rax, -38
	je	.LfailS
	test	rax, rax
	jnz	.LfailS

	/* readlink(sym, rbuf, 64) */
	.att_syntax prefix
	movq	$89, %rax
	.intel_syntax noprefix
	lea	rdi, [path_sym]
	lea	rsi, [rbuf]
	.att_syntax prefix
	movq	$64, %rdx
	.intel_syntax noprefix
	syscall
	cmp	rax, want_link_len
	jne	.LfailR
	mov	rcx, want_link_len
	lea	rsi, [want_link]
	lea	rdi, [rbuf]
	repe	cmpsb
	jne	.LfailR

	/* lstat(sym) — S_IFLNK */
	.att_syntax prefix
	movq	$6, %rax
	.intel_syntax noprefix
	lea	rdi, [path_sym]
	lea	rsi, [stbuf]
	syscall
	test	rax, rax
	jnz	.LfailA
	mov	eax, dword ptr [stbuf + 24]
	and	eax, 0xF000
	cmp	eax, 0xA000
	jne	.LfailA

	/* rename(src, ren) */
	.att_syntax prefix
	movq	$82, %rax
	.intel_syntax noprefix
	lea	rdi, [path_src]
	lea	rsi, [path_ren]
	syscall
	cmp	rax, -38
	je	.LfailN
	test	rax, rax
	jnz	.LfailN

	/* stat(ren) — size 5 */
	.att_syntax prefix
	movq	$4, %rax
	.intel_syntax noprefix
	lea	rdi, [path_ren]
	lea	rsi, [stbuf]
	syscall
	test	rax, rax
	jnz	.LfailA
	mov	rax, qword ptr [stbuf + 48]
	cmp	rax, payload_len
	jne	.LfailA

	/* utimensat(AT_FDCWD, ren, NULL, 0) */
	.att_syntax prefix
	movq	$280, %rax
	movq	$-100, %rdi
	.intel_syntax noprefix
	lea	rsi, [path_ren]
	xor	rdx, rdx
	xor	r10, r10
	syscall
	cmp	rax, -38
	je	.LfailU

	/* dup(1) then write a byte through it (must be a new fd) */
	.att_syntax prefix
	movq	$32, %rax
	movq	$1, %rdi
	.intel_syntax noprefix
	syscall
	cmp	rax, -38
	je	.LfailD
	test	rax, rax
	js	.LfailD
	cmp	rax, 1
	je	.LfailD
	mov	r14, rax

	/* unlink temps */
	.att_syntax prefix
	movq	$87, %rax
	.intel_syntax noprefix
	lea	rdi, [path_ren]
	syscall
	.att_syntax prefix
	movq	$87, %rax
	.intel_syntax noprefix
	lea	rdi, [path_sym]
	syscall
	test	r12, r12
	jnz	1f
	.att_syntax prefix
	movq	$87, %rax
	.intel_syntax noprefix
	lea	rdi, [path_hard]
	syscall
1:

	.att_syntax prefix
	movq	$1, %rax
	.intel_syntax noprefix
	mov	rdi, r14
	lea	rsi, [msg_ok]
	.att_syntax prefix
	movq	$msg_ok_len, %rdx
	.intel_syntax noprefix
	syscall
	jmp	.Lexit

.LfailT:
	mov	bl, 'T'
	jmp	.Lfail
.LfailF:
	mov	bl, 'F'
	jmp	.Lfail
.LfailY:
	mov	bl, 'Y'
	jmp	.Lfail
.LfailL:
	mov	bl, 'L'
	jmp	.Lfail
.LfailS:
	mov	bl, 'S'
	jmp	.Lfail
.LfailR:
	mov	bl, 'R'
	jmp	.Lfail
.LfailA:
	mov	bl, 'A'
	jmp	.Lfail
.LfailN:
	mov	bl, 'N'
	jmp	.Lfail
.LfailU:
	mov	bl, 'U'
	jmp	.Lfail
.LfailD:
	mov	bl, 'D'
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
	mov	byte ptr [rbuf], bl
	.att_syntax prefix
	movq	$1, %rax
	movq	$1, %rdi
	.intel_syntax noprefix
	lea	rsi, [rbuf]
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
	movq	$msg_nl_len, %rdx
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
