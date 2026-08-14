/*
 * Static x86_64 Linux ELF: prove the former return-0 stubs.
 * getuid/setuid/getgid/setgid/gettid/set_tid_address/set_robust_list/
 * prctl name/mprotect/munmap/chmod/fchmod/chown/truncate/ftruncate.
 * License: Public Domain / CC0 1.0 Universal
 */

.intel_syntax noprefix
.global _start

.section .bss
.align 16
stbuf:
	.space 144
namebuf:
	.space 32
tidslot:
	.space 8
robust:
	.space 24

.section .rodata
path_tmp:
	.asciz "/tmp/wstat.tmp"
thr_name:
	.asciz "wstat-thread"
msg_ok:
	.ascii "WSTATOK\n"
	msg_ok_len = . - msg_ok
msg_fail:
	.ascii "WSTATFAIL "
	msg_fail_len = . - msg_fail
msg_nl:
	.ascii "\n"
	msg_nl_len = . - msg_nl

.section .text
_start:
	/* getuid — must not be -ENOSYS */
	.att_syntax prefix
	movq	$102, %rax
	.intel_syntax noprefix
	syscall
	cmp	rax, -38
	je	.LfailU
	mov	r12, rax

	/* geteuid must match getuid (we alias) */
	.att_syntax prefix
	movq	$107, %rax
	.intel_syntax noprefix
	syscall
	cmp	rax, r12
	jne	.LfailU

	/* setuid(1234); getuid()==1234 */
	.att_syntax prefix
	movq	$105, %rax
	movq	$1234, %rdi
	.intel_syntax noprefix
	syscall
	test	rax, rax
	jnz	.Lfailu
	.att_syntax prefix
	movq	$102, %rax
	.intel_syntax noprefix
	syscall
	cmp	rax, 1234
	jne	.Lfailu

	/* setgid(5678); getgid/getegid */
	.att_syntax prefix
	movq	$106, %rax
	movq	$5678, %rdi
	.intel_syntax noprefix
	syscall
	test	rax, rax
	jnz	.LfailG
	.att_syntax prefix
	movq	$104, %rax
	.intel_syntax noprefix
	syscall
	cmp	rax, 5678
	jne	.LfailG
	.att_syntax prefix
	movq	$108, %rax
	.intel_syntax noprefix
	syscall
	cmp	rax, 5678
	jne	.LfailG

	/* gettid > 0 and not -ENOSYS */
	.att_syntax prefix
	movq	$186, %rax
	.intel_syntax noprefix
	syscall
	test	rax, rax
	jle	.LfailT
	mov	r13, rax

	/* set_tid_address(&tidslot) returns same tid */
	.att_syntax prefix
	movq	$218, %rax
	.intel_syntax noprefix
	lea	rdi, [tidslot]
	syscall
	cmp	rax, r13
	jne	.Lfailt

	/* set_robust_list(&robust, 24) == 0 */
	.att_syntax prefix
	movq	$273, %rax
	.intel_syntax noprefix
	lea	rdi, [robust]
	.att_syntax prefix
	movq	$24, %rsi
	.intel_syntax noprefix
	syscall
	test	rax, rax
	jnz	.LfailR

	/* prctl(PR_SET_NAME, "wstat-thread") */
	.att_syntax prefix
	movq	$157, %rax
	movq	$15, %rdi
	.intel_syntax noprefix
	lea	rsi, [thr_name]
	xor	rdx, rdx
	xor	r10, r10
	xor	r8, r8
	syscall
	test	rax, rax
	jnz	.LfailP

	/* prctl(PR_GET_NAME, namebuf) */
	.att_syntax prefix
	movq	$157, %rax
	movq	$16, %rdi
	.intel_syntax noprefix
	lea	rsi, [namebuf]
	xor	rdx, rdx
	xor	r10, r10
	xor	r8, r8
	syscall
	test	rax, rax
	jnz	.LfailP
	/* first 4 bytes of "wstat-thread" are 'w''s''t''a' = 0x61747377 */
	mov	eax, dword ptr [namebuf]
	cmp	eax, 0x61747377
	jne	.LfailP

	/* mmap ANON 4096 RW */
	.att_syntax prefix
	movq	$9, %rax
	xorq	%rdi, %rdi
	movq	$4096, %rsi
	movq	$3, %rdx
	movq	$0x22, %r10
	movq	$-1, %r8
	xorq	%r9, %r9
	.intel_syntax noprefix
	syscall
	test	rax, rax
	js	.LfailM
	mov	r14, rax

	/* mprotect(addr, 4096, PROT_READ|PROT_WRITE) */
	.att_syntax prefix
	movq	$10, %rax
	.intel_syntax noprefix
	mov	rdi, r14
	.att_syntax prefix
	movq	$4096, %rsi
	movq	$3, %rdx
	.intel_syntax noprefix
	syscall
	cmp	rax, -38
	je	.LfailM
	test	rax, rax
	jnz	.LfailM
	mov	byte ptr [r14], 0x5a

	/* munmap */
	.att_syntax prefix
	movq	$11, %rax
	.intel_syntax noprefix
	mov	rdi, r14
	.att_syntax prefix
	movq	$4096, %rsi
	.intel_syntax noprefix
	syscall
	cmp	rax, -38
	je	.LfailM

	/* openat(AT_FDCWD, /tmp/wstat.tmp, O_RDWR|O_CREAT|O_TRUNC, 0644) */
	.att_syntax prefix
	movq	$257, %rax
	movq	$-100, %rdi
	.intel_syntax noprefix
	lea	rsi, [path_tmp]
	.att_syntax prefix
	movq	$0x242, %rdx		/* O_RDWR|O_CREAT|O_TRUNC */
	movq	$0644, %r10
	.intel_syntax noprefix
	syscall
	test	rax, rax
	js	.LfailF
	mov	r15, rax

	/* ftruncate(fd, 1234) */
	.att_syntax prefix
	movq	$77, %rax
	.intel_syntax noprefix
	mov	rdi, r15
	.att_syntax prefix
	movq	$1234, %rsi
	.intel_syntax noprefix
	syscall
	cmp	rax, -38
	je	.LfailZ
	test	rax, rax
	jnz	.LfailZ

	/* fstat — size @48 == 1234 */
	.att_syntax prefix
	movq	$5, %rax
	.intel_syntax noprefix
	mov	rdi, r15
	lea	rsi, [stbuf]
	syscall
	test	rax, rax
	jnz	.LfailZ
	mov	rax, qword ptr [stbuf + 48]
	cmp	rax, 1234
	jne	.LfailZ

	/* fchmod(fd, 0600) */
	.att_syntax prefix
	movq	$91, %rax
	.intel_syntax noprefix
	mov	rdi, r15
	.att_syntax prefix
	movq	$0600, %rsi
	.intel_syntax noprefix
	syscall
	cmp	rax, -38
	je	.LfailC
	test	rax, rax
	jnz	.LfailC

	/* fstat — mode @24 & 0777 == 0600 */
	.att_syntax prefix
	movq	$5, %rax
	.intel_syntax noprefix
	mov	rdi, r15
	lea	rsi, [stbuf]
	syscall
	test	rax, rax
	jnz	.LfailC
	mov	eax, dword ptr [stbuf + 24]
	and	eax, 0777
	cmp	eax, 0600
	jne	.LfailC

	/* chmod(path, 0644) */
	.att_syntax prefix
	movq	$90, %rax
	.intel_syntax noprefix
	lea	rdi, [path_tmp]
	.att_syntax prefix
	movq	$0644, %rsi
	.intel_syntax noprefix
	syscall
	cmp	rax, -38
	je	.Lfailc

	/* chown(path, -1, -1) no-op must succeed */
	.att_syntax prefix
	movq	$92, %rax
	.intel_syntax noprefix
	lea	rdi, [path_tmp]
	.att_syntax prefix
	movq	$0xffffffff, %rsi
	movq	$0xffffffff, %rdx
	.intel_syntax noprefix
	syscall
	cmp	rax, -38
	je	.LfailO
	test	rax, rax
	jnz	.LfailO

	/* fchown(fd, -1, -1) */
	.att_syntax prefix
	movq	$93, %rax
	.intel_syntax noprefix
	mov	rdi, r15
	.att_syntax prefix
	movq	$0xffffffff, %rsi
	movq	$0xffffffff, %rdx
	.intel_syntax noprefix
	syscall
	cmp	rax, -38
	je	.LfailO

	/* lchown(path, -1, -1) */
	.att_syntax prefix
	movq	$94, %rax
	.intel_syntax noprefix
	lea	rdi, [path_tmp]
	.att_syntax prefix
	movq	$0xffffffff, %rsi
	movq	$0xffffffff, %rdx
	.intel_syntax noprefix
	syscall
	cmp	rax, -38
	je	.LfailO

	/* fchmodat(AT_FDCWD, path, 0644, 0) */
	.att_syntax prefix
	movq	$268, %rax
	movq	$-100, %rdi
	.intel_syntax noprefix
	lea	rsi, [path_tmp]
	.att_syntax prefix
	movq	$0644, %rdx
	xorq	%r10, %r10
	.intel_syntax noprefix
	syscall
	cmp	rax, -38
	je	.Lfailc

	/* fchownat(AT_FDCWD, path, -1, -1, 0) */
	.att_syntax prefix
	movq	$260, %rax
	movq	$-100, %rdi
	.intel_syntax noprefix
	lea	rsi, [path_tmp]
	.att_syntax prefix
	movq	$0xffffffff, %rdx
	movq	$0xffffffff, %r10
	xorq	%r8, %r8
	.intel_syntax noprefix
	syscall
	cmp	rax, -38
	je	.LfailO

	/* truncate(path, 100) */
	.att_syntax prefix
	movq	$76, %rax
	.intel_syntax noprefix
	lea	rdi, [path_tmp]
	.att_syntax prefix
	movq	$100, %rsi
	.intel_syntax noprefix
	syscall
	cmp	rax, -38
	je	.LfailZ

	/* close */
	.att_syntax prefix
	movq	$3, %rax
	.intel_syntax noprefix
	mov	rdi, r15
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
	jmp	.Lexit

.LfailU:
	mov	bl, 'U'
	jmp	.Lfail
.Lfailu:
	mov	bl, 'u'
	jmp	.Lfail
.LfailG:
	mov	bl, 'G'
	jmp	.Lfail
.LfailT:
	mov	bl, 'T'
	jmp	.Lfail
.Lfailt:
	mov	bl, 't'
	jmp	.Lfail
.LfailR:
	mov	bl, 'R'
	jmp	.Lfail
.LfailP:
	mov	bl, 'P'
	jmp	.Lfail
.LfailM:
	mov	bl, 'M'
	jmp	.Lfail
.LfailF:
	mov	bl, 'F'
	jmp	.Lfail
.LfailZ:
	mov	bl, 'Z'
	jmp	.Lfail
.LfailC:
	mov	bl, 'C'
	jmp	.Lfail
.Lfailc:
	mov	bl, 'c'
	jmp	.Lfail
.LfailO:
	mov	bl, 'O'
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
	mov	byte ptr [namebuf], bl
	.att_syntax prefix
	movq	$1, %rax
	movq	$1, %rdi
	.intel_syntax noprefix
	lea	rsi, [namebuf]
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
