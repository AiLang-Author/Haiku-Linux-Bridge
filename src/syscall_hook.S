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
 *   _kern_write_stat = 0x9d (157)
 *   _kern_unmap_memory            = 0xd5 (213)
 *   _kern_set_memory_protection   = 0xd6 (214)
 *   _kern_rename_thread           = 0x38 (56)
 *
 * Haiku x86_64 SYSCALL ABI matches Linux: 4th arg in r10 (SYSCALL
 * clobbers rcx). Kernel then moves r10 -> rcx before the _user_* call.
 *
 * License: Public Domain / CC0 1.0 Universal
 */

	.intel_syntax noprefix
	.text

	/* COM1 0x3f8 — QEMU -serial file:. Independent of Haiku
	 * serial_debug_output (dprintf is gated on that flag). */
	.macro KSER ch
	push	rax
	push	rcx
	push	rdx
	mov	ecx, 100000
	mov	dx, 0x3fd
1:
	in	al, dx
	test	al, 0x20
	jnz	2f
	dec	ecx
	jnz	1b
2:
	mov	al, \ch
	mov	dx, 0x3f8
	out	dx, al
	pop	rdx
	pop	rcx
	pop	rax
	.endm
	.globl	sys_compat_lstar
	.globl	gOrigLstar
	.globl	gLinuxCR3
	.globl	gLinuxTeam
	.globl	gLinuxN
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
	.globl	gSavedRsp
	.globl	gKstackEnd
	.globl	gKstack
	.globl	gForkPending
	.globl	gForkTramp
	.globl	gForkHaikuRsp
	.globl	gForkUserRip
	.globl	gForkUserRsp
	.globl	gForkUserFlags
	.hidden	gOrigLstar
	.hidden	gLinuxCR3
	.hidden	gLinuxTeam
	.hidden	gLinuxN
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
	.hidden	gSavedRsp
	.hidden	gKstackEnd
	.hidden	gKstack
	.hidden	gForkPending
	.hidden	gForkTramp
	.hidden	gForkHaikuRsp
	.hidden	gForkUserRip
	.hidden	gForkUserRsp
	.hidden	gForkUserFlags

	.extern	sys_compat_getdents64
	.extern	sys_compat_stat
	.extern	sys_compat_mkdir
	.extern	sys_compat_unlink
	.extern	sys_compat_access
	.extern	sys_compat_getcwd
	.extern	sys_compat_chdir
	.extern	sys_compat_mark_team
	.extern	sys_compat_adopt
	.extern	sys_compat_getpid
	.extern	sys_compat_wait4
	.extern	sys_compat_wstat
	.extern	sys_compat_mprotect
	.extern	sys_compat_munmap
	.extern	sys_compat_getuid
	.extern	sys_compat_getgid
	.extern	sys_compat_setuid
	.extern	sys_compat_setgid
	.extern	sys_compat_gettid
	.extern	sys_compat_set_tid_address
	.extern	sys_compat_set_robust_list
	.extern	sys_compat_prctl
	.extern	sys_compat_rename
	.extern	sys_compat_symlink
	.extern	sys_compat_link
	.extern	sys_compat_readlink
	.extern	sys_compat_dup
	.extern	sys_compat_dup2
	.extern	sys_compat_fsync
	.extern	sys_compat_clock_gettime
	.extern	sys_compat_utimensat
	.extern	sys_compat_time
	.extern	sys_compat_gettimeofday
	.extern	sys_compat_getppid
	.extern	sys_compat_pipe2
	.extern	sys_compat_nanosleep
	.extern	sys_compat_fcntl
	.extern	sys_compat_statx
	.extern	sys_compat_try_fork
	.extern	sys_compat_fork_parent_dump

#define SYS_COMPAT_MARK_NR	0x1337

sys_compat_lstar:
	cmp	rax, SYS_COMPAT_MARK_NR
	je	.Lmark

	/* SYSCALL leaves user GS + user RSP. After fork that stack is
	 * COW-RO; a push here #PFs in kernel (PRE reset, no W).
	 * Official LSTAR: swapgs, save RSP at arch_thread.user_rsp
	 * (gs:16), RSP = syscall_rsp (gs:8). Then restore before
	 * jmp LSTAR so official swapgs is still correct. */
	swapgs
	mov	qword ptr [gs:16], rsp
	mov	rsp, qword ptr [gs:8]
	push	rax
	cmp	qword ptr [rip + gLinuxCR3], 0
	je	.Lhaiku
	push	r8
	push	r9
	mov	rax, cr3
	and	rax, 0xfffffffffffff000	/* drop PCID */
	lea	r9, [rip + gLinuxCR3]
	xor	r8, r8
.Lcr3scan:
	cmp	rax, [r9 + r8 * 8]
	je	.Llinux
	inc	r8
	cmp	r8, 8
	jb	.Lcr3scan
	/* Unmarked CR3 after Linux fork: stamp on *any* syscall.
	 * Linux 4 (stat) is Haiku _kern_shutdown(rdi≠0) → real reboot.
	 * Linux 1 (write) is _kern_generic_syscall → Kill Thread.
	 * Linux 60 (exit) is _kern_cancel_thread. Never identity-pass. */
	cmp	qword ptr [rip + gForkPending], 0
	je	.Lhaiku_slow
	jmp	.Lstamp_child
.Lstamp_child:
	lea	r9, [rip + gLinuxCR3]
	xor	r8, r8
.Lstamp_scan:
	cmp	qword ptr [r9 + r8 * 8], 0
	je	.Lstamp_got
	inc	r8
	cmp	r8, 8
	jb	.Lstamp_scan
	jmp	.Lstamp_done
