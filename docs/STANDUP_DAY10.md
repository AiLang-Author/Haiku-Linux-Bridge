# Developer standup: Day 10

**Module:** `sys_compat` syscall trap (no ioctl layer)  
**License:** Public Domain / CC0 1.0 Universal  
**Pickup doc:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)  
**90% map:** [SYSCALL_COVERAGE.md](SYSCALL_COVERAGE.md)

This round’s goal was “make it a real boy”: unmodified Linux sysutils, a
correct `date`, and a visible list of the ~80–100 syscalls that dominate
CLI software.

### What landed (guest-proven)

- [x] Former return-0 stubs became real mappings: `mprotect`/`munmap`,
  `chmod`/`fchmod`/`fchmodat`, `chown` family, `truncate`/`ftruncate`,
  `getuid`/`setuid`/`getgid`/`setgid`, `gettid`/`set_tid_address`/
  `set_robust_list`, `prctl` name. `hello_wstat` printed **`WSTATOK`**.
  Commit `3533193`.
- [x] File-util pack: `rename`/`symlink`/`readlink`/`stat`/`lstat`/`dup`/
  `fsync`/`utimensat`. `hello_util` printed **`UTILOK`**. Unmodified
  busybox **`cp` `mv` `ln -s` `readlink` `touch` `rm` `cat` `echo` `ls`**
  all RC=0. Commit `eeb950a`.
- [x] Real **`date`**. `time` (201) + `gettimeofday` (96) +
  `clock_gettime` via `_kern_get_clock` **0xc0** (guest dump; later Haiku
  trees count it as 0xc1). `hello_date` printed **`DATEOK 1786731467`**.
  busybox `date` / `date -u` printed **`Fri Aug 14 18:17:47 UTC 2026`**.
  Commit `48d23d2`.
- [x] Core 90% table written: [SYSCALL_COVERAGE.md](SYSCALL_COVERAGE.md).
  There is no official kernel “these 80 are 90%” file. The table is
  host `strace` of this busybox + GNU coreutils + glibc-static startup +
  the same names gVisor/linuxulator implement.

### KDLs this round (ours)

- [x] `real_time_clock_usecs()` from the driver resolved to a libroot
  stub, re-entered `SYSCALL`, fault at `0x100000000`. Never call libroot
  time from this addon. Use `kSyscallInfos[_kern_get_clock]`.
- [x] Second panic was a NULL deref in Terminal’s writer while
  `hello_util` was still loading. After a clean reset, adopt-on-CR3-miss
  off, `hello_min` / `hello_wstat` / `hello_util` all loaded. Adopt stays
  off until fork is an explicit, proven path.
- [x] Hard `link` can return EPERM on this volume. `ln -s` is the one
  that matters and is proven.

### Wired, not separately guest-proven

`pread64`/`pwrite64`, `writev`/`readv`, `getppid`, `pipe`/`pipe2`,
`nanosleep` (returns 0). Numbers dumped: `readv=0x96` `writev=0x98`
`create_pipe=0x83`.

### Score

~70 guest-proven useful Linux numbers. ~90 dispatched (including stubs).
busybox CLI applets that work: echo, uname, cat, ls, ls -l, cp, mv,
ln -s, readlink, touch, rm, date.

### Next (do not skip)

1. `fcntl` + `statx` — modern coreutils.
2. Fork-style `clone` + `wait4` + `execve` — shells, make, Ailang/gcc.
3. `futex` + `rt_sigaction` (no-op install often enough).
4. ioctl / TTY / sockets — only after the 90% table is mostly green.

Ailang-built Linux toolchain is the right “wild” test after spawn +
`fcntl`, not before.
