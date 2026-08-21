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
	.globl	gForkUserRbp
	.globl	gForkChildTid
	.globl	gForkRbx
	.globl	gForkR12
	.globl	gForkR13
	.globl	gForkR14
	.globl	gForkR15
	.globl	gForkRetAddr
	.globl	gMarkExe
	.globl	gForkFS
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
	.hidden	gForkUserRbp
	.hidden	gForkChildTid
	.hidden	gForkRbx
	.hidden	gForkR12
	.hidden	gForkR13
	.hidden	gForkR14
	.hidden	gForkR15
	.hidden	gForkRetAddr
	.hidden	gMarkExe
	.hidden	gForkFS

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
	.extern	sys_compat_execve
	.extern	sys_compat_futex
	.extern	sys_compat_poll
	.extern	sys_compat_ppoll
	.extern	sys_compat_select
	.extern	sys_compat_pselect
	.extern	sys_compat_mmap
	.extern	sys_compat_sendfile
	.extern	sys_compat_open
	.extern	sys_compat_wstat
	.extern	sys_compat_mprotect
	.extern	sys_compat_munmap
	.extern	sys_compat_close
	.extern	sys_compat_write
	.extern	sys_compat_exit_team
	.extern	sys_compat_getgroups
	.extern	sys_compat_sched_getaffinity
	.extern	sys_compat_getuid
	.extern	sys_compat_getgid
	.extern	sys_compat_setuid
	.extern	sys_compat_setgid
	.extern	sys_compat_gettid
	.extern	sys_compat_set_tid_address
	.extern	sys_compat_set_robust_list
	.extern	sys_compat_get_robust_list
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
	.extern	sys_compat_ioctl
	.extern	sys_compat_statx
	.extern	sys_compat_try_fork
	.extern	sys_compat_clone_vm
	.extern	sys_compat_exit_prep
	.extern	sys_compat_fork_parent_dump
	.globl	sChildDone
	.hidden	sChildDone
	.globl	sExitCloses
	.hidden	sExitCloses
	.globl	sExitR14
	.hidden	sExitR14
	.globl	sRobustList
	.hidden	sRobustList
	.globl	sRobustLen
	.hidden	sRobustLen
	.globl	sWstatScratch
	.hidden	sWstatScratch
	.globl	gPollSnap
	.hidden	gPollSnap
	.globl	sPollWrote
	.hidden	sPollWrote
	.extern	sys_compat_exit_prep

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
	/* Only stamp if this SYSCALL came from the Linux ELF or the
	 * fork tramp page. gForkPending is global: a Haiku thread on
	 * another CPU must not be adopted (that was SX during F2).
	 * Do not KSER on the miss — Tracker/app_server flood COM1. */
	cmp	rcx, 0x400000
	jb	.Lstamp_trypage
	cmp	rcx, 0x1000000		/* static Linux ELF, not 4K hello_* */
	jb	.Lstamp_child
.Lstamp_trypage:
	/* rax is CR3 — do not clobber. r8/r9 already pushed. */
	mov	r8, rcx
	and	r8, 0xfffffffffffff000
	mov	r9, [rip + gForkTramp]
	and	r9, 0xfffffffffffff000
	cmp	r8, r9
	jne	.Lhaiku_slow
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
	lea	r9, [rip + gLinuxTeam]
	mov	qword ptr [r9 + r8 * 8], 1
	inc	qword ptr [rip + gLinuxN]
	mov	qword ptr [rip + gForkPending], 0
	/* Still on gs:8. Do not KSER after restoring the user stack. */
	KSER	'S'
.Lstamp_done:
	pop	r9
	pop	r8
	pop	rax
	/* Child IRETQ does not copy FS_BASE. busybox clone reads
	 * fs:0x10 before any other syscall. Prefer the FS_BASE
	 * snapshotted at clone (gForkFS) — glibc may use wrfsbase
	 * so gLinuxFS stays 0 and apply was skipped (5RS then #PF). */
	push	rax
	mov	rax, [rip + gLinuxFS]
	test	rax, rax
	jnz	.Lstamp_fs
	mov	rax, [rip + gForkFS]
	test	rax, rax
	jz	.Lstamp_nofs
	mov	[rip + gLinuxFS], rax
