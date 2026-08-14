/*
 * x86_64 LSTAR trampoline — identity for Haiku, remap for Linux.
 *
 * Haiku path: push/pop rax, jmp original LSTAR. No swapgs.
 * Linux-marked CR3: rewrite rax (and args if needed) to the equivalent
 * Haiku syscall and jmp original LSTAR. Unknown numbers sysret -ENOSYS.
 * Never call C from here. Never switch stacks. A bad Linux number
 * must not panic the kernel.
 *
 * Haiku numbers from this image's libroot stubs (hrev57937):
 *   _kern_write      = 0x97 (151)
 *   _kern_exit_team  = 0x29 (41)
 *
 * License: Public Domain / CC0 1.0 Universal
 */

	.intel_syntax noprefix
	.text
	.globl	sys_compat_lstar
	.globl	gOrigLstar
	.globl	gLinuxCR3
	.hidden	gOrigLstar
	.hidden	gLinuxCR3

sys_compat_lstar:
	push	rax
	mov	rax, cr3
	cmp	rax, [rip + gLinuxCR3]
	je	.Llinux
	pop	rax
	jmp	[rip + gOrigLstar]

.Llinux:
	pop	rax

	cmp	rax, 1			/* Linux write */
	je	.Lwrite
	cmp	rax, 60			/* Linux exit */
	je	.Lexit
	cmp	rax, 231		/* Linux exit_group */
	je	.Lexit

	/* Reject, do not panic. SYSCALL already left RIP in RCX, RFLAGS in R11. */
	mov	rax, -38		/* -ENOSYS */
	sysretq

.Lwrite:
	/* Linux: rdi=fd rsi=buf rdx=count
	 * Haiku _kern_write: rdi=fd rsi=pos rdx=buf rcx/r10=count
	 */
	mov	r10, rdx
	mov	rdx, rsi
	mov	rsi, -1
	mov	rax, 0x97
	jmp	[rip + gOrigLstar]

.Lexit:
	/* Linux: rdi=code  Haiku _kern_exit_team: rdi=status */
	mov	rax, 0x29
	jmp	[rip + gOrigLstar]

	.bss
	.align	8
gOrigLstar:
	.quad	0
gLinuxCR3:
	.quad	0