.Lstamp_got:
	mov	[r9 + r8 * 8], rax
	inc	qword ptr [rip + gLinuxN]
	mov	qword ptr [rip + gForkPending], 0
	/* Still on gs:8. Do not KSER after restoring the user stack. */
	KSER	'S'
.Lstamp_done:
	pop	r9
	pop	r8
	pop	rax
	/* Child first syscall during _user_fork. Parent is still on
	 * gKstack in try_fork — do not CALL_C. Only exit/write.
	 * Never use 1f/2f next to KSER (macro owns those labels). */
	cmp	rax, 60
	je	.Lexit
	cmp	rax, 231
	je	.Lexit
	cmp	rax, 1
	je	.Lwrite
	mov	[rip + gLastLinuxRax], rax
	KSER	'X'
	mov	[rip + gTmpR8], rdx
	mov	dx, 0x3f8
	mov	rax, [rip + gLastLinuxRax]
	shr	al, 4
	and	al, 0xf
	add	al, '0'
	cmp	al, '9'
	jbe	.Lsthex1
	add	al, 7
.Lsthex1:
	out	dx, al
	mov	rax, [rip + gLastLinuxRax]
	and	al, 0xf
	add	al, '0'
	cmp	al, '9'
	jbe	.Lsthex2
	add	al, 7
.Lsthex2:
	out	dx, al
	mov	rdx, [rip + gTmpR8]
	mov	rax, -38
	jmp	.Lret
.Lhaiku_slow:
	pop	r9
	pop	r8
.Lhaiku:
	pop	rax
	mov	rsp, qword ptr [gs:16]
	swapgs
	jmp	[rip + gOrigLstar]

.Lmark:
	/* Still on the user stack, user GS. Do not swapgs.
	 * rdi = optional arena base, rsi = size (0 = no arena),
	 * rdx = optional fork IRETQ trampoline (user page).
	 */
	KSER	'M'
	mov	qword ptr [rip + gForkTramp], rdx
	mov	qword ptr [rip + gForkHaikuRsp], r8
	xor	r8, r8
.Lmark_clr:
	lea	r9, [rip + gLinuxCR3]
	mov	qword ptr [r9 + r8 * 8], 0
	lea	r9, [rip + gLinuxTeam]
	mov	qword ptr [r9 + r8 * 8], 0
	inc	r8
	cmp	r8, 8
	jb	.Lmark_clr
	mov	rax, cr3
	and	rax, 0xfffffffffffff000
	mov	[rip + gLinuxCR3], rax
	mov	qword ptr [rip + gLinuxN], 1
	mov	qword ptr [rip + gForkPending], 0
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
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	swapgs
	mov	[rip + gSavedRsp], rsp
	lea	rsp, [rip + gKstackEnd]
	and	rsp, -16
	sti
	call	sys_compat_mark_team
	cli
	mov	rsp, [rip + gSavedRsp]
	swapgs
	KSER	'm'
	pop	r10
	pop	r9
	pop	r8
	pop	rdx
	pop	rsi
	pop	rdi
	pop	r11
	pop	rcx
	xor	rax, rax
	KSER	'Q'
	sysretq

.Llinux:
	pop	r9
	pop	r8
	pop	rax
	/* Stay on gs:8 / kernel GS. Post-fork user stack is COW-RO. */