.Lstamp_fs:
	pop	rax
	push	rax
	push	rcx
	push	r11
	call	.Lapply_fs
	pop	r11
	pop	rcx
	pop	rax
	KSER	'F'
	jmp	.Llinux_go
.Lstamp_nofs:
	pop	rax
	KSER	'f'
	/* Parent already IRETQ'd. Dispatch this first child syscall
	 * like any marked team (dup2/close/execve, not just exit). */
	jmp	.Llinux_go
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
	mov	qword ptr [rip + gMarkExe], r9
	/* Add or refresh this CR3. Do not wipe other slots —
	 * exec's loader mark was unmarking the parent (Kill Thread). */
	mov	rax, cr3
	and	rax, 0xfffffffffffff000
	lea	r9, [rip + gLinuxCR3]
	xor	r8, r8
.Lmark_find:
	cmp	[r9 + r8 * 8], rax
	je	.Lmark_have
	inc	r8
	cmp	r8, 8
	jb	.Lmark_find
	xor	r8, r8
.Lmark_empty:
	cmp	qword ptr [r9 + r8 * 8], 0
	je	.Lmark_got
	inc	r8
	cmp	r8, 8
	jb	.Lmark_empty
	xor	r8, r8
.Lmark_got:
	mov	[r9 + r8 * 8], rax
	inc	qword ptr [rip + gLinuxN]
.Lmark_have:
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
	mov	dword ptr [rip + sExitCloses], 0
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
	/* Linux _start: rdx is rtld_fini. Do not return the fork
	 * tramp (xor-edi / SYS_exit 60) — glibc would call it on
	 * exit() and skip fflush. Tramp is already in gForkTramp. */
	xor	rdx, rdx
	KSER	'Q'
	sysretq

.Llinux:
	pop	r9
	pop	r8
	pop	rax
	/* Stay on gs:8 / kernel GS. Post-fork user stack is COW-RO. */
.Llinux_go:
	/* Snapshot callee-saved before any dispatch/C. clone plants
	 * these; do not store them in gFork* here — the child reuses
	 * this path during the parent hold and would smash the plant.
	 * Also push them on THIS thread's gs:8. Linux SYSCALL must
	 * keep rbx/rbp/r12-r15; glibc exit() parks the status in r14.
	 * Identity .Llstar abandons this kstack (next SYSCALL resets
	 * rsp to gs:8). .Lret pops. */
	push	rbx
	push	rbp
	push	r12
	push	r13
	push	r14
	push	r15
	mov	qword ptr [rip + gSavedRbx], rbx
	mov	qword ptr [rip + gSavedRbp], rbp
	mov	qword ptr [rip + gSavedR12], r12
	mov	qword ptr [rip + gSavedR13], r13
	mov	qword ptr [rip + gSavedR14], r14
	mov	qword ptr [rip + gSavedR15], r15
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
	je	.Lioctl
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
	cmp	rax, 95			/* umask */
	je	.Lumask
	cmp	rax, 115		/* getgroups */
	je	.Lgetgroups
	cmp	rax, 162		/* sync */
	je	.Lok0
	cmp	rax, 204		/* sched_getaffinity */
	je	.Lgetaffinity
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
	cmp	rax, 40			/* sendfile */
	je	.Lsendfile
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
	cmp	rax, 109		/* setpgid — LTP fork_testrun */
	je	.Lsetpgid
	cmp	rax, 110		/* getppid */
	je	.Lgetppid
	cmp	rax, 111		/* getpgrp */
	je	.Lgetpid
	cmp	rax, 121		/* getpgid */
	je	.Lgetpid
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
	cmp	rax, 274		/* Linux get_robust_list */
	je	.Lget_robust_list
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
	cmp	rax, 62			/* kill — heartbeat / teardown */
	je	.Lkill
	cmp	rax, 200		/* tkill */
	je	.Lkill
	cmp	rax, 234		/* tgkill */
	je	.Lkill
	cmp	rax, 26			/* msync */
	je	.Lok0
	cmp	rax, 37			/* alarm */
	je	.Lok0
	cmp	rax, 38			/* setitimer */
	je	.Lok0
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
	je	.Lpoll
	cmp	rax, 23			/* select */
	je	.Lselect
	cmp	rax, 270		/* pselect6 */
	je	.Lpselect
	cmp	rax, 271		/* ppoll */
	je	.Lppoll
	cmp	rax, 202		/* futex */
	je	.Lfutex
	cmp	rax, 59			/* execve */
	je	.Lexecve
	cmp	rax, 322		/* execveat */
	je	.Lexecveat
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
	 * After ND, identity LSTAR write is poison — C _user_write
	 * on this kstack so fflush can land.
	 */
	mov	byte ptr [rip + sPollWrote], 1
	KSER	'W'
	/* After ND, identity LSTAR write is poison — C _user_write
	 * on this kstack so fflush can land. */
	cmp	dword ptr [rip + sExitCloses], 0
	je	.Lwrite_id
	push	rcx
	push	r11
	sti
	call	sys_compat_write
	cli
	pop	r11
	pop	rcx
	jmp	.Lret
