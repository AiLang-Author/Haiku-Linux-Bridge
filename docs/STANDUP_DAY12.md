# Developer standup: Day 12

**Module:** `sys_compat` syscall trap (no ioctl layer)  
**License:** Public Domain / CC0 1.0 Universal  
**Pickup doc:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)  
**90% map:** [SYSCALL_COVERAGE.md](SYSCALL_COVERAGE.md)

Pyramid this round: the everyday CLI layer, not the 400-syscall tail.
Rare / deprecated numbers wait for a filed issue.

### What landed (guest-proven)

- [x] Unmodified busybox **grep, wc, sed, head, sort, cut** via
  `sys_compat_run`. All **RC=0** on `/tmp/cli.txt`.
  `grep hello` printed `hello world` / `hello linux`.
  `sed s/hello/hi/` rewrote both lines. `wc -l` → `4`.
  `results/ltp/cli_out.txt`. Kernel stayed up (`mark=6 hits=137`).
- Host `strace` of this busybox `grep`: openat/read/write/fstat/close/
  brk/mprotect/newfstatat plus the already-proven glibc startup set.
  No new syscall was required.

### Tried, not this layer

- [ ] Fork-style `clone` + `wait4`. `_kern_fork` from a marked Linux
  team **reboots** the guest (triple-fault class — no new serial KDL).
  Adopt-on-CR3-miss also killed Terminal in earlier cuts. Spawn stays
  parked. Single-process CLI does not need it.

### Score

Same ~76 guest-proven numbers. The tip got closer: the text-utils
people actually run now work as one process each.

### Next (do not skip)

1. Safe fork/wait (must not reboot) then `execve` — shells, pipelines.
2. `futex` + `rt_sigaction` if a real applet needs them.
3. ioctl / TTY / sockets last.
