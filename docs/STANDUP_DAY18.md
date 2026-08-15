# Developer standup: Day 18

**Module:** `sys_compat` syscall trap (no ioctl layer)
**License:** Public Domain / CC0 1.0 Universal
**Pickup / onboarding:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)
**90% map:** [SYSCALL_COVERAGE.md](SYSCALL_COVERAGE.md)

Parent official IRETQ now lands on the real Linux clone return
(`0x40101c`). The ELF's own `write(PRE)` works. Guest stays up.

The old `0x40101c` hard reset was the same post-fork COW-RO hook-push
bug Day 17 fixed for the tramp pad — not NX, not a bad RIP.

### Proof (guest 2026-08-15)

COM1 (parent to `0x40101c`):

```
MMARK team=0x1b6
mQC123F2 rip=0x40101c tramp=0xf71d2c4000 hrsp=0x7feee0e017c0
F4
5R
W
```

`/tmp/fork.out` ends with `PRE`. Desktop stayed up.

`0x40101c` is `test %rax,%rax` then `write` from `.rodata` at
`0x402000`. Loader `mprotect`s `.text` RX (`prot=5`) before mark.

### Child CR3 stamp

Child IRETQ is Haiku's (iframe.ip = tramp+0) and runs **during**
`_user_fork` (`STI` around the call). First child syscall misses
parent CR3, `gForkPending=1`, stamps a free slot (`KSER S`):

```
F4
S5R
W
```

`S` is before parent `5` — the child is live while the parent is
still in `try_fork`. Guest stays up. Child `write` of `CHD` after
that stamp has not appeared in `fork.out` yet (no second `W`).

Stamp stays on `gs:8`. Do not restore the user stack and walk
`.Llinux_go` for that first child syscall — that path printed `S`
and then lost the write.

### What is still open

| Step | Result |
|---|---|
| Official IRETQ to tramp+64 `write(PRE)` | Green (Day 17) |
| Official IRETQ to Linux `0x40101c` | **`PRE` / `KSER W`, guest lives** |
| Child first syscall stamps CR3 | **`KSER S` during `_user_fork`** |
| Child `write` / `exit` after stamp | No `CHD` yet |
| `wait4` / `execve` | Not started |

### Next (do not skip)

1. Child `write`/`exit` that races with parent still in `_user_fork`.
   Then `wait4`, then `execve`.
2. pthread / ioctl later.

Landmines this round: after fork, no `push` / `KSER` on the user
stack; child starts under `STI` inside `_user_fork`; `gKstack` is
still a single global (`-smp 4`); adopt-on-every-miss stays **off**.
ioctl still deferred.
