/*
 * x86_64 LSTAR trampoline — identity for Haiku, remap for Linux.
 *
 * Haiku path: push/pop rax, jmp original LSTAR. No swapgs.
 * Linux-marked CR3: rewrite rax (and args if needed) to the equivalent
 * Haiku syscall and jmp original LSTAR. Unknown numbers sysret -ENOSYS.
 * Linux rseq (334) is implemented here (register + cpu_id=0), not
 * in the Haiku kernel. Never call C from here. Never switch stacks.
 * A bad Linux number must not panic the kernel.
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
	.globl	gBrkBase
	.globl	gBrkCur
	.globl	gMapCur
	.globl	gArenaHi
	.globl	gLastN
	.globl	gLastNidx
	.globl	gUlsOff
	.globl	gLinuxFS
	.globl	gRseqPtr
	.globl	gRseqLen
	.globl	gRseqSig
	.hidden	gOrigLstar
	.hidden	gLinuxCR3
	.hidden	gMarkCount
	.hidden	gLinuxHits
	.hidden	gLastLinuxRax
	.hidden	gBrkBase
	.hidden	gBrkCur
	.hidden	gMapCur
	.hidden	gArenaHi
	.hidden	gLastN
	.hidden	gLastNidx
	.hidden	gUlsOff
	.hidden	gLinuxFS
	.hidden	gRseqPtr
	.hidden	gRseqLen
	.hidden	gRseqSig

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
	/* Still on the user stack, user GS. Do not swapgs.
	 * rdi = optional arena base, rsi = size (0 = no arena).
	 */
	mov	rax, cr3
	and	rax, 0xfffffffffffff000
	mov	[rip + gLinuxCR3], rax
	inc	qword ptr [rip + gMarkCount]
	cmp	rsi, 4096
	jb	.Lmark_noarena
	test	rdi, rdi
	jz	.Lmark_noarena
	mov	[rip + gBrkBase], rdi
	mov	[rip + gBrkCur], rdi
	add	rdi, rsi
	mov	[rip + gArenaHi], rdi
	mov	[rip + gMapCur], rdi
	jmp	.Lmark_ok
.Lmark_noarena:
	mov	qword ptr [rip + gBrkBase], 0
	mov	qword ptr [rip + gBrkCur], 0
	mov	qword ptr [rip + gMapCur], 0
	mov	qword ptr [rip + gArenaHi], 0
.Lmark_ok:
	mov	qword ptr [rip + gLinuxFS], 0
	mov	qword ptr [rip + gRseqPtr], 0
	mov	qword ptr [rip + gRseqLen], 0
	mov	qword ptr [rip + gRseqSig], 0
	xor	rax, rax
	sysretq

.Llinux:
	pop	rax
	inc	qword ptr [rip + gLinuxHits]
	mov	[rip + gLastLinuxRax], rax
	push	r8
	push	r9
	lea	r9, [rip + gLastN]
	mov	r8, [rip + gLastNidx]
	and	r8, 7
	mov	[r9 + r8 * 8], rax
	inc	qword ptr [rip + gLastNidx]
	pop	r9
	pop	r8

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
	cmp	rax, 9			/* Linux mmap */
	je	.Lmmap
	cmp	rax, 10			/* Linux mprotect */
	je	.Lok0
	cmp	rax, 11			/* Linux munmap */
	je	.Lok0
	cmp	rax, 12			/* Linux brk */
	je	.Lbrk
	cmp	rax, 39			/* Linux getpid */
	je	.Lget1
	cmp	rax, 102		/* getuid */
	je	.Lget0
	cmp	rax, 104		/* getgid */
	je	.Lget0
	cmp	rax, 105		/* setuid */
	je	.Lok0
	cmp	rax, 106		/* setgid */
	je	.Lok0
	cmp	rax, 107		/* geteuid */
	je	.Lget0
	cmp	rax, 108		/* getegid */
	je	.Lget0
	cmp	rax, 157		/* prctl */
	je	.Lok0
	cmp	rax, 158		/* Linux arch_prctl */
	je	.Larch_prctl
	cmp	rax, 186		/* Linux gettid */
	je	.Lget1
	cmp	rax, 218		/* Linux set_tid_address */
	je	.Lget1
	cmp	rax, 257		/* Linux openat */
	je	.Lopenat
	cmp	rax, 262		/* newfstatat */
	je	.Lenoent
	cmp	rax, 267		/* readlinkat */
	je	.Lreadlinkat
	cmp	rax, 273		/* Linux set_robust_list */
	je	.Lok0
	cmp	rax, 302		/* prlimit64 */
	je	.Lprlimit
	cmp	rax, 318		/* getrandom */
	je	.Lgetrandom
	cmp	rax, 334		/* Linux rseq — register in this layer */
	je	.Lrseq
	cmp	rax, 60			/* Linux exit */
	je	.Lexit
	cmp	rax, 231		/* Linux exit_group */
	je	.Lexit

	/* Reject, do not panic. SYSCALL already left RIP in RCX, RFLAGS in R11. */
	mov	rax, -38		/* -ENOSYS */
	jmp	.Lret

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
	mov	qword ptr [rip + gLinuxFS], 0
	mov	qword ptr [rip + gRseqPtr], 0
	mov	qword ptr [rip + gRseqLen], 0
	mov	qword ptr [rip + gRseqSig], 0
	mov	rax, 0x29
	jmp	[rip + gOrigLstar]

.Lok0:
	xor	rax, rax
	jmp	.Lret

.Lget1:
	/* getpid/gettid/set_tid_address: return a fake tid of 1. */
	mov	rax, 1
	jmp	.Lret

.Lget0:
	xor	rax, rax
	jmp	.Lret

.Lenoent:
	mov	rax, -2			/* -ENOENT */
	jmp	.Lret

.Lprlimit:
	/* rdi=pid rsi=resource rdx=new r10=old. Fill old with 8MB/∞. */
	test	r10, r10
	jz	.Lok0
	stac
	mov	qword ptr [r10], 0x800000
	mov	qword ptr [r10 + 8], -1
	clac
	xor	rax, rax
	jmp	.Lret

.Lgetrandom:
	/* rdi=buf rsi=len — write up to 8 bytes from rdtsc, return len. */
	test	rdi, rdi
	jz	.Lnomem
	test	rsi, rsi
	jz	.Lok0
	rdtsc
	stac
	mov	[rdi], eax
	cmp	rsi, 4
	jbe	1f
	mov	[rdi + 4], edx
1:
	clac
	mov	rax, rsi
	cmp	rax, 8
	jbe	.Lret
	mov	rax, 8
	jmp	.Lret

.Lreadlinkat:
	/* Fake /proc/self/exe → "/boot/home/busybox". rdx=buf r10=bufsiz. */
	test	rdx, rdx
	jz	.Lnomem
	cmp	r10, 18
	jb	.Lnomem
	stac
	mov	byte ptr [rdx + 0], '/'
	mov	byte ptr [rdx + 1], 'b'
	mov	byte ptr [rdx + 2], 'o'
	mov	byte ptr [rdx + 3], 'o'
	mov	byte ptr [rdx + 4], 't'
	mov	byte ptr [rdx + 5], '/'
	mov	byte ptr [rdx + 6], 'h'
	mov	byte ptr [rdx + 7], 'o'
	mov	byte ptr [rdx + 8], 'm'
	mov	byte ptr [rdx + 9], 'e'
	mov	byte ptr [rdx + 10], '/'
	mov	byte ptr [rdx + 11], 'b'
	mov	byte ptr [rdx + 12], 'u'
	mov	byte ptr [rdx + 13], 's'
	mov	byte ptr [rdx + 14], 'y'
	mov	byte ptr [rdx + 15], 'b'
	mov	byte ptr [rdx + 16], 'o'
	mov	byte ptr [rdx + 17], 'x'
	clac
	mov	rax, 18
	jmp	.Lret

.Lbrk:
	/* Linux brk(rdi): return new break, or current on failure/query. */
	cmp	qword ptr [rip + gBrkBase], 0
	je	.Lenosys
	mov	rax, [rip + gBrkCur]
	test	rdi, rdi
	jz	.Lret
	cmp	rdi, [rip + gBrkBase]
	jb	.Lret
	cmp	rdi, [rip + gMapCur]
	ja	.Lret
	mov	[rip + gBrkCur], rdi
	mov	rax, rdi
	jmp	.Lret

.Lmmap:
	/* Linux: rdi=addr rsi=len rdx=prot r10=flags r8=fd r9=off
	 * ANON only, carved from the loader arena. File mmap is later.
	 */
	cmp	qword ptr [rip + gBrkBase], 0
	je	.Lnomem
	test	r10, 0x20		/* MAP_ANONYMOUS */
	jz	.Lnomem
	mov	rax, rsi
	add	rax, 4095
	and	rax, 0xfffffffffffff000
	jz	.Lnomem
	test	r10, 0x10		/* MAP_FIXED */
	jz	.Lmmap_carve
	cmp	rdi, [rip + gBrkBase]
	jb	.Lnomem
	mov	rsi, rdi
	add	rsi, rax
	cmp	rsi, [rip + gArenaHi]
	ja	.Lnomem
	mov	rax, rdi
	jmp	.Lret
.Lmmap_carve:
	mov	rsi, [rip + gMapCur]
	sub	rsi, rax
	cmp	rsi, [rip + gBrkCur]
	jb	.Lnomem
	and	rsi, 0xfffffffffffff000
	mov	[rip + gMapCur], rsi
	mov	rax, rsi
	jmp	.Lret

.Lapply_fs:
	/* rcx/r11 must be saved by caller (SYSCALL RIP/RFLAGS). */
	swapgs
	cmp	qword ptr [rip + gUlsOff], 0
	je	1f
	mov	r8, [gs:0]
	add	r8, [rip + gUlsOff]
	mov	r9, [rip + gLinuxFS]
	mov	[r8], r9
