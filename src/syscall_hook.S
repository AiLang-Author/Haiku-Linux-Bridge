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
	cmp	rax, 3			/* Linux close */
	je	.Lclose
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
