# Developer standup: Day 14

**Module:** `sys_compat` syscall trap (no ioctl layer)  
**License:** Public Domain / CC0 1.0 Universal  
**Pickup / onboarding:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)  
**90% map:** [SYSCALL_COVERAGE.md](SYSCALL_COVERAGE.md)

Fork diagnosis wrap. `_kern_fork` itself is fine. The reboot is
**post-mark**: child IRETQ (or parent SYSRET) into Linux after
`clone` from a marked team.

### Tracker (Haiku Trac)

`dev.haiku-os.org` is behind Anubis; live ticket search is blocked.
Source + git history + commit-linked tickets:

| Ticket | Relevance |
|---|---|
| *(none)* | No ticket for “`_kern_fork` only via official SYSCALL” or “IRETQ to a copied 0x400000 map panics” |
| #18692 | DF IST was broken ~2014–2024; double fault = silent reboot. Fix is in hrev57937 |
| #15236 | `lfence` after `swapgs` — GS on SYSCALL entry is load-bearing |
| #1745 | KDL docs: iframe lives at kstack top |
| #19337 / #17556 | fork + odd `vm_copy_area` / COW — errors, not reboots |
| #17896 | TLS on fork is updated, not wiped |
| #16705 | Linux `exit=60` is `_kern_cancel_thread` (already known) |

This is an **implementation contract**, not an unfixed Haiku bug.

`arch_store_fork_frame()` → `x86_get_current_iframe()` walks RBP only
inside `Thread.kernel_stack_base..top`. Marker is `*rbp` with high bits
0 and low nibble = `IFRAME_TYPE_SYSCALL` (1). Official SYSCALL entry
plants that iframe at `kernel_stack_top` and sets `RBP=RSP=iframe`.
Calling `_user_fork` from a driver on `gKstack` cannot satisfy the walk.
Child return is `arch_restore_fork_frame` → `x86_return_to_userland` →
`swapgs; iretq`. Bad CS/SS/IP/flags after that `swapgs` is a triple
fault: no KDL, no serial.

### Guest results (2026-08-14)

| Probe | What it tests | Result |
|---|---|---|
| `tests/haiku_native_fork.c` (gcc on guest) | Native Haiku `fork()` | `NATIVE_PARENT 445` / `NATIVE_CHILD` / `NATIVE_OK` |
| `sys_compat_run` Haiku `fork()` after mapping Linux ELF at 0x400000, **no mark** | `vm_copy_area` of that map | `HAIKU_FORK_PARENT 446` / `HAIKU_FORK_CHILD` / `HAIKU_FORK_OK` |
| Plant iframe at `gs:8` (`syscall_rsp`) + `call _user_fork` | Fake official layout | Silent reboot, no KDL |
| User GS, user RSP, `rax=0x2f`, `jmp` original LSTAR | Real official `_kern_fork` from a **marked** Linux team | Same silent reboot |
| Earlier kstack upper bound `0xffffff0000000000` | Validation bug | `NEG` / `frk=-EFAULT`; guest stayed up. That bound is *below* real stacks (`0xffffffff877f0000`) |

`hello_min` still green. Single-process busybox CLI still green.

### What we ruled out

- Haiku `_kern_fork` is broken (native fork works).
- `vm_copy_area` cannot clone the 0x400000 Linux map (Haiku-side fork after mmap works).
- The 32 MB arena COW (fork probes skip it).
- Missing iframe on `gKstack` (official LSTAR jmp still reboots).
- Child Linux `exit(60)` / `cancel_thread` (probe child only spins).

### What is left

Fork **after mark**. Child IRETQs into Linux (`iframe.ip` = Linux RIP,
`iframe.sp` = Linux stack) or the parent SYSRETs back into Linux on
another CPU. Same areas already survived a Haiku-side `fork()`.

`sys_compat_run` currently **returns after** `HAIKU_FORK_OK` when the
path contains `"fork"`, so the next probe will not instantly reboot.
Flip that return off when taking the next cut.

Hook `.Ltry_fork` is the official LSTAR jmp (`rax=0x2f`, user GS).
`sys_compat_try_fork` (planted iframe) is still in the driver for
diagnostics; the hook does not call it.

### Next (do not skip)

1. Isolate child IRETQ into Linux: one QEMU CPU, or IRETQ to a Haiku
   trampoline that then jumps. Flip the isolation `return 0` off.
2. Parent must print `PRE` without a reset.
3. Stamp the child's CR3 so Linux `exit` (60) ≠ `_kern_cancel_thread`.
4. `wait4`, then `execve`.
5. pthread (`futex`, `CLONE_VM`) later. ioctl still deferred.

Adopt-on-every-miss stays **off**.