.Llinux_go:
	inc	qword ptr [rip + gLinuxHits]
	mov	[rip + gLastLinuxRax], rax
	/* After fork the user stack is COW-RO. Do not push here. */
	mov	[rip + gTmpR8], r8
	mov	[rip + gTmpR9], r9
	lea	r9, [rip + gLastN]
	mov	r8, [rip + gLastNidx]
	and	r8, 7
	mov	[r9 + r8 * 8], rax
	inc	qword ptr [rip + gLastNidx]
	mov	r8, [rip + gTmpR8]
	mov	r9, [rip + gTmpR9]

	cmp	rax, 0			/* Linux read */
	je	.Lread
	cmp	rax, 1			/* Linux write */
	je	.Lwrite
	cmp	rax, 2			/* Linux open */
	je	.Lopen
	cmp	rax, 3			/* Linux close */
	je	.Lclose
	cmp	rax, 4			/* Linux stat */
	je	.Lstat
	cmp	rax, 5			/* Linux fstat */
	je	.Lfstat
	cmp	rax, 6			/* Linux lstat */
	je	.Llstat
	cmp	rax, 8			/* Linux lseek */
	je	.Llseek
	cmp	rax, 17			/* Linux pread64 */
	je	.Lpread64
	cmp	rax, 18			/* Linux pwrite64 */
	je	.Lpwrite64
	cmp	rax, 19			/* Linux writev */
	je	.Lwritev
	cmp	rax, 20			/* Linux readv */
	je	.Lreadv
	cmp	rax, 16			/* Linux ioctl */
	je	.Lenotty
	cmp	rax, 21			/* Linux access */
	je	.Laccess
	cmp	rax, 22			/* Linux pipe */
	je	.Lpipe
	cmp	rax, 35			/* Linux nanosleep */
	je	.Lnanosleep
	cmp	rax, 32			/* Linux dup */
	je	.Ldup
	cmp	rax, 33			/* Linux dup2 */
	je	.Ldup2
	cmp	rax, 72			/* Linux fcntl */
	je	.Lfcntl
	cmp	rax, 221		/* fadvise64 — hint, succeed */
	je	.Lok0
	cmp	rax, 332		/* statx */
	je	.Lstatx
	cmp	rax, 74			/* Linux fsync */
	je	.Lfsync
	cmp	rax, 75			/* Linux fdatasync */
	je	.Lfdatasync
	cmp	rax, 82			/* Linux rename */
	je	.Lrename
	cmp	rax, 86			/* Linux link */
	je	.Llink
	cmp	rax, 88			/* Linux symlink */
	je	.Lsymlink
	cmp	rax, 89			/* Linux readlink */
	je	.Lreadlink
	cmp	rax, 79			/* Linux getcwd */
	je	.Lgetcwd
	cmp	rax, 80			/* Linux chdir */
	je	.Lchdir
	cmp	rax, 81			/* Linux fchdir */
	je	.Lfchdir
	cmp	rax, 76			/* Linux truncate */
	je	.Ltruncate
	cmp	rax, 77			/* Linux ftruncate */
	je	.Lftruncate
	cmp	rax, 83			/* Linux mkdir */
	je	.Lmkdir
	cmp	rax, 84			/* Linux rmdir */
	je	.Lrmdir
	cmp	rax, 87			/* Linux unlink */
	je	.Lunlink
	cmp	rax, 90			/* chmod */
	je	.Lchmod
	cmp	rax, 91			/* fchmod */
	je	.Lfchmod
	cmp	rax, 92			/* chown */
	je	.Lchown
	cmp	rax, 93			/* fchown */
	je	.Lfchown
	cmp	rax, 94			/* lchown */
	je	.Llchown
	cmp	rax, 137		/* Linux statfs */
	je	.Lstatfs
	cmp	rax, 138		/* Linux fstatfs */
	je	.Lstatfs
	cmp	rax, 96			/* gettimeofday */
	je	.Lgettimeofday
	cmp	rax, 201		/* time */
	je	.Ltime
	cmp	rax, 228		/* Linux clock_gettime */
	je	.Lclock_gettime
	cmp	rax, 403		/* clock_gettime64 */
	je	.Lclock_gettime
	cmp	rax, 260		/* fchownat */
	je	.Lfchownat
	cmp	rax, 264		/* renameat */
	je	.Lrenameat
	cmp	rax, 265		/* linkat */
	je	.Llinkat
	cmp	rax, 266		/* symlinkat */
	je	.Lsymlinkat
	cmp	rax, 268		/* fchmodat */
	je	.Lfchmodat
	cmp	rax, 258		/* Linux mkdirat */
	je	.Lmkdirat
	cmp	rax, 263		/* Linux unlinkat */
	je	.Lunlinkat
	cmp	rax, 280		/* utimensat */
	je	.Lutimensat
	cmp	rax, 292		/* dup3 */
	je	.Ldup3
	cmp	rax, 316		/* renameat2 */
	je	.Lrenameat2
	cmp	rax, 9			/* Linux mmap */
	je	.Lmmap
	cmp	rax, 10			/* Linux mprotect */
	je	.Lmprotect
	cmp	rax, 11			/* Linux munmap */
	je	.Lmunmap
	cmp	rax, 12			/* Linux brk */
	je	.Lbrk
	cmp	rax, 39			/* Linux getpid */
	je	.Lgetpid
	cmp	rax, 110		/* getppid */
	je	.Lgetppid
	cmp	rax, 293		/* pipe2 */
	je	.Lpipe2
	cmp	rax, 56			/* Linux clone */
	jne	.Lnotclone
	KSER	'C'
	jmp	.Lclone
.Lnotclone:
	cmp	rax, 57			/* Linux fork */
	je	.Lfork
	cmp	rax, 58			/* Linux vfork */
	je	.Lfork
	cmp	rax, 61			/* Linux wait4 */
	je	.Lwait4
	cmp	rax, 102		/* getuid */
	je	.Lgetuid
	cmp	rax, 104		/* getgid */
	je	.Lgetgid
	cmp	rax, 105		/* setuid */
	je	.Lsetuid
	cmp	rax, 106		/* setgid */
	je	.Lsetgid
	cmp	rax, 107		/* geteuid */
	je	.Lgetuid
	cmp	rax, 108		/* getegid */
	je	.Lgetgid
	cmp	rax, 157		/* prctl */
	je	.Lprctl
	cmp	rax, 158		/* Linux arch_prctl */
	je	.Larch_prctl
	cmp	rax, 186		/* Linux gettid */
	je	.Lgettid
	cmp	rax, 218		/* Linux set_tid_address */
	je	.Lset_tid_address
	cmp	rax, 257		/* Linux openat */
	je	.Lopenat
	cmp	rax, 217		/* getdents64 */
	je	.Lgetdents
	cmp	rax, 262		/* newfstatat */
	je	.Lnewfstatat
	cmp	rax, 267		/* readlinkat */
	je	.Lreadlinkat
	cmp	rax, 273		/* Linux set_robust_list */
	je	.Lset_robust_list
	cmp	rax, 302		/* prlimit64 */
	je	.Lprlimit
	cmp	rax, 318		/* getrandom */
	je	.Lgetrandom
	cmp	rax, 334		/* Linux rseq — register in this layer */
	je	.Lrseq
	cmp	rax, 63			/* Linux uname */
	je	.Luname
	cmp	rax, 60			/* Linux exit */
	je	.Lexit
	cmp	rax, 231		/* Linux exit_group */
	je	.Lexit
	cmp	rax, 13			/* rt_sigaction — glibc installs and ignores */
	je	.Lok0
	cmp	rax, 14			/* rt_sigprocmask */
	je	.Lok0
	cmp	rax, 230		/* clock_nanosleep */
	je	.Lclock_nanosleep
	cmp	rax, 269		/* faccessat */
	je	.Lfaccessat
	cmp	rax, 169		/* Linux reboot — never identity-pass */
	je	.Lenosys
	cmp	rax, 7			/* poll */
	je	.Lenosys
	cmp	rax, 23			/* select */
	je	.Lenosys
	cmp	rax, 270		/* pselect6 */
	je	.Lenosys
	cmp	rax, 271		/* ppoll */
	je	.Lenosys
	cmp	rax, 202		/* futex */
	je	.Lenosys
	cmp	rax, 59			/* execve */
	je	.Lenosys
	cmp	rax, 25			/* mremap */
	je	.Lenosys
	cmp	rax, 15			/* rt_sigreturn */
	je	.Lenosys

	/* Marked CR3: every other Linux number is -ENOSYS.
	 * Never jmp original LSTAR with a Linux rax (Haiku 4 = shutdown). */
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
	jmp	.Llstar