.Lwrite_id:
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
	/* Pipe/cat: identity 0x9e. After set_robust_list(NULL)
	 * (sExitCloses) glibc is in exit — jmp LSTAR KTs. Service
	 * those closes on this thread's gs:8, not gKstack. */
	KSER	'c'
	cmp	dword ptr [rip + sExitCloses], 0
	je	.Lclose_id
	push	rcx
	push	r11
	sti
	call	sys_compat_close
	cli
	pop	r11
	pop	rcx
	/* Return to userspace so libc fflush/exit_group can run
	 * with the real status. Do not xor rdi and .Lexit here. */
	jmp	.Lret
.Lclose_id:
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
	 * Directories use _kern_open_dir. /proc /sys go to C.
	 * Everything else stays on LSTAR — CALL_C on every open
	 * smashed gKstack when LTP fork_testrun raced wait4.
	 */
	test	rsi, 0x10000		/* LINUX O_DIRECTORY */
	jnz	.Lopen_dir_cwd
	mov	r8d, dword ptr [rdi]
	cmp	r8d, 0x6f72702f		/* "/pro" */
	je	.Lopen_c
	cmp	r8d, 0x7379732f		/* "/sys" */
	je	.Lopen_c
	cmp	r8d, 0x7665642f		/* "/dev" */
	jne	1f
	mov	r8d, dword ptr [rdi + 4]
	cmp	r8d, 0x3062662f		/* "/fb0" */
	je	.Lopen_c
1:
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
	/* Linux: rdi=dirfd rsi=path rdx=flags r10=mode */
	test	rdx, 0x10000		/* LINUX O_DIRECTORY */
	jnz	.Lopenat_dir
	mov	r8d, dword ptr [rsi]
	cmp	r8d, 0x6f72702f		/* "/pro" */
	je	.Lopenat_c
	cmp	r8d, 0x7379732f		/* "/sys" */
	je	.Lopenat_c
	cmp	r8d, 0x7665642f		/* "/dev" */
	jne	1f
	mov	r8d, dword ptr [rsi + 4]
	cmp	r8d, 0x3062662f		/* "/fb0" */
	je	.Lopenat_c
1:
	XLAT_OFLAGS
	mov	rax, 0x72
	jmp	.Llstar
.Lopenat_dir:
	mov	rax, 0x74		/* _kern_open_dir(dirfd, path) */
	jmp	.Llstar

.Lexit:
	KSER	'e'
	/* Linux mm_release on this thread's kstack, not gKstack.
	 * rdi is the exit status. gTmpR8 is clobbered by every
	 * Linux syscall — park status in sExitStatus. */
	mov	qword ptr [rip + sExitStatus], rdi
	mov	qword ptr [rip + sExitR14], r14
	/* glibc exit() does mov %r14d,%edi; _exit. A prior syscall
	 * that clobbered r14 made that _exit(0). Prefer r14 if rdi
	 * is 0 and r14 looks like a wait status. */
	test	rdi, rdi
	jnz	.Lexit_have
	mov	rax, r14
	cmp	rax, 256
	jae	.Lexit_have
	test	rax, rax
	jz	.Lexit_have
	mov	qword ptr [rip + sExitStatus], rax