1:
	mov	rax, [rip + gLinuxFS]
	mov	rdx, rax
	shr	rdx, 32
	mov	ecx, 0xC0000100
	wrmsr
	swapgs
	ret

.Larch_prctl:
	cmp	rdi, 0x1002		/* ARCH_SET_FS */
	jne	.Lenosys
	mov	[rip + gLinuxFS], rsi
	push	rcx
	push	r11
	call	.Lapply_fs
	pop	r11
	pop	rcx
	xor	rax, rax
	jmp	.Lret

.Lnomem:
	mov	rax, -12		/* -ENOMEM */
	jmp	.Lret
.Leinval:
	mov	rax, -22		/* -EINVAL */
	jmp	.Lret
.Leperm:
	mov	rax, -1			/* -EPERM */
	jmp	.Lret
.Lebusy:
	mov	rax, -16		/* -EBUSY */
	jmp	.Lret
.Lefault:
	mov	rax, -14		/* -EFAULT */
	jmp	.Lret
.Lenosys:
	mov	rax, -38		/* -ENOSYS */
	jmp	.Lret

	/*
	 * Linux sys_rseq(rseq, rseq_len, flags, sig)
	 *   rdi=struct rseq*  rsi=len  rdx=flags  r10=sig
	 * Spec: linux/kernel/rseq.c (ORIG_RSEQ_SIZE=32).
	 * This layer owns the Linux ABI. Haiku's scheduler is not rseq.
	 * cpu_id / cpu_id_start are pinned to 0 (one logical CPU).
	 * Preempt-abort (RIP -> abort_ip) is not hooked yet.
	 */
.Lrseq:
	test	rdi, rdi
	jz	.Lefault
	test	rdx, 1			/* RSEQ_FLAG_UNREGISTER */
	jnz	.Lrseq_unreg
	test	rdx, rdx		/* no other flags (no slice ext) */
	jnz	.Leinval
	cmp	rsi, 32			/* ORIG_RSEQ_SIZE */
	jb	.Leinval
	test	rdi, 31			/* 32-byte align */
	jnz	.Leinval
	mov	rax, [rip + gRseqPtr]
	test	rax, rax
	jz	.Lrseq_new
	cmp	rax, rdi
	jne	.Leinval
	cmp	rsi, [rip + gRseqLen]
	jne	.Leinval
	cmp	r10d, dword ptr [rip + gRseqSig]
	jne	.Leperm
	jmp	.Lebusy
.Lrseq_new:
	stac
	mov	qword ptr [rdi + 8], 0	/* rseq_cs = NULL */
	mov	dword ptr [rdi + 16], 0	/* flags */
	mov	dword ptr [rdi], 0	/* cpu_id_start = 0 */
	mov	dword ptr [rdi + 4], 0	/* cpu_id = 0 */
	cmp	rsi, 28
	jb	1f
	mov	dword ptr [rdi + 20], 0	/* node_id */
	mov	dword ptr [rdi + 24], 0	/* mm_cid */
1:
	clac
	mov	[rip + gRseqPtr], rdi
	mov	[rip + gRseqLen], rsi
	mov	[rip + gRseqSig], r10
	xor	rax, rax
	jmp	.Lret
.Lrseq_unreg:
	cmp	rdx, 1			/* only RSEQ_FLAG_UNREGISTER */
	jne	.Leinval
	cmp	rdi, [rip + gRseqPtr]
	jne	.Leinval
	cmp	qword ptr [rip + gRseqPtr], 0
	je	.Leinval
	cmp	rsi, [rip + gRseqLen]
	jne	.Leinval
	cmp	r10d, dword ptr [rip + gRseqSig]
	jne	.Leperm
	stac
	mov	dword ptr [rdi], 0		/* cpu_id_start = 0 */
	mov	dword ptr [rdi + 4], -1		/* UNINITIALIZED */
	clac
	mov	qword ptr [rip + gRseqPtr], 0
	mov	qword ptr [rip + gRseqLen], 0
	mov	qword ptr [rip + gRseqSig], 0
	xor	rax, rax
	jmp	.Lret

.Lret:
	/* Keep registered cpu_id fields at 0 on every stub sysret.
	 * Preserve rax (return) and all userspace regs except rcx/r11.
	 */
	cmp	qword ptr [rip + gRseqPtr], 0
	je	.Lsysret
	push	rax
	push	rdi
	mov	rdi, [rip + gRseqPtr]
	stac
	mov	dword ptr [rdi], 0
	mov	dword ptr [rdi + 4], 0
	clac
	pop	rdi
	pop	rax
.Lsysret:
	sysretq

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
gBrkBase:
	.quad	0
gBrkCur:
	.quad	0
gMapCur:
	.quad	0
gArenaHi:
	.quad	0
gLastNidx:
	.quad	0
gLastN:
	.quad	0, 0, 0, 0, 0, 0, 0, 0
gUlsOff:
	.quad	0
gLinuxFS:
	.quad	0
gRseqPtr:
	.quad	0
gRseqLen:
	.quad	0
gRseqSig:
	.quad	0