.Lwrite:
	/* Linux: rdi=fd rsi=buf rdx=count
	 * Haiku _kern_write: rdi=fd rsi=pos rdx=buf rcx/r10=count
	 * Already on gs:8 / kernel GS.
	 */
	KSER	'W'
	mov	r10, rdx
	mov	rdx, rsi
	mov	rsi, -1
	mov	rax, 0x97
	jmp	.Llstar

.Lpread64:
	/* Linux: rdi=fd rsi=buf rdx=count r10=offset
	 * Haiku read: rdi=fd rsi=pos rdx=buf r10=count
	 */
	mov	rax, r10
	mov	r10, rdx
	mov	rdx, rsi
	mov	rsi, rax
	mov	rax, 0x95
	jmp	.Llstar

.Lpwrite64:
	mov	rax, r10
	mov	r10, rdx
	mov	rdx, rsi
	mov	rsi, rax
	mov	rax, 0x97
	jmp	.Llstar

.Lreadv:
	/* Linux: rdi=fd rsi=iov rdx=iovcnt → Haiku readv(fd, pos=-1, iov, n) */
	mov	r10, rdx
	mov	rdx, rsi
	mov	rsi, -1
	mov	rax, 0x96
	jmp	.Llstar

.Lwritev:
	mov	r10, rdx
	mov	rdx, rsi
	mov	rsi, -1
	mov	rax, 0x98
	jmp	.Llstar

.Lclose:
	/* Linux: rdi=fd  Haiku _kern_close: rdi=fd  (0x9e) */
	mov	rax, 0x9e
	jmp	.Llstar

.Llseek:
	/* Linux lseek(fd,off,whence) == Haiku _kern_seek. SEEK_*=0/1/2. */
	mov	rax, 0x79
	jmp	.Llstar

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
	 * Directories must use _kern_open_dir (0x74) or read_dir is B_UNSUPPORTED.
	 */
	test	rsi, 0x10000		/* LINUX O_DIRECTORY */
	jnz	.Lopen_dir_cwd
	mov	r10, rdx
	mov	rdx, rsi
	XLAT_OFLAGS
	mov	rsi, rdi
	mov	rdi, -100
	mov	rax, 0x72
	jmp	.Llstar
.Lopen_dir_cwd:
	mov	rsi, rdi
	mov	rdi, -100
	mov	rax, 0x74		/* _kern_open_dir */
	jmp	.Llstar

.Lopenat:
	/* Linux: rdi=dirfd rsi=path rdx=flags r10=mode — same layout */
	test	rdx, 0x10000		/* LINUX O_DIRECTORY */
	jnz	.Lopenat_dir
	XLAT_OFLAGS
	mov	rax, 0x72
	jmp	.Llstar
.Lopenat_dir:
	mov	rax, 0x74		/* _kern_open_dir(dirfd, path) */
	jmp	.Llstar

.Lexit:
	KSER	'e'
	/* Drop this CR3 only. A live child must stay marked. */
	push	r8
	push	r9
	mov	rax, cr3
	and	rax, 0xfffffffffffff000
	lea	r9, [rip + gLinuxCR3]
	xor	r8, r8
.Lexit_scan:
	cmp	rax, [r9 + r8 * 8]
	jne	1f
	mov	qword ptr [r9 + r8 * 8], 0
	lea	r9, [rip + gLinuxTeam]
	mov	qword ptr [r9 + r8 * 8], 0
	cmp	qword ptr [rip + gLinuxN], 0
	je	2f
	dec	qword ptr [rip + gLinuxN]
	jmp	2f
1:
	inc	r8
	cmp	r8, 8
	jb	.Lexit_scan
2:
	pop	r9
	pop	r8
	mov	qword ptr [rip + gLinuxFS], 0
	mov	qword ptr [rip + gRseqPtr], 0
	mov	qword ptr [rip + gRseqLen], 0
	mov	qword ptr [rip + gRseqSig], 0
	mov	rax, 0x29
	KSER	'E'
	jmp	.Llstar

.Lok0:
	xor	rax, rax
	jmp	.Lret

.Lget1:
	/* gettid/set_tid_address: fake tid 1 is enough for single-thread. */
	mov	rax, 1
	jmp	.Lret

.Lgetpid:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	mov	[rip + gSavedRsp], rsp
	lea	rsp, [rip + gKstackEnd]
	and	rsp, -16
	sti
	call	sys_compat_getpid
	cli
	mov	rsp, [rip + gSavedRsp]
	pop	r10
	pop	r9
	pop	r8
	pop	rdx
	pop	rsi
	pop	rdi
	pop	r11
	pop	rcx
	jmp	.Lret

.Lfork:
	/* Diagnose: call _user_fork from C (see .Lclone). */
	jmp	.Ltry_fork

.Lclone:
	/* Fork-style only: stack==NULL, no CLONE_VM / CLONE_THREAD. */
	test	rsi, rsi
	jnz	.Lenosys
	test	rdi, 0x100		/* CLONE_VM */
	jnz	.Lenosys
	test	rdi, 0x10000		/* CLONE_THREAD */
	jnz	.Lenosys