.Lexit_have:
	mov	rsp, qword ptr [gs:8]
	sub	rsp, 0xA00
	and	rsp, -16
	sti
	call	sys_compat_exit_prep
	cli
	mov	rdi, qword ptr [rip + sExitStatus]
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
	/* Keep gLinuxFS if a sibling CR3 is still marked. Zeroing it
	 * here un-FS'd the parent when the pipe child exited. */
	cmp	qword ptr [rip + gLinuxN], 0
	jne	.Lexit_keepfs
	mov	qword ptr [rip + gLinuxFS], 0
	mov	qword ptr [rip + gRseqPtr], 0
	mov	qword ptr [rip + gRseqLen], 0
	mov	qword ptr [rip + gRseqSig], 0
.Lexit_keepfs:
	mov	dword ptr [rip + sChildDone], 1
	KSER	'E'
	/* Always _user_exit_team(status) + thread_exit. Identity
	 * LSTAR 0x29 after this stack dance delivered status 0
	 * (false → FALSE_RC=0, host exit_group(1)). Named label
	 * — KSER uses 1:/2:. */
	mov	dword ptr [rip + sExitCloses], 0
	mov	rdi, qword ptr [rip + sExitStatus]
	sti
	call	sys_compat_exit_team
	/* _user_exit_team posts SIGKILL and returns. Do not sysret
	 * (that KDLd under CLI). Wait for the signal with IF on. */
.Lexit_wait:
	sti
	hlt
	jmp	.Lexit_wait

.Lkill:
	/* LTP heartbeat is kill(ppid, SIGUSR1). Do not deliver.
	 * SIGKILL/SIGTERM to self still just succeed — exit_group
	 * follows. Never identity-pass (Haiku 62 is not kill). */
	KSER	'k'
	xor	rax, rax
	jmp	.Lret
.Lsetpgid:
	KSER	'G'
.Lok0:
	xor	rax, rax
	jmp	.Lret

.Lumask:
	/* rdi = new mask. Return the previous one. */
	mov	eax, dword ptr [rip + sUmask]
	mov	dword ptr [rip + sUmask], edi
	jmp	.Lret

.Lget1:
	/* gettid/set_tid_address: fake tid 1 is enough for single-thread. */
	mov	rax, 1
	jmp	.Lret

.Lgetpid:
	KSER	'g'
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
	/* CLONE_VM + child stack: same-team Haiku thread. */
	test	rdi, 0x100		/* CLONE_VM */
	jz	.Lclone_fork
	test	rsi, rsi
	jz	.Lenosys
	jmp	.Lclone_vm
.Lclone_fork:
	/* Fork-style only: stack==NULL, no CLONE_THREAD. */
	test	rsi, rsi
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
	mov	qword ptr [rip + gForkUserRbp], rbp
	mov	qword ptr [rip + gForkChildTid], r10
	/* Prefer the linux_go snapshot — rbx here should match. */
	mov	rax, qword ptr [rip + gSavedRbx]
	mov	qword ptr [rip + gForkRbx], rax
	mov	rax, qword ptr [rip + gSavedR12]
	mov	qword ptr [rip + gForkR12], rax
	mov	rax, qword ptr [rip + gSavedR13]
	mov	qword ptr [rip + gForkR13], rax
	mov	rax, qword ptr [rip + gSavedR14]
	mov	qword ptr [rip + gForkR14], rax
	mov	rax, qword ptr [rip + gSavedR15]
	mov	qword ptr [rip + gForkR15], rax
	mov	rax, qword ptr [rip + gSavedRbp]
	test	rax, rax
	jz	.Ltry_fork_args
	mov	qword ptr [rip + gForkUserRbp], rax
.Ltry_fork_args:
	mov	rdi, qword ptr [rip + gForkUserRip]
	mov	rsi, qword ptr [rip + gForkUserRsp]
	mov	rdx, qword ptr [rip + gForkUserFlags]
	/* Already kernel GS / gs:8. Do not swapgs. */
	KSER	'2'
	/* C below the iframe on THIS thread's kstack. gKstack is one
	 * global — echo close/getpid vs parent second clone smashed
	 * it (EX1: 5R then F6P homemade IRETQ #GP). Iframe sits at
	 * ktop-sizeof (~gs:8-200); 0xA00 leaves ~2K for C. */
	mov	rsp, qword ptr [gs:8]
	sub	rsp, 0xA00
	and	rsp, -16
	mov	rbp, rsp
	KSER	'3'
	call	sys_compat_try_fork
	/* C IRETQ did not take. Homemade 5-push #GP'd (EX1). */
	KSER	'6'
	cli
.Ltry_fork_stuck:
	hlt
	jmp	.Ltry_fork_stuck
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
	mov	rdx, [rip + gForkUserRsp]
	test	rdx, rdx
	jnz	.Lprsp
	mov	rdx, [rip + gForkHaikuRsp]
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
	 * Haiku wait_for_child user_memcpy's siginfo to userInfo.
	 * rsp-256 sits in the Linux frames (safe_waitpid / fork_testrun)
	 * and smashes status / RIP. Prefer the mark arena page. */
	KSER	'V'
	push	rcx
	push	r11
	push	rbx
	push	rbp
	mov	r8, qword ptr [rip + sWstatScratch]
	cmp	r8, 0x100000
	jae	1f
	mov	r8, qword ptr [gs:16]
	sub	r8, 256
1:
	mov	rcx, r10
	mov	rbx, rsp
	mov	rsp, qword ptr [gs:8]
	sub	rsp, 0xA00
	and	rsp, -16
	mov	rbp, rsp
	sti
	call	sys_compat_wait4
	cli
	mov	rsp, rbx
	pop	rbp
	pop	rbx
	pop	r11
	pop	rcx
	KSER	'v'
	jmp	.Lret

.Lexecveat:
	/* rdi=dirfd rsi=path rdx=argv r10=envp r8=flags → execve */
	mov	rdi, rsi
	mov	rsi, rdx
	mov	rdx, r10
.Lexecve:
	/* rdi=path rsi=argv rdx=envp. Flatten is BSS. C on gKstack. */
	KSER	'x'
	push	rcx
	push	r11
	push	rbx
	push	rbp
	/* Scratch on the SAME page as user RSP (…778 → 512 in-page).
	 * RSP-8192 is COW-RO after fork; kernel user_memcpy hung. */
	mov	r8, qword ptr [gs:16]
	sub	r8, 512
	and	r8, -16
	mov	rcx, r8
	mov	rbx, rsp
	mov	rsp, qword ptr [gs:8]
	sub	rsp, 0xA00
	and	rsp, -16
	mov	rbp, rsp
	sti
	call	sys_compat_execve
	cli
	mov	rsp, rbx
	pop	rbp
	pop	rbx
	pop	r11
	pop	rcx
	KSER	'y'
	jmp	.Lret

.Lfutex:
	/* rdi=uaddr rsi=op rdx=val r10=utime r8=uaddr2 r9=val3.
	 * Stay on gs:8 (this thread's kstack). A blocked WAIT on
	 * gKstack would be smashed by WAKE/CALL_C on another CPU. */
	KSER	'u'
	push	rcx
	push	r11
	push	rbp
	mov	rcx, r10
	mov	rbp, rsp
	sti
	call	sys_compat_futex
	cli
	pop	rbp
	pop	r11
	pop	rcx
	KSER	'U'
	jmp	.Lret

.Lppoll:
	/* rdi=fds rsi=nfds rdx=timespec* r10=sigset. Ignore sigset. */
	test	rdx, rdx
	jnz	.Lppoll_ts
	mov	rdx, -1
	jmp	.Lpoll
.Lppoll_ts:
	KSER	'o'
	push	rcx
	push	r11
	push	rbp
	xor	rcx, rcx
	mov	rbp, rsp
	sti
	call	sys_compat_ppoll
	cli
	pop	rbp
	pop	r11
	pop	rcx
	KSER	'O'
	jmp	.Lret
.Lpoll:
	/* rdi=fds rsi=nfds rdx=timeout_ms.
	 * ELF nfds==1: copy pollfd with user GS (uname pattern).
	 * C kldb of 0x403018 GPFd. Do not pass gs:16-512 as scratch. */
	KSER	'o'
	push	rcx
	push	r11
	push	rbp
	push	rdi
	push	rsi
	cmp	rsi, 1
	jne	.Lpoll_c
	cmp	rdi, 0x400000
	jb	.Lpoll_c
	cmp	rdi, 0x1000000
	jae	.Lpoll_c
	test	rdi, 7
	jnz	.Lpoll_c
	push	rax
	swapgs
	mov	rax, qword ptr [rdi]
	swapgs
	mov	qword ptr [rip + gPollSnap], rax
	pop	rax
