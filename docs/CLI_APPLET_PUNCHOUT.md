# CLI applet punch-out

**Updated:** 2026-08-19 (Day 44: redirected `date`/`md5sum`/`puts` write)

**License:** Public Domain / CC0 1.0 Universal
**Goal:** run static Linux CLI and toolchain programs on Haiku without
rewriting them. Not “random Linux packages people download.”
**Guest:** 2026-08-18/19, PR32, busybox 1.36.1 static.
**Battery log:** guest `applets_out.txt` (58 invocations). No Kill Thread, no KDL.
**Status log:** `guest_run_status.sh` POSTed via Haiku curl (BSD sockets). `OK`.

The “~90 syscalls” number was a hipshot. Host `strace -c` of this same
applet set hits **55 unique Linux syscalls**.

## What the battery was

58 invocations of unmodified `busybox` via `sys_compat_run`. POSIX CLI
plus the file/process surface a compiler driver actually uses. No TTY,
no fbdev, no network inside the Linux ELF, no `vi`.

Haiku itself talks to the host with **curl** (`10.0.2.2:8083`). That is
Haiku’s curl on BSD sockets, not the Linux ABI.

## Works (stdout/stderr matched the job)

| Applet | Evidence |
|---|---|
| `echo` | printed `hello` |
| `uname -a` | `Linux haiku 6.1.0 sys_compat x86_64 GNU/Linux` |
| `cat` | file contents |
| `ls -l` | `total 20` + names |
| `cp` `mv` `ln` `touch` `rm` `mkdir` `rmdir` `chmod` | RC=0, no error |
| `awk '{print $1}'` | `hello` / `foo` / `hello` / `zzz` |
| `head` `sort` `uniq` `tee` | expected lines |
| `dd` | `2+0 records in/out` |
| `expr 1 + 2` | `3` |
| `seq 1 3` | `1 2 3` |
| `sh -c 'echo A; echo B'` | `A` / `B` |
| `sh -c 'echo hi > f && cat f'` | `hi` (and a second `sys_compat_run` for `cat`) |
| `test -f` | RC=0 (true) |
| `sleep 0` `true` `printf` `dirname` `basename` `pwd` | RC=0 |
| `false` | **`FALSE_RC=1`** (Day 42) |
| `cmp` (stderr) | `cmp: EOF on …`, **`CMP_RC=1`** (Day 42) |
| `id` | **PR32:** `uid=0(user) gid=0(root) groups=0(root)` |
| glibc `puts` | **`PRINTF_OK`** (Day 44) |
| `date -u` | **`Wed Nov 15 04:41:07 UTC 2023`** in the redirect (Day 44) |
| `md5sum` | **`56b119667b17e283b4c3535154b59aa7`** host match (Day 44) |
| `nproc` | **`1`** (affinity stub is one CPU; stdout now lands) |
| `printf` | **`BBPRINTF_OK`** |

## Fragile / wrong (punch these before a toolchain)

| Hole | What we saw | Why it matters |
|---|---|---|
| **`ioctl` still `-ENOTTY`** (except `TCGETS`/`TIOCGWINSZ` = 0) | not blocking redirected CLI stdout | Next slice: real TTY / fbdev onto Haiku drivers. |
| **`sched_getaffinity` one CPU** | `nproc` prints `1` on QEMU `-smp 4` | Fine for CLI; wrong for parallel make later. |
| **`umask` / `sync` (162)** | Wired in the trap; not in the status script | Host applets issue them. |
| **`rt_sigreturn` `-ENOSYS`** | host glibc/busybox traces it | Fine while signals are stubs. |
| **`sendfile` pipe `-EINVAL`** | Linux-correct; `cat` uses read/write | Leave it. |
| **Pipe child stdout** | `echo HI \| cat` was RC=0 with `HI` missing **before** Day 44. Re-prove after rdx=0. | Do not treat pipelines as fully proven until re-run. |

## Not a layer bug

This busybox `ar` is extract-only (`ar x\|p\|t`). `-r`/`-c` is invalid on
this build. Need a real `ar` later for `.a` files, or a different busybox
config.

## Syscall boundary (measured, this battery)

55 unique Linux names on the host. Rough split against the trap:

| In the trap and used here | Missing / stub vs this trace |
|---|---|
| arch_prctl, brk, mmap, mprotect, munmap, openat, read, write, close, lseek, fstat, newfstatat, getdents64, fcntl, ftruncate, mkdir, rmdir, unlink, rename, symlink, readlink/readlinkat, chmod, utimensat, getcwd, clone, execve, wait4, pipe2, dup2/dup3, prctl, prlimit64, rseq, set_robust_list, set_tid_address, getuid/euid/gid/egid, setuid/setgid, uname, getrandom, clock_nanosleep | ioctl (still `-ENOTTY`), rt_sigreturn (ENOSYS), sendfile (EINVAL on pipes). PR32 added getgroups (guest-green), umask, sync, sched_getaffinity (wired). |

So the CLI surface is about **fifty** syscalls, not ninety.
The extra rows in `SYSCALL_COVERAGE.md` are still useful (statx, poll, …)
but they are not what this busybox set exercises.

## Day 40 trap changes

- Close after `ND` returns (`cS` + `.Lret`). `.Lexit` only from
  `exit`/`exit_group`, with the real rdi.
- After `ND`, `write` is `_user_write` on `gs:8` so `fflush` can land.
- `getgroups`, `umask`, `sync`, `sched_getaffinity` wired.
- Guest-reprove: `id` groups green. `false` / redirected `date` still not.

## Day 44 trap changes

- After mark, `rdx=0` before `jmp` Linux `_start`. `rdx` is `rtld_fini`;
  the fork tramp was xor-edi / `SYS_exit` 60 and skipped `fflush`.
- Mark sysret also zeros `rdx`. Guest-proven with loader xor only
  (hook still PR37 until reboot).

## Next

1. Real TTY/fbdev ioctl onto Haiku drivers (not a Linux display stack). `TCGETS` is only `isatty`=true.
2. Re-prove `echo HI | cat` in a redirect now that FILE* flush works.
3. Do not expand into distro packages or pthreads until TTY is green enough for interactive `sh`.

`false` / `cmp` `$?` is guest-green (Day 42). Redirected `date` /
`md5sum` / glibc `puts` are guest-green (Day 44).

Scripts: `scripts/catalog_applet_syscalls.sh` (host),
`scripts/guest_run_applets.sh` (guest battery),
`scripts/guest_run_status.sh` (status+flush). Guest fetch/POST is
Haiku curl: `curl -s --max-time 8` to `http://10.0.2.2:8083/`.