.Ltry_fork:
	/* Plant iframe + _user_fork. Parent SYSRET must match official
	 * x86_64_syscall_entry: rcx=RIP, r11=RFLAGS, rsp=user, swapgs,
	 * sysretq. COM1 showed the old path Double Faulted at
	 * sys_compat_lstar+0xa63 with RSP already on the Linux user
	 * stack and rcx=0x23 (USER_SS) — leftover from C, pops never
	 * finished. Do not push the SYSCALL frame onto the user stack,
	 * do not pop it back from there, and do not walk .Lret (rseq
	 * write) after the stack switch. */
	KSER	'1'
	mov	qword ptr [rip + gForkPending], 1
	mov	qword ptr [rip + gForkUserRip], rcx
	mov	rax, qword ptr [gs:16]
	mov	qword ptr [rip + gForkUserRsp], rax
	mov	qword ptr [rip + gForkUserFlags], r11
	mov	rdi, rcx
	mov	rsi, rax
	mov	rdx, r11
	/* Already kernel GS / gs:8. Do not swapgs. */
	KSER	'2'
	/* C on gKstack, iframe on the real kstack. Running try_fork
	 * on gs:8 left its frame 64 bytes below the iframe; _user_fork
	 * smashed the return address (syslog: parent return, then
	 * reset, never KSER 6). Must set RBP: -O3 spills -0x38(%rbp)
	 * and leftover user RBP=0x10 #PF'd at 0xffffffffffffffd8. */
	lea	rsp, [rip + gKstackEnd]
	and	rsp, -16
	mov	rbp, rsp
	/* No STI here. Official SYSCALL enables interrupts only after
	 * RBP is the iframe on the real kstack. STI on gKstack jumped
	 * to 0x19e1e78c0bc during F4. try_fork STIs around _user_fork. */
	KSER	'3'
	call	sys_compat_try_fork
	KSER	'6'
	cli
	mov	rdi, [rip + gForkUserRip]
	mov	rsi, [rip + gForkUserRsp]
	mov	rdx, [rip + gForkUserFlags]
	mov	rcx, rax
	push	rax
	call	sys_compat_fork_parent_dump
	pop	rax
	KSER	'7'
	/* Park after 9 kept the guest up: child IRETQ is not the
	 * reboot. Parent SYSRET (mov rsp,user; swapgs; sysretq)
	 * Double Faulted — kernel code on the Linux stack. IRETQ
	 * loads user RSP from the frame so we never do that. */
	KSER	'Y'
	/* 5-push IRETQ to tramp+64. Stub is COM1 'U' then eb fe —
	 * no SYSCALL. RFLAGS=0x3202 (IF|IOPL=3) so CPL3 OUT works.
	 * COM1 'U' after Z => user mode ran. Silence after Z =>
	 * IRETQ itself triple-faulted (matches empty previous_syslog). */
	push	0x23
	mov	rdx, [rip + gForkHaikuRsp]
	test	rdx, rdx
	jnz	.Lprsp
	mov	rdx, [rip + gForkUserRsp]
.Lprsp:
	push	rdx
	push	0x3202
	push	0x2b
	mov	rdx, [rip + gForkTramp]
	test	rdx, rdx
	jz	.Lprip_user
	add	rdx, 64			/* UART stub; +0 is child eb fe */
	jmp	.Lprip
.Lprip_user:
	mov	rdx, [rip + gForkUserRip]
.Lprip:
	push	rdx
	KSER	'Z'
	swapgs
	iretq

.Lwait4:
	/* rdi=pid rsi=status rdx=options r10=rusage.
	 * Info scratch is below the user RSP (Haiku writes it via
	 * user_memcpy). Do not push on that COW-RO stack.
	 * rcx/r11 are SYSCALL RIP/RFLAGS — must survive to sysretq. */
	KSER	'V'
	push	rcx
	push	r11
	mov	r8, qword ptr [gs:16]
	sub	r8, 256
	mov	rcx, r10
	mov	[rip + gSavedRsp], rsp
	lea	rsp, [rip + gKstackEnd]
	and	rsp, -16
	sti
	call	sys_compat_wait4
	cli
	mov	rsp, [rip + gSavedRsp]
	pop	r11
	pop	rcx
	KSER	'v'
	jmp	.Lret

	/* Direct `call` is PLT-safe. `lea r11, [rip+fn]` is R_X86_64_PC32
	 * and the Haiku DRIVER link rejects it (-fPIC / shared object). */
.macro CALL_C fn
	mov	[rip + gSavedRsp], rsp
	lea	rsp, [rip + gKstackEnd]
	and	rsp, -16
	sti
	call	\fn
	cli
	mov	rsp, [rip + gSavedRsp]
	pop	r10
	pop	r9
	pop	r8
	pop	rdx
	pop	rsi
	pop	rdi
	pop	r11
	pop	rcx
	jmp	.Lret
.endm

.Lchmod:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	mov	r8, rsi
	xor	r9, r9
	xor	rdx, rdx
	mov	rcx, 1
	mov	rsi, rdi
	mov	rdi, -100
	CALL_C	sys_compat_wstat
.Lfchmod:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	mov	r8, rsi
	xor	r9, r9
	xor	rdx, rdx
	mov	rcx, 1
	xor	rsi, rsi
	CALL_C	sys_compat_wstat
.Lfchmodat:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	mov	r8, rdx
	mov	rdx, r10
	mov	rcx, 1
	xor	r9, r9
	CALL_C	sys_compat_wstat
.Lchown:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	mov	r8, rsi
	mov	r9, rdx
	xor	ecx, ecx
	cmp	r8d, 0xffffffff
	je	1f
	or	ecx, 2
1:
	cmp	r9d, 0xffffffff
	je	2f
	or	ecx, 4
2:
	xor	rdx, rdx
	mov	rsi, rdi
	mov	rdi, -100
	CALL_C	sys_compat_wstat
.Lfchown:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	mov	r8, rsi
	mov	r9, rdx
	xor	ecx, ecx
	cmp	r8d, 0xffffffff
	je	1f
	or	ecx, 2