.Lpoll_c:
	xor	rcx, rcx
	mov	rbp, rsp
	sti
	call	sys_compat_poll
	cli
	pop	rsi
	pop	rdi
	cmp	rsi, 1
	jne	.Lpoll_out
	cmp	rdi, 0x400000
	jb	.Lpoll_out
	cmp	rdi, 0x1000000
	jae	.Lpoll_out
	test	rdi, 7
	jnz	.Lpoll_out
	push	rax
	mov	rax, qword ptr [rip + gPollSnap]
	swapgs
	mov	qword ptr [rdi], rax
	swapgs
	pop	rax
.Lpoll_out:
	pop	rbp
	pop	r11
	pop	rcx
	KSER	'O'
	jmp	.Lret

.Lselect:
	/* rdi=nfds rsi=rfds rdx=wfds r10=efds r8=timeval */
	KSER	's'
	push	rcx
	push	r11
	push	rbp
	mov	rcx, r10
	mov	r9, qword ptr [gs:16]
	sub	r9, 1024
	and	r9, -16
	mov	rbp, rsp
	sti
	call	sys_compat_select
	cli
	pop	rbp
	pop	r11
	pop	rcx
	KSER	'S'
	jmp	.Lret

.Lpselect:
	/* rdi=nfds rsi=rfds rdx=wfds r10=efds r8=timespec r9=sigset */
	KSER	's'
	push	rcx
	push	r11
	push	rbp
	mov	rcx, r10
	/* r8 stays timespec; scratch in a stack slot via r9 overwrite */
	mov	r9, qword ptr [gs:16]
	sub	r9, 1024
	and	r9, -16
	mov	rbp, rsp
	sti
	call	sys_compat_pselect
	cli
	pop	rbp
	pop	r11
	pop	rcx
	KSER	'S'
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

.Lclone_vm:
	/* rdi=flags rsi=child_stack rcx=user RIP. Same CR3. */
	KSER	'T'
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	mov	rdx, rdi
	mov	rdi, rcx
	CALL_C	sys_compat_clone_vm

.Lopen_c:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	push	rbp
	mov	rcx, rdx
	mov	rdx, rsi
	mov	rsi, rdi
	mov	rdi, -100
	mov	[rip + gSavedRsp], rsp
	lea	rsp, [rip + gKstackEnd]
	and	rsp, -16
	sti
	call	sys_compat_open
	cli
	mov	rsp, [rip + gSavedRsp]
	pop	rbp
	pop	r10
	pop	r9
	pop	r8
	pop	rdx
	pop	rsi
	pop	rdi
	pop	r11
	pop	rcx
	jmp	.Lret

.Lopenat_c:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	push	rbp
	mov	rcx, r10
	mov	[rip + gSavedRsp], rsp
	lea	rsp, [rip + gKstackEnd]
	and	rsp, -16
	sti
	call	sys_compat_open
	cli
	mov	rsp, [rip + gSavedRsp]
	pop	rbp
	pop	r10
	pop	r9
	pop	r8
	pop	rdx
	pop	rsi
	pop	rdi
	pop	r11
	pop	rcx
	jmp	.Lret

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
	/* File maps from vm_map_file are Haiku areas. delete_area
	 * them in C. Do not call _user_unmap_memory (that KTd). */
	KSER	'n'
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
	call	sys_compat_munmap
	cli
	mov	rsp, [rip + gSavedRsp]
	/* C returns 1 after ND. Set the flag HERE so .Lclose in this
	 * image sees it (C write was invisible across dual loads). */
	cmp	rax, 1
	jne	1f
	mov	dword ptr [rip + sExitCloses], 1
	xor	rax, rax
1:
	pop	r10
	pop	r9
	pop	r8
	pop	rdx
	pop	rsi
	pop	rdi
	pop	r11
	pop	rcx
	jmp	.Lret
.Lgetgroups:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	CALL_C	sys_compat_getgroups
.Lgetaffinity:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	CALL_C	sys_compat_sched_getaffinity
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
	/* Store (head,len) here. CALL_C on gKstack raced the
	 * parent's wait4/getpid and KTd at gbB1 (PR11b). Keep
	 * rdx — glibc _Fork returns edx as the child pid. */
	KSER	'b'
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	mov	qword ptr [rip + sRobustList], rdi
	mov	qword ptr [rip + sRobustLen], rsi
	xor	rax, rax
	pop	r10
	pop	r9
	pop	r8
	pop	rdx
	pop	rsi
	pop	rdi
	pop	r11
	pop	rcx
	jmp	.Lret
.Lget_robust_list:
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	CALL_C	sys_compat_get_robust_list
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
	KSER	'd'
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
.Lioctl:
	/* Linux ioctl → C. TTY maps onto Haiku tty.
	 * Unknown cmds return -ENOTTY. Do not stub TCGETS as 0. */
	KSER	'I'
	push	rcx
	push	r11
	push	rdi
	push	rsi
	push	rdx
	push	r8
	push	r9
	push	r10
	CALL_C	sys_compat_ioctl

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
	KSER	'N'
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
	 * ANON: carve the loader arena. File: _user_map_file.
	 */
	test	r10, 0x20		/* MAP_ANONYMOUS */
	jz	.Lmmap_file
	cmp	qword ptr [rip + gBrkBase], 0
	je	.Lnomem
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

.Lmmap_file:
	KSER	'M'
	push	rcx
	push	r11
	push	rbp
	mov	rcx, r10
	mov	rbp, rsp
	sti
	call	sys_compat_mmap
	cli
	pop	rbp
	pop	r11
	pop	rcx
	KSER	'm'
	jmp	.Lret

.Lsendfile:
	/* rdi=out rsi=in rdx=offp r10=count
	 * Linux SYSCALL must preserve rbp. EX3 returned EINVAL
	 * (fSF) then cat_main touched [rbp] → Kill Thread. */
	KSER	'f'
	push	rcx
	push	r11
	push	rbp
	mov	rcx, r10
	mov	rbp, rsp
	sti
	call	sys_compat_sendfile
	cli
	pop	rbp
	pop	r11
	pop	rcx
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
	/* Do not store into gRseqPtr here. After fork that user page
	 * is COW-RO; a CLI write is KDL (lstar+0x2240 on exit01).
	 * Register/unregister already wrote cpu_id.
	 * Do not apply_fs here — every-sysret WRMSR/ULS write KTd
	 * the pipe parent after wait4 (PR11 first guest). */
	pop	r15
	pop	r14
	pop	r13
	pop	r12
	pop	rbp
	pop	rbx
.Lsysret:
	mov	rsp, qword ptr [gs:16]
	swapgs
	sysretq

.Llstar:
	/* After ND, jmp official LSTAR KTs (identity close). The
	 * only LSTAR still allowed is _kern_exit_team (0x29).
	 * Named labels: KSER uses 1:/2: and je 1f would land in it. */
	cmp	dword ptr [rip + sExitCloses], 0
	je	.Llstar_go
	cmp	rax, 0x29
	je	.Llstar_go
	KSER	'X'
	xor	rax, rax
	jmp	.Lret
.Llstar_go:
	mov	rsp, qword ptr [gs:16]
	swapgs
	jmp	[rip + gOrigLstar]

	.data
	.align	4
sUmask:
	.long	0x12			/* 022 */

	.bss
	.align	8
sExitStatus:
	.quad	0
sExitR14:
	.quad	0
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
gSavedRbx:
	.quad	0
gSavedRbp:
	.quad	0
gSavedR12:
	.quad	0
gSavedR13:
	.quad	0
gSavedR14:
	.quad	0
gSavedR15:
	.quad	0
gForkRetAddr:
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
gForkUserRbp:
	.quad	0
gForkChildTid:
	.quad	0
gForkRbx:
	.quad	0
gForkR12:
	.quad	0
gForkR13:
	.quad	0
gForkR14:
	.quad	0
gForkR15:
	.quad	0
gMarkExe:
	.quad	0
gForkFS:
	.quad	0
sChildDone:
	.long	0
sExitCloses:
	.long	0
	.align	8
sRobustList:
	.quad	0
sRobustLen:
	.quad	0
sWstatScratch:
	.quad	0
gPollSnap:
	.quad	0
sPollWrote:
	.byte	0
	.align	16
gKstack:
	.space	32768
gKstackEnd:
