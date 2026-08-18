# Core 90% Linux syscall set

**Last updated:** 2026-08-18 (Day 39: uname01 UNAME_RC=0)

Linux has 300+ x86_64 syscall numbers. Roughly **80–100 of them** dominate
everyday CLI and statically-linked C programs (glibc startup + POSIX file
I/O + process/time). The rest is sockets, aio, io_uring, namespaces, bpf,
and other edges.

This is the hand-off list: if a row is **works**, the layer is ready to
take unmodified Linux coreutils/busybox-class binaries. **ioctl** stays
deferred until this table is mostly green.

## Where the list comes from

No single kernel “audit file” names the 90% set. These do:

| Source | What it shows |
|---|---|
| Host `strace` of this tree’s static `busybox` (`date`, `id`, `pwd`, `true`, `cp`, `ls`) | Real glibc-static startup + applet syscalls |
| Host `strace` of GNU coreutils (`ls cat cp mv rm mkdir ln touch stat …`) | `openat`/`close`/`mmap`/`pread64`/`statx` dominate |
| Observed glibc-static startup on this layer | `arch_prctl`, `rseq`, `set_tid_address`, `set_robust_list`, `prctl`, `prlimit64`, `getrandom`, `readlinkat` |
| POSIX file/process/time (what coreutils actually is) | rename/symlink/readlink/wait/fork/clock |
| gVisor / FreeBSD linuxulator “basic UNIX” implementations | Same ~80 names, independently |

vdso note: on real Linux, `clock_gettime` often never enters the kernel.
On this layer there is no vdso, so `date` must hit `time` / `gettimeofday`
/ `clock_gettime` as real syscalls.

## The ~90

Status: **works** (guest-proven), **wired** (implemented, not yet guest-proven),
**stub** (returns 0 / `-ENOTTY` / fake), **missing** (`-ENOSYS`).

### glibc / process startup (must not ENOSYS)

| # | name | status |
|---|---|---|
| 158 | arch_prctl | works |
| 12 | brk | works |
| 9 | mmap | **works** (ANON arena + file via kernel `vm_map_file` / `_vm_map_file(..., false)`). `hello_mmapf` `MMAPFOK`. Day 32. |
| 10 | mprotect | works |
| 11 | munmap | **works** for tracked `linux_mmap` via `vm_delete_area(team)` (`VD`/`ND`). Never `_user_unmap_memory` (`cuU` KT). Hook sets `sExitCloses` on `ND`. Day 38. |
| 218 | set_tid_address | works |
| 273 | set_robust_list | works (in-hook store, rdx kept). `get_robust_list` 274 wired. Day 37. |
| 334 | rseq | works |
| 157 | prctl | works |
| 302 | prlimit64 | stub (fill 8MB/∞) |
| 318 | getrandom | stub (rdtsc, ≤8 bytes) |
| 267 | readlinkat | works |
| 63 | uname | works |
| 102/107 | getuid/geteuid | works |
| 104/108 | getgid/getegid | works |
| 105/106 | setuid/setgid | works (layer-local) |
| 186 | gettid | works |
| 39 | getpid | wired (unproven) |
| 109 | setpgid | stub (0). Guest: `uname01` no longer TBROK. Day 35. |
| 62/200/234 | kill/tkill/tgkill | stub (0). COM1 `k`. Do not identity-pass (Haiku 62 ≠ kill). Day 36. |
| 110 | getppid | wired |
| 111 | getpgrp | stub (pid) |
| 121 | getpgid | stub (pid) |
| 231/60 | exit_group/exit | **works**. After `ND`, `_user_exit_team` + `thread_exit` (not LSTAR `0x29`). `UNAME_RC=0`. Day 39. |

### File I/O (coreutils hot path)

| # | name | status |
|---|---|---|
| 0 | read | works |
| 1 | write | works |
| 2 | open | works (`/proc/meminfo` materialized; other `/proc`/`/sys` `-ENOENT`) |
| 257 | openat | works (same) |
| 3 | close | works (identity `_kern_close` 0x9e). After `ND`, skip `_user_close` (`cS`) and `.Lexit`. Day 39. |
| 8 | lseek | works |
| 5 | fstat | works |
| 4/6 | stat/lstat | works |
| 262 | newfstatat | works |
| 217 | getdents64 | works |
| 17/18 | pread64/pwrite64 | wired |
| 19/20 | writev/readv | wired |
| 21 | access | works |
| 79/80/81 | getcwd/chdir/fchdir | works |
| 83/258 | mkdir/mkdirat | works |
| 84/87/263 | rmdir/unlink/unlinkat | works |
| 82/264/316 | rename/renameat/renameat2 | works |
| 88/266 | symlink/symlinkat | works |
| 89 | readlink | works |
| 86/265 | link/linkat | wired (EPERM on some volumes) |
| 90/91/268 | chmod/fchmod/fchmodat | works |
| 92/93/94/260 | chown family | works |
| 76/77 | truncate/ftruncate | works |
| 74/75 | fsync/fdatasync | works |
| 280 | utimensat | works |
| 32/33/292 | dup/dup2/dup3 | works |
| 16 | ioctl | stub `-ENOTTY` |
| 72 | fcntl | **works** (`_kern_fcntl` 0x76; F_DUPFD/GETFD/SETFD/GETFL/SETFL/DUPFD_CLOEXEC; flag xlat) |
| 332 | statx | **works** (`_kern_read_stat` → 256-byte `statx`; BASIC\|BTIME) |
| 221 | fadvise64 | **works** (hint, return 0) |
| 25 | mremap | **-ENOSYS** (marked path, never Haiku identity) |
| 269 | faccessat | **wired** (AT_FDCWD + access helper) |