1:
	cmp	r9d, 0xffffffff
	je	2f
	or	ecx, 4
2:
	xor	rdx, rdx
	xor	rsi, rsi
	CALL_C	sys_compat_wstat
.Llchown:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	mov	r8, rsi
	mov	r9, rdx
	xor	ecx, ecx
	cmp	r8d, 0xffffffff
	je	1f
	or	ecx, 2
1:
	cmp	r9d, 0xffffffff
	je	2f
	or	ecx, 4
2:
	mov	rdx, 0x100
	mov	rsi, rdi
	mov	rdi, -100
	CALL_C	sys_compat_wstat
.Lfchownat:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	/* Linux fchownat(dirfd,path,uid,gid,flags):
	 * rdi=dirfd rsi=path rdx=uid r10=gid r8=flags
	 * After the 8 pushes: [rsp]=r10 [rsp+8]=r9 [rsp+16]=r8
	 * SysV wstat(fd,path,flags,mask,uid,gid). */
	mov	r9, r10			/* gid */
	mov	r8, rdx			/* uid */
	mov	rdx, [rsp + 16]		/* saved Linux r8 = flags */
	xor	ecx, ecx
	cmp	r8d, 0xffffffff
	je	1f
	or	ecx, 2
1:
	cmp	r9d, 0xffffffff
	je	2f
	or	ecx, 4
2:
	CALL_C	sys_compat_wstat
.Ltruncate:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	mov	r8, rsi
	xor	r9, r9
	xor	rdx, rdx
	mov	rcx, 8
	mov	rsi, rdi
	mov	rdi, -100
	CALL_C	sys_compat_wstat
.Lftruncate:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	mov	r8, rsi
	xor	r9, r9
	xor	rdx, rdx
	mov	rcx, 8
	xor	rsi, rsi
	CALL_C	sys_compat_wstat
.Lmprotect:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	CALL_C	sys_compat_mprotect
.Lmunmap:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	CALL_C	sys_compat_munmap
.Lgetuid:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	CALL_C	sys_compat_getuid
.Lgetgid:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	CALL_C	sys_compat_getgid
.Lsetuid:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	CALL_C	sys_compat_setuid
.Lsetgid:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	CALL_C	sys_compat_setgid
.Lgettid:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	CALL_C	sys_compat_gettid
.Lset_tid_address:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	CALL_C	sys_compat_set_tid_address
.Lset_robust_list:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	CALL_C	sys_compat_set_robust_list
.Lprctl:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	mov	rcx, r10
	CALL_C	sys_compat_prctl

.Lrename:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	mov	rcx, rsi
	mov	rsi, rdi
	mov	rdi, -100
	mov	rdx, -100
	CALL_C	sys_compat_rename
.Lrenameat:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	mov	rcx, r10
	CALL_C	sys_compat_rename
.Lrenameat2:
	test	r8, r8
	jnz	.Leinval
	jmp	.Lrenameat
.Lsymlink:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	/* Linux symlink(target, linkpath) → C(AT_FDCWD, linkpath, target) */
	mov	rdx, rdi
	mov	rdi, -100
	CALL_C	sys_compat_symlink
.Lsymlinkat:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	/* Linux symlinkat(target, dirfd, linkpath) → C(dirfd, linkpath, target) */
	mov	rax, rdi
	mov	rdi, rsi
	mov	rsi, rdx
	mov	rdx, rax
	CALL_C	sys_compat_symlink
.Llink:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	mov	rcx, rsi
	mov	rsi, rdi
	mov	rdi, -100
	mov	rdx, -100
	xor	r8, r8
	CALL_C	sys_compat_link
.Llinkat:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	mov	rcx, r10
	CALL_C	sys_compat_link
.Lreadlink:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	mov	rcx, rdx
	mov	rdx, rsi
	mov	rsi, rdi
	mov	rdi, -100
	CALL_C	sys_compat_readlink
.Lreadlinkat:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	mov	rcx, r10
	CALL_C	sys_compat_readlink
.Ldup:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	CALL_C	sys_compat_dup
.Ldup2:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	xor	rdx, rdx
	CALL_C	sys_compat_dup2
.Ldup3:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	CALL_C	sys_compat_dup2
.Lfsync:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	xor	rsi, rsi
	CALL_C	sys_compat_fsync
.Lfdatasync:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	mov	rsi, 1
	CALL_C	sys_compat_fsync
.Lclock_gettime:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	CALL_C	sys_compat_clock_gettime
.Lutimensat:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	mov	rcx, r10
	CALL_C	sys_compat_utimensat
.Ltime:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	CALL_C	sys_compat_time
.Lgettimeofday:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	CALL_C	sys_compat_gettimeofday
.Lgetppid:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	CALL_C	sys_compat_getppid
.Lpipe:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	xor	rsi, rsi
	CALL_C	sys_compat_pipe2
.Lpipe2:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	CALL_C	sys_compat_pipe2
.Lclock_nanosleep:
	/* rdi=clockid rsi=flags rdx=req r10=rem → nanosleep(req, rem) */
	mov	rdi, rdx
	mov	rsi, r10
.Lnanosleep:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	CALL_C	sys_compat_nanosleep
.Lfcntl:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	CALL_C	sys_compat_fcntl
.Lstatx:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	mov	rcx, r10
	CALL_C	sys_compat_statx

.Lget0:
	xor	rax, rax
	jmp	.Lret

.Lenoent:
	mov	rax, -2			/* -ENOENT */
	jmp	.Lret
.Lenotty:
	mov	rax, -25		/* -ENOTTY */
	jmp	.Lret

.Lstat:
	/* Linux: rdi=path rsi=statbuf → C(AT_FDCWD, path, statbuf, 0) */
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	mov	rdx, rsi
	mov	rsi, rdi
	mov	rdi, -100
	xor	r10, r10
	jmp	.Lstat_go
.Llstat:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	mov	rdx, rsi
	mov	rsi, rdi
	mov	rdi, -100
	mov	r10, 0x100
	jmp	.Lstat_go
.Lfstat:
	/* Linux: rdi=fd rsi=statbuf → C(fd, NULL, statbuf, 0) */
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	mov	rdx, rsi
	xor	rsi, rsi
	xor	r10, r10
	jmp	.Lstat_go
.Lnewfstatat:
	/* Linux: rdi=dirfd rsi=path rdx=statbuf r10=flags
	 * C ABI 4th arg is rcx. Call C on the private stack like getdents.
	 */
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
.Lstat_go:
	mov	[rip + gSavedRsp], rsp
	lea	rsp, [rip + gKstackEnd]
	and	rsp, -16
	mov	rcx, r10
	sti
	call	sys_compat_stat
	cli
	mov	rsp, [rip + gSavedRsp]
	pop	r10
	pop	r9
	pop	r8
	pop	rdx
	pop	rsi
	pop	rdi
	pop	r11
	pop	rcx
	jmp	.Lret

.Lmkdir:
	/* Linux: rdi=path rsi=mode → C(AT_FDCWD, path, mode) */
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	mov	rdx, rsi
	mov	rsi, rdi
	mov	rdi, -100
	jmp	.Lmkdir_go
.Lmkdirat:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
.Lmkdir_go:
	mov	[rip + gSavedRsp], rsp
	lea	rsp, [rip + gKstackEnd]
	and	rsp, -16
	sti
	call	sys_compat_mkdir
	cli
	mov	rsp, [rip + gSavedRsp]
	pop	r10
	pop	r9
	pop	r8
	pop	rdx
	pop	rsi
	pop	rdi
	pop	r11
	pop	rcx
	jmp	.Lret

.Lunlink:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	mov	rsi, rdi
	mov	rdi, -100
	xor	rdx, rdx
	jmp	.Lunlink_go
.Lrmdir:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	mov	rsi, rdi
	mov	rdi, -100
	mov	rdx, 0x200		/* AT_REMOVEDIR */
	jmp	.Lunlink_go
.Lunlinkat:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
.Lunlink_go:
	mov	[rip + gSavedRsp], rsp
	lea	rsp, [rip + gKstackEnd]
	and	rsp, -16
	sti
	call	sys_compat_unlink
	cli
	mov	rsp, [rip + gSavedRsp]
	pop	r10
	pop	r9
	pop	r8
	pop	rdx
	pop	rsi
	pop	rdi
	pop	r11
	pop	rcx
	jmp	.Lret

.Lfaccessat:
	/* rdi=dirfd rsi=path rdx=mode — ignore dirfd/flags. */
	mov	rdi, rsi
	mov	rsi, rdx
.Laccess:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	mov	rdx, rsi
	mov	rsi, rdi
	mov	rdi, -100
	mov	[rip + gSavedRsp], rsp
	lea	rsp, [rip + gKstackEnd]
	and	rsp, -16
	sti
	call	sys_compat_access
	cli
	mov	rsp, [rip + gSavedRsp]
	pop	r10
	pop	r9
	pop	r8
	pop	rdx
	pop	rsi
	pop	rdi
	pop	r11
	pop	rcx
	jmp	.Lret

.Lgetcwd:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	mov	[rip + gSavedRsp], rsp
	lea	rsp, [rip + gKstackEnd]
	and	rsp, -16
	sti
	call	sys_compat_getcwd
	cli
	mov	rsp, [rip + gSavedRsp]
	pop	r10
	pop	r9
	pop	r8
	pop	rdx
	pop	rsi
	pop	rdi
	pop	r11
	pop	rcx
	jmp	.Lret

.Lchdir:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	mov	rsi, rdi
	mov	rdi, -100
	jmp	.Lchdir_go
.Lfchdir:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	xor	rsi, rsi
.Lchdir_go:
	mov	[rip + gSavedRsp], rsp
	lea	rsp, [rip + gKstackEnd]
	and	rsp, -16
	sti
	call	sys_compat_chdir
	cli
	mov	rsp, [rip + gSavedRsp]
	pop	r10
	pop	r9
	pop	r8
	pop	rdx
	pop	rsi
	pop	rdi
	pop	r11
	pop	rcx
	jmp	.Lret

.Lstatfs:
	/* Linux: rdi=path/fd rsi=struct statfs*. Fake ext4. */
	test	rsi, rsi
	jz	.Lefault
	swapgs
	xor	eax, eax
1:
	mov	byte ptr [rsi + rax], 0
	inc	rax
	cmp	rax, 120
	jb	1b
	mov	qword ptr [rsi], 0xEF53		/* EXT4_SUPER_MAGIC */
	mov	qword ptr [rsi + 8], 4096	/* f_bsize */
	mov	qword ptr [rsi + 16], 100000	/* f_blocks */
	mov	qword ptr [rsi + 24], 50000	/* f_bfree */
	mov	qword ptr [rsi + 32], 50000	/* f_bavail */
	mov	qword ptr [rsi + 64], 255	/* f_namelen */
	mov	qword ptr [rsi + 72], 4096	/* f_frsize */
	swapgs
	xor	rax, rax
	jmp	.Lret

.Lgetdents:
	/* rdi=fd rsi=buf rdx=count. Call C on a private stack. IF is clear. */
	push	rcx
	push	r11
	mov	[rip + gSavedRsp], rsp
	lea	rsp, [rip + gKstackEnd]
	and	rsp, -16
	sti
	call	sys_compat_getdents64
	cli
	mov	rsp, [rip + gSavedRsp]
	pop	r11
	pop	rcx
	jmp	.Lret

	/*
	 * Linux uname(struct utsname *). Each field is 65 bytes.
	 * No STAC: this Haiku does not set CR4.SMAP.
	 */
.Luname:
	test	rdi, rdi
	jz	.Lefault
	swapgs
	xor	eax, eax
.Luname_z:
	mov	byte ptr [rdi + rax], 0
	inc	rax
	cmp	rax, 390
	jb	.Luname_z
	mov	byte ptr [rdi + 0], 'L'
	mov	byte ptr [rdi + 1], 'i'
	mov	byte ptr [rdi + 2], 'n'
	mov	byte ptr [rdi + 3], 'u'
	mov	byte ptr [rdi + 4], 'x'
	mov	byte ptr [rdi + 65], 'h'
	mov	byte ptr [rdi + 66], 'a'
	mov	byte ptr [rdi + 67], 'i'
	mov	byte ptr [rdi + 68], 'k'
	mov	byte ptr [rdi + 69], 'u'
	mov	byte ptr [rdi + 130], '6'
	mov	byte ptr [rdi + 131], '.'
	mov	byte ptr [rdi + 132], '1'
	mov	byte ptr [rdi + 133], '.'
	mov	byte ptr [rdi + 134], '0'
	mov	byte ptr [rdi + 195], 's'
	mov	byte ptr [rdi + 196], 'y'
	mov	byte ptr [rdi + 197], 's'
	mov	byte ptr [rdi + 198], '_'
	mov	byte ptr [rdi + 199], 'c'
	mov	byte ptr [rdi + 200], 'o'
	mov	byte ptr [rdi + 201], 'm'
	mov	byte ptr [rdi + 202], 'p'
	mov	byte ptr [rdi + 203], 'a'
	mov	byte ptr [rdi + 204], 't'
	mov	byte ptr [rdi + 260], 'x'
	mov	byte ptr [rdi + 261], '8'
	mov	byte ptr [rdi + 262], '6'
	mov	byte ptr [rdi + 263], '_'
	mov	byte ptr [rdi + 264], '6'
	mov	byte ptr [rdi + 265], '4'
	swapgs
	xor	rax, rax
	jmp	.Lret

.Lprlimit:
	/* rdi=pid rsi=resource rdx=new r10=old. Fill old with 8MB/∞. */
	test	r10, r10
	jz	.Lok0
	swapgs
	mov	qword ptr [r10], 0x800000
	mov	qword ptr [r10 + 8], -1
	swapgs
	xor	rax, rax
	jmp	.Lret

.Lgetrandom:
	/* rdi=buf rsi=len — write up to 8 bytes from rdtsc, return len. */
	test	rdi, rdi
	jz	.Lnomem
	test	rsi, rsi
	jz	.Lok0
	rdtsc
	swapgs
	mov	[rdi], eax
	cmp	rsi, 4
	jbe	1f
	mov	[rdi + 4], edx
1:
	swapgs
	mov	rax, rsi
	cmp	rax, 8
	jbe	.Lret
	mov	rax, 8
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
	/* Already kernel GS. rcx/r11 saved by caller. */
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
	/* User GS here. swapgs so a #PF is a thread kill, not a double fault.
	 * Do not STAC/CLAC: this Haiku image does not set CR4.SMAP, so
	 * STAC is #UD and takes the kernel down. */
	swapgs
	mov	qword ptr [rdi + 8], 0	/* rseq_cs = NULL */
	mov	dword ptr [rdi + 16], 0	/* flags */
	mov	dword ptr [rdi], 0	/* cpu_id_start = 0 */
	mov	dword ptr [rdi + 4], 0	/* cpu_id = 0 */
	cmp	rsi, 28
	jb	1f
	mov	dword ptr [rdi + 20], 0	/* node_id */
	mov	dword ptr [rdi + 24], 0	/* mm_cid */
1:
	swapgs
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
	swapgs
	mov	dword ptr [rdi], 0		/* cpu_id_start = 0 */
	mov	dword ptr [rdi + 4], -1		/* UNINITIALIZED */
	swapgs
	mov	qword ptr [rip + gRseqPtr], 0
	mov	qword ptr [rip + gRseqLen], 0
	mov	qword ptr [rip + gRseqSig], 0
	xor	rax, rax
	jmp	.Lret

.Lret:
	/* Keep registered cpu_id fields at 0 on every stub sysret.
	 * Preserve rax (return) and all userspace regs except rcx/r11.
	 * Entered on gs:8 / kernel GS.
	 */
	cmp	qword ptr [rip + gRseqPtr], 0
	je	.Lsysret
	push	rax
	push	rdi
	mov	rdi, [rip + gRseqPtr]
	mov	dword ptr [rdi], 0
	mov	dword ptr [rdi + 4], 0
	pop	rdi
	pop	rax
.Lsysret:
	mov	rsp, qword ptr [gs:16]
	swapgs
	sysretq

.Llstar:
	mov	rsp, qword ptr [gs:16]
	swapgs
	jmp	[rip + gOrigLstar]

	.bss
	.align	8
gOrigLstar:
	.quad	0
gLinuxCR3:
	.quad	0, 0, 0, 0, 0, 0, 0, 0
gLinuxTeam:
	.quad	0, 0, 0, 0, 0, 0, 0, 0
gLinuxN:
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
gSavedRsp:
	.quad	0
gTmpR8:
	.quad	0
gTmpR9:
	.quad	0
gForkPending:
	.quad	0
gForkTramp:
	.quad	0
gForkHaikuRsp:
	.quad	0
gForkUserRip:
	.quad	0
gForkUserRsp:
	.quad	0
gForkUserFlags:
	.quad	0
	.align	16
gKstack:
	.space	32768
gKstackEnd:
