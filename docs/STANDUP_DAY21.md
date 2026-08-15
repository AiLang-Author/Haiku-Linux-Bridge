# Developer standup: Day 21

**Module:** `sys_compat` syscall trap (no ioctl layer)
**License:** Public Domain / CC0 1.0 Universal
**Pickup / onboarding:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)
**90% map:** [SYSCALL_COVERAGE.md](SYSCALL_COVERAGE.md)

Child official IRETQ now lands on the real Linux clone return
(`0x40101c`, `ax=0` → ELF `exit(60)`). `hello_fork` still `FORKOK`
RC=0. QEMU was restarted after the 10h cap.

### Proof (guest 2026-08-15)

COM1:

```
F4
S5eRE
VvWeE
```

`fork.out`: `FORKOK` / `FORK_RC=0`. `seq=56,61,1,60`.

### What was actually broken

`gForkPending` is one global. While it is 1, **any** CR3-miss
syscall stamped — including Haiku `app_server` / `message deliverer`
on another CPU (`-smp 4`). That was `SX` mid-`F2` hex and the
Debugger screen. CLI is per-CPU.

Stamp now only if user RIP (`rcx`) is in `0x400000..0x405000` or
the tramp page. Haiku threads identity-pass.

### What is still open

| Step | Result |
|---|---|
| Parent IRETQ to `0x40101c` | Green |
| Child IRETQ to `0x40101c` + ELF `exit` | **`FORKOK`** |
| `execve` | Open |

### Next (do not skip)

1. `execve`.
2. pthread / ioctl later.

Landmines: stamp only Linux RIP; `gForkPending` is global; CLI is
per-CPU; adopt-on-every-miss stays **off**. ioctl deferred.