### Time

| # | name | status |
|---|---|---|
| 228/403 | clock_gettime / clock_gettime64 | **works** (`_kern_get_clock` 0xc0). `hello_date` DATEOK. |
| 201 | time | **works** |
| 96 | gettimeofday | **works**. busybox `date` → Fri Aug 14 18:17:47 UTC 2026 |
| 35 | nanosleep | wired (returns 0) |
| 230 | clock_nanosleep | **wired** (same helper as nanosleep) |
| 26 | msync | stub (0). Day 36. |
| 37/38 | alarm/setitimer | stub (0). Day 36. |

### Process spawn (LTP / shells / make)

| # | name | status |
|---|---|---|
| 56/57/58 | clone/fork/vfork | **works** (`_user_fork`). Child IRETQ to `0x40101c`. `hello_fork` `FORKOK`. Day 20–21. |
| 61 | wait4 | **works**. Parent `Vv` + `FORKOK`. Day 20. |
| 59 | execve | **works**. `_user_exec` 0x2e of `sys_compat_run <path>`. `hello_exec` → `hello_min`, `EXEC_RC=0`. Day 22. |
| 202 | futex | **works** (WAIT/WAKE/BITSET; REQUEUE-as-wake). `hello_futex` `FUTEXOK`. Day 23. |

### Pipes / poll (pipelines, more applets)

| # | name | status |
|---|---|---|
| 22/293 | pipe/pipe2 | **works**. `sh -c 'echo HI \| cat'` `SH_PIPE_RC=0`. Day 31. |
| 40 | sendfile | **pipe = `-EINVAL`** (Linux: `in_fd` must be mmapable). busybox `cat` then `read`/`write`. Regular-file bounce later. |
| 7 | poll | **works**. `_user_wait_for_objects` 0x06. `hello_poll` `POLLOK`. Day 24. |
| 23/270 | select/pselect6 | **works**. fd_set → poll. `hello_select` `SELECTOK`. Day 25. |
| 271 | ppoll | **works** (timespec → ms; sigset ignored). |

### Signals (many binaries install handlers and ignore them)

| # | name | status |
|---|---|---|
| 13 | rt_sigaction | **stub** (return 0 — glibc install-and-ignore) |
| 14 | rt_sigprocmask | **stub** (return 0) |
| 15 | rt_sigreturn | **-ENOSYS** |
| 62/200/234 | kill/tkill/tgkill | **stub** (return 0). LTP heartbeat. Day 36. |

### Intentionally later

ioctl (TTY/sockets), socket/connect/bind/listen/accept, clone(CLONE_VM),
ptrace, mount, bpf, io_uring, inotify, epoll.

## Score

Approximate unique Linux numbers we **dispatch to something other than
ENOSYS**: ~90 (including stubs).

**Guest-proven useful**: ~78. Unmodified busybox CLI that works as a
**single process** (no shell spawn): echo, uname, cat, ls, cp, mv,
ln -s, readlink, touch, rm, date, **grep, wc, sed, head, sort, cut**.

`clone`/`fork`/`wait4`/`exit` from a **marked** Linux team: `hello_fork`
prints `FORKOK`, `FORK_RC=0` (Day 20–21). Both parent and child IRETQ
to Linux `0x40101c`. Stamp-on-fork is RIP-guarded (ELF/tramp only).
`execve` from a marked team: `hello_exec` replaced itself with
`hello_min` (`EXEC_RC=0`, Day 22). Flatten + `_user_exec` of
`sys_compat_run`; unmark first so the loader is Haiku.
Single-process grep/sed/wc do **not** need spawn. Pipelines and shells do.
Linux `exit`=60 is Haiku `_kern_cancel_thread` — do not pass an unmarked
child's exit through. Rare/deprecated syscalls wait for a filed issue.

**Wired, not separately guest-proven**: pread64/pwrite64, writev/readv,
getppid, nanosleep.

**Highest remaining for “coreutils in the wild”:** interactive TTY
`sh` (ioctl), then `CLONE_VM` (pthread). `hello_pipeline` is
guest-green (`PIPELINEOK`, Day 26). `sh -c 'echo HI | cat'` prints
`HI`, `SH_PIPE_RC=0` (Day 31). Testers should start from
[STATUS.md](STATUS.md), not this table.

When those plus the wired-but-unproven rows are guest-green, the layer is
ready to try an Ailang-built Linux compiler/toolchain and only then ioctl.
