# Developer standup: Day 16

**Module:** `sys_compat` syscall trap (no ioctl layer)
**License:** Public Domain / CC0 1.0 Universal
**Pickup / onboarding:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)
**90% map:** [SYSCALL_COVERAGE.md](SYSCALL_COVERAGE.md)

The kernel-killing post-fork return is fixed. Linux `clone` gets
through `_user_fork` and back into **user mode** without a reset.
Returning the parent into the Linux ELF at `0x40101c` is still open.

### What syslog showed

`/var/log/previous_syslog` is the last boot's kernel ring. It stopped
at `try_fork returned 428` / `parent return` with **no PANIC**. That is
a triple fault: death after `swapgs`, before the next `dprintf`.

Pull it with `scripts/guest_dump_syslog.sh` after a reset.

### What KDL showed

Forcing a `#PF` before IRETQ hit Kernel Debugging Land:

```
PANIC: vm_page_fault at 0xffffffffffffffd8
dis: movq %r8, -0x38(%rbp)    ; 0x10 - 0x38 = 0xffffffffffffffd8
```

The hook called C on `gKstack` without setting `RBP`. `-O3` spills
through `-0x38(%rbp)`. Leftover user `RBP` was `0x10`.

A second smash: C frame and planted iframe shared the real kstack.
`_user_fork` grows down and overwrote the return address. Syslog logged
`parent return` then a hard reset.

### The fix

- C stays on `gKstack` (32 KB) with `RBP` set.
- Iframe stays on the real kernel stack (`gs:8`).
- `STI` only around `_user_fork`, when `RBP` **is** that iframe.
  Official SYSCALL does the same. `STI` on `gKstack` jumped to
  `0x19e1e78c0bc`. `CLI` during `user_memcpy` can panic
  "page fault, but interrupts were disabled".
- Parent return is official `x86_return_to_userland` (scanned from
  LSTAR: `movq %rdi,%rbp ; movq %rbp,%rsp ; movq %gs:0,%r12`).
  Frame is a driver-static copy so `_user_fork` cannot smash it.

### Proof (COM1)

```
RETUfn=0xffffffff801428cd
F5 st=0x1d7
RETU ip=<tramp+64>
U
```

Parent ran user code (`OUT` to COM1). Desktop stayed up. First Linux
clone that came back to user mode without a reset or KDL.

### What is still open

| Return | Result |
|---|---|
| Official IRETQ to tramp + Haiku SP + `eb fe` / `OUT 'U'` | Guest lives |
| Official IRETQ to Linux `RIP=0x40101c` | Hard reset, no PANIC |
| Tramp then `jmp 0x40101c` | Hard reset, no PANIC |

Kernel can **read** `0x40101c` after fork (`INSN=0x78c08548` =
`test rax,rax; js`). The page is present. Execute / Linux-stack
switch after the proven tramp landing is the remaining edge.

Current isolation stub (in tree): tramp+64 loads Linux RSP then
`OUT 'U'` (no jump). `U` + live guest ⇒ stack is fine. Reset ⇒
Linux RSP is poison.

### Next (do not skip)

1. Finish the Linux-RSP isolation. Then tramp → `0x40101c` so the
   probe prints `PRE` (`KSER W`).
2. Stamp child CR3 so Linux `exit` 60 ≠ `_kern_cancel_thread`.
3. `wait4`, then `execve`.
4. pthread / ioctl later.

Landmines this round: `previous_syslog` is the dying ring, not the
live file; KDL `reboot` can leave a black screen (QMP `system_reset`);
`user_memcpy` under `CLI` panics; do not IRETQ from a C frame that
sits under `_user_fork`; Deskbar leaf → Applications → Terminal.

Adopt-on-every-miss stays **off**. ioctl still deferred.
