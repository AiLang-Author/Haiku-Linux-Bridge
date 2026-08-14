# Developer standup: Day 11

**Module:** `sys_compat` syscall trap (no ioctl layer)  
**License:** Public Domain / CC0 1.0 Universal  
**Pickup doc:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)  
**90% map:** [SYSCALL_COVERAGE.md](SYSCALL_COVERAGE.md)

Pyramid base this round: file-control + modern stat. Coreutils and
glibc-static hit `fcntl` / `statx` constantly; they sit under spawn,
not beside it.

### What landed (guest-proven)

- [x] Linux `fcntl` (72) via `_kern_fcntl` **0x76** (guest dump:
  sandwiched between `open_dir` 0x74 and `fsync` 0x77). Commands:
  F_DUPFD / F_GETFD / F_SETFD / F_GETFL / F_SETFL / F_DUPFD_CLOEXEC.
  Linux F_* and O_APPEND/O_NONBLOCK translated. Unknown cmds `-EINVAL`.
  Return the fd or flags, not 0. GETFD masked to FD_CLOEXEC.
- [x] Linux `statx` (332) from `_kern_read_stat`. 256-byte buffer,
  `stx_mask` = BASIC|BTIME, `stx_size` @40, `stx_mode` @28.
- [x] Linux `fadvise64` (221) hint → 0 (not ENOSYS).
- [x] `hello_fcntl` printed **`FCNTOK`**, `FCNTL_RC=0`.
  `hello_min` still `HELLO_RC=0`. `hello_date` still **`DATEOK 1786732658`**.
  Kernel stayed up. `fcntl=0xffffffff80105a90` in `/dev/misc/sys_compat`.

### Score

~76 guest-proven useful Linux numbers. ~93 dispatched (including stubs).

### Next (do not skip)

1. Fork-style `clone` + `wait4` + `execve` — shells, make, Ailang/gcc.
   Adopt-on-CR3-miss stays **off** until this path is explicit and proven.
2. `futex` + `rt_sigaction` (no-op install often enough).
3. ioctl / TTY / sockets — only after the 90% table is mostly green.
