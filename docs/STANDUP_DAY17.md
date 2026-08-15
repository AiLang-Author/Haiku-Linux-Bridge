# Developer standup: Day 17

**Module:** `sys_compat` syscall trap (no ioctl layer)
**License:** Public Domain / CC0 1.0 Universal
**Pickup / onboarding:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)
**90% map:** [SYSCALL_COVERAGE.md](SYSCALL_COVERAGE.md)

Parent `PRE` after `_user_fork` is green. First real Linux syscall
out of official IRETQ works. The guest stays up.

### Proof (guest 2026-08-15)

COM1:

```
MMARK team=0x1b7
mQC123F2 rip=0x40101c tramp=0x29a217e000 hrsp=0x7fa191382ac0
F4
5R
W
```

`/tmp/fork.out` ends with `PRE`. Desktop stayed up (parent and child
on `eb fe`). `hits` / `last=228` (Linux `write`) after the run.

### What was actually dying

IRETQ to tramp+64 was already proven (Day 16 COM1 `U`). The PRE stub
on that same page `syscall`'d `write`. After `fork_team` the user
stack is COW-RO until the first write. The hook was still pushing
there:

1. Entry `push rax` before any stack switch — first diagnosis.
   Fix: official-shaped `swapgs`; save user RSP at `gs:16`;
   `RSP=gs:8` before any push. Restore + `swapgs` before `jmp` LSTAR
   so official `swapgs` is still correct.
2. `.Llinux_go` last-N `push r8/r9` after restoring the user stack.
   Fix: spill to `gTmpR8` / `gTmpR9`.
3. `gForkPending=1` made the first post-fork Linux syscall take
   `KSER 'L'` on that same COW-RO stack. Triple fault after `R`,
   no `W`, no PANIC. Fix: no `KSER` on the user stack after restore.
4. `KSER 'W'` itself pushes. Fix: switch to `gs:8` for that poke,
   then restore user RSP before `jmp` LSTAR.

CLI hex dumps after `_user_fork` (`F5 st=…`) also `#PF` at `ip=0`.
After fork only `kser_puts("5")` then official return.

The iframe for official `x86_return_to_userland` is a **gKstack
local**, not driver BSS (`system_time` after `mov rsp,rdi` smashed
globals when the frame lived in BSS). Flags `0x3202` (same as the
live `U` run). Loader plants the PRE stub in userland before mark
(no kernel `user_memcpy` under CLI). `.text` is `mprotect` RX so
fork COW cannot strip X.

### What is still open

| Return | Result |
|---|---|
| Official IRETQ to tramp + Haiku SP + `eb fe` / `OUT 'U'` | Guest lives |
| Official IRETQ to tramp+64 Linux `write(PRE)` | **`PRE` / `KSER W`, guest lives** |
| Official IRETQ to Linux `RIP=0x40101c` | Hard reset, no PANIC |

Kernel can still **read** `0x40101c` after fork (`INSN=0x78c08548`).
Execute of that page after the proven tramp landing is the remaining
edge.

### Next (do not skip)

1. IRETQ parent to `0x40101c` (RX text). Child can stay on tramp+0
   `eb fe`.
2. Stamp child CR3 so Linux `exit` 60 ≠ `_kern_cancel_thread`.
3. `wait4`, then `execve`.
4. pthread / ioctl later.

Landmines this round: after fork, **no `push` / `KSER` on the user
stack**; `gs:8` first; last-N via BSS; short `5` not hex; do not
truncate `haiku_serial.log`; QMP `system_reset` after KDL; Deskbar
→ Applications → Terminal (Tracker search opens WebPositive).

Adopt-on-every-miss stays **off**. ioctl still deferred.
