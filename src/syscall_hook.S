/*
 * x86_64 LSTAR trampoline — identity for Haiku, remap for Linux.
 *
 * Haiku path: push/pop rax, jmp original LSTAR. No swapgs.
 * Linux-marked CR3: rewrite rax (and args if needed) to the equivalent
 * Haiku syscall and jmp original LSTAR. Unknown numbers sysret -ENOSYS.
 * Never call C from here. Never switch stacks. A bad Linux number
 * must not panic the kernel.
 *
 * Mark (syscall 0x1337) is handled BEFORE the CR3 check so a Haiku
 * team can opt in. It stores CR3 with PCID bits cleared and sysrets 0.
 * Do not return through libc after that — jmp the Linux image next.
 *
 * Haiku numbers from this image's libroot stubs (hrev57937):
 *   _kern_read       = 0x95 (149)
 *   _kern_write      = 0x97 (151)
 *   _kern_close      = 0x9e (158)
 *   _kern_seek       = 0x79 (121)
 *   _kern_open       = 0x72 (114)
 *   _kern_exit_team  = 0x29 (41)
 *
 * Haiku x86_64 SYSCALL ABI matches Linux: 4th arg in r10 (SYSCALL
 * clobbers rcx). Kernel then moves r10 -> rcx before the _user_* call.
 *
 * License: Public Domain / CC0 1.0 Universal
 */

	.intel_syntax noprefix
	.text
	.globl	sys_compat_lstar
	.globl	gOrigLstar
	.globl	gLinuxCR3
	.globl	gMarkCount
	.globl	gLinuxHits
	.globl	gLastLinuxRax
	.hidden	gOrigLstar
	.hidden	gLinuxCR3
	.hidden	gMarkCount
	.hidden	gLinuxHits
	.hidden	gLastLinuxRax

#define SYS_COMPAT_MARK_NR	0x1337

sys_compat_lstar:
	cmp	rax, SYS_COMPAT_MARK_NR
	je	.Lmark

	push	rax
	mov	rax, cr3
	and	rax, 0xfffffffffffff000	/* drop PCID */
	cmp	qword ptr [rip + gLinuxCR3], 0
	je	.Lhaiku
	cmp	rax, [rip + gLinuxCR3]
	je	.Llinux
.Lhaiku:
	pop	rax
	jmp	[rip + gOrigLstar]

.Lmark:
	/* Still on the user stack, user GS. Do not swapgs. */
	mov	rax, cr3
	and	rax, 0xfffffffffffff000
	mov	[rip + gLinuxCR3], rax
	inc	qword ptr [rip + gMarkCount]
	xor	rax, rax
	sysretq

.Llinux:
	pop	rax
	inc	qword ptr [rip + gLinuxHits]
	mov	[rip + gLastLinuxRax], rax

	cmp	rax, 0			/* Linux read */
	je	.Lread
	cmp	rax, 1			/* Linux write */
	je	.Lwrite
	cmp	rax, 2			/* Linux open */
	je	.Lopen
	cmp	rax, 3			/* Linux close */
	je	.Lclose
	cmp	rax, 8			/* Linux lseek */
	je	.Llseek
	cmp	rax, 257		/* Linux openat */
	je	.Lopenat
	cmp	rax, 60			/* Linux exit */
	je	.Lexit
	cmp	rax, 231		/* Linux exit_group */
	je	.Lexit

	/* Reject, do not panic. SYSCALL already left RIP in RCX, RFLAGS in R11. */
	mov	rax, -38		/* -ENOSYS */
	sysretq

.Lread:
	/* Linux: rdi=fd rsi=buf rdx=count
	 * Haiku _kern_read: rdi=fd rsi=pos rdx=buf rcx/r10=count
	 * Numbers from guest libroot: _kern_read=0x95 (49 89 ca; mov rax,0x95)
	 */
	mov	r10, rdx
	mov	rdx, rsi
	mov	rsi, -1
	mov	rax, 0x95
	jmp	[rip + gOrigLstar]

.Lwrite:
	/* Linux: rdi=fd rsi=buf rdx=count
	 * Haiku _kern_write: rdi=fd rsi=pos rdx=buf rcx/r10=count
	 */
	mov	r10, rdx
	mov	rdx, rsi
	mov	rsi, -1
	mov	rax, 0x97
	jmp	[rip + gOrigLstar]

.Lclose:
	/* Linux: rdi=fd  Haiku _kern_close: rdi=fd  (0x9e) */
	mov	rax, 0x9e
	jmp	[rip + gOrigLstar]

.Llseek:
	/* Linux lseek(fd,off,whence) == Haiku _kern_seek. SEEK_*=0/1/2. */
	mov	rax, 0x79
	jmp	[rip + gOrigLstar]

	/*
	 * Linux -> Haiku open flags. ACCMODE (0..2) match.
	 * Other bits collide (Linux O_CREAT 0x40 == Haiku O_CLOEXEC).
	 * Rebuild in r8 from known Linux bits. Clobbers r8.
	 */
.macro XLAT_OFLAGS
	mov	r8, rdx
	and	r8, 3			/* O_ACCMODE */
	test	rdx, 0x40		/* LINUX O_CREAT */
	jz	1f
	or	r8, 0x200		/* HAIKU O_CREAT */
1:
	test	rdx, 0x80		/* LINUX O_EXCL */
	jz	2f
	or	r8, 0x100		/* HAIKU O_EXCL */
2:
	test	rdx, 0x200		/* LINUX O_TRUNC */
	jz	3f
	or	r8, 0x400		/* HAIKU O_TRUNC */
3:
	test	rdx, 0x400		/* LINUX O_APPEND */
	jz	4f
	or	r8, 0x800		/* HAIKU O_APPEND */
4:
	test	rdx, 0x800		/* LINUX O_NONBLOCK */
	jz	5f
	or	r8, 0x80		/* HAIKU O_NONBLOCK */
5:
	test	rdx, 0x80000		/* LINUX O_CLOEXEC */
	jz	6f
	or	r8, 0x40		/* HAIKU O_CLOEXEC */
6:
	test	rdx, 0x10000		/* LINUX O_DIRECTORY */
	jz	7f
	or	r8, 0x200000		/* HAIKU O_DIRECTORY */
7:
	test	rdx, 0x20000		/* LINUX O_NOFOLLOW */
	jz	8f
	or	r8, 0x80000		/* HAIKU O_NOFOLLOW */
8:
	mov	rdx, r8
.endm

.Lopen:
	/* Linux: rdi=path rsi=flags rdx=mode
	 * Haiku _kern_open(dirfd,path,openMode,perms): AT_FDCWD=-100 on both
	 */
	mov	r10, rdx
	mov	rdx, rsi
	XLAT_OFLAGS
	mov	rsi, rdi
	mov	rdi, -100
	mov	rax, 0x72
	jmp	[rip + gOrigLstar]

.Lopenat:
	/* Linux: rdi=dirfd rsi=path rdx=flags r10=mode — same layout */
	XLAT_OFLAGS
	mov	rax, 0x72
	jmp	[rip + gOrigLstar]

.Lexit:
	/* Linux: rdi=code  Haiku _kern_exit_team: rdi=status */
	mov	qword ptr [rip + gLinuxCR3], 0
	mov	rax, 0x29
	jmp	[rip + gOrigLstar]

	.bss
	.align	8
gOrigLstar:
	.quad	0
gLinuxCR3:
	.quad	0
gMarkCount:
	.quad	0
gLinuxHits:
	.quad	0
gLastLinuxRax:
	.quad	0
