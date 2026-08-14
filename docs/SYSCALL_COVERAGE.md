# Core 90% Linux syscall set

**Last updated:** 2026-08-14

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
| 9 | mmap | works (ANON arena) |
| 10 | mprotect | works |
| 11 | munmap | works |
| 218 | set_tid_address | works |
| 273 | set_robust_list | works |
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
| 110 | getppid | wired |
| 231/60 | exit_group/exit | works |

### File I/O (coreutils hot path)

| # | name | status |
|---|---|---|
| 0 | read | works |
| 1 | write | works |
| 2 | open | works |
| 257 | openat | works |
| 3 | close | works |
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
| 72 | fcntl | **missing** (coreutils uses it) |
| 332 | statx | **missing** (modern coreutils) |
| 221 | fadvise64 | **missing** (hint only) |
| 25 | mremap | **missing** |
| 269 | faccessat | **missing** (openat-era access) |

### Time

| # | name | status |
|---|---|---|
| 228/403 | clock_gettime / clock_gettime64 | **works** (`_kern_get_clock` 0xc0). `hello_date` DATEOK. |
| 201 | time | **works** |
| 96 | gettimeofday | **works**. busybox `date` → Fri Aug 14 18:17:47 UTC 2026 |
| 35 | nanosleep | wired (returns 0) |
| 230 | clock_nanosleep | **missing** |

### Process spawn (LTP / shells / make)

| # | name | status |
|---|---|---|
| 56/57/58 | clone/fork/vfork | wired, **unproven** (fork-style only) |
| 61 | wait4 | wired, **unproven** |
| 59 | execve | **missing** |
| 202 | futex | **missing** (pthread) |

### Pipes / poll (pipelines, more applets)

| # | name | status |
|---|---|---|
| 22/293 | pipe/pipe2 | wired |
| 7 | poll | **missing** |
| 23/270 | select/pselect6 | **missing** |
| 271 | ppoll | **missing** |

### Signals (many binaries install handlers and ignore them)

| # | name | status |
|---|---|---|
| 13 | rt_sigaction | **missing** |
| 14 | rt_sigprocmask | **missing** |
| 15 | rt_sigreturn | **missing** |

### Intentionally later

ioctl (TTY/sockets), socket/connect/bind/listen/accept, clone(CLONE_VM),
ptrace, mount, bpf, io_uring, inotify, epoll, mmap of files.

## Score

Approximate unique Linux numbers we **dispatch to something other than
ENOSYS**: ~90 (including stubs).

**Guest-proven useful**: ~70.

**Wired this cut, not yet guest-proven**: time, gettimeofday, clock via
`_kern_get_clock`, pread64/pwrite64, writev/readv, getppid, pipe/pipe2,
nanosleep.

**Highest remaining for “coreutils in the wild”:** `fcntl`, `statx`,
`execve`+fork/wait (already in tree), `futex`, `poll`/`ppoll`,
`rt_sigaction` (no-op install is often enough), file `mmap`.

When those plus the wired-but-unproven rows are guest-green, the layer is
ready to try an Ailang-built Linux compiler/toolchain and only then ioctl.
