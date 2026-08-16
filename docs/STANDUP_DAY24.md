# Developer standup: Day 24

**Module:** `sys_compat` syscall trap (no ioctl layer)
**License:** Public Domain / CC0 1.0 Universal
**Pickup / onboarding:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)
**90% map:** [SYSCALL_COVERAGE.md](SYSCALL_COVERAGE.md)

Linux `poll` / `ppoll` are guest-green via Haiku
`_user_wait_for_objects` (`0x06`). Combined with Day 23 `futex`,
pipelines have a real wait path.

### Proof (guest 2026-08-15)

`hello_poll`: `pipe2` + `poll(read, POLLIN, 0)` empty → `0`; write
1 byte; poll again → `1` + `POLLIN`. Prints `POLLOK`. `POLL_RC=0`.
Desktop stayed up.

COM1: `oOWoOWeE`. `seq=293,7,1,7,1,60`. Guest dump:
`_kern_wait_for_objects nr=0x6`. `WOBJfn=0xffffffff80095870`.

### How it works

`.Lpoll` / `.Lppoll` stay on the official per-thread kstack. Convert
Linux `pollfd` to `object_wait_info` (user scratch at `RSP-512`),
call `_user_wait_for_objects`, convert events back. `ppoll` timespec
→ ms; sigset ignored. Timeout 0 / `B_TIMED_OUT` / `B_WOULD_BLOCK`
return 0 ready fds.

### What is still open

| Step | Result |
|---|---|
| poll/ppoll + pipe2 | **`POLLOK`** |
| `select` / `pselect6` | Open (same helper later) |
| `CLONE_VM` / PI futex | Later |
| ioctl | Deferred |

### Next (do not skip)

1. `select` if a CLI path needs it; otherwise file `mmap`.
2. ioctl / TTY / sockets only after the CLI 90% set is green.

Landmines: `_user_wait_for_objects` needs a user pointer; block on
the official kstack not `gKstack`; adopt-on-every-miss stays **off**.
ioctl deferred.
