# Developer standup: Day 23

**Module:** `sys_compat` syscall trap (no ioctl layer)
**License:** Public Domain / CC0 1.0 Universal
**Pickup / onboarding:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)
**90% map:** [SYSCALL_COVERAGE.md](SYSCALL_COVERAGE.md)

Linux `futex` WAIT/WAKE is guest-green. `rt_sigaction` /
`rt_sigprocmask` stay the glibc install-and-ignore `return 0`.

### Proof (guest 2026-08-15)

`hello_futex`: WAIT val-mismatch → `-EAGAIN`, WAKE empty → `0`,
WAIT + 1 ms → `-ETIMEDOUT`. Prints `FUTEXOK`. `FUTEX_RC=0`.
Desktop stayed up.

COM1: `uUuUuU` (three futex, then write/exit). `seq=202,202,202,1,60`.
`hits=5 last=60`.

### How it works

`.Lfutex` stays on the official per-thread kstack (`gs:8`), sets
`RBP`, STI, calls `sys_compat_futex`. Do **not** park WAIT on
global `gKstack` — a WAKE from another CPU would smash it.

WAIT/WAKE (and BITSET / REQUEUE-as-wake) use a driver mutex sem
plus a per-waiter `create_sem(0)`. Value re-check happens before
enqueue. Unknown cmds (`LOCK_PI` …) return `-ENOSYS`.

### What is still open

| Step | Result |
|---|---|
| futex WAIT/WAKE in-process | **`FUTEXOK`** |
| futex across `CLONE_VM` | Later (pthread) |
| `poll` / `ppoll` | Open |
| ioctl | Deferred |

### Next (do not skip)

1. `poll` / `ppoll` — pipelines (`cat | grep`).
2. ioctl / TTY / sockets only after the CLI 90% set is green.

Landmines: WAIT on per-thread kstack; unaligned uaddr is
`EINVAL`; adopt-on-every-miss stays **off**. ioctl deferred.
