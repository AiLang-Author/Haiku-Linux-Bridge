# CLI applet punch-out

**Updated:** 2026-08-19 (Day 41: `hello_exit` RC=42; busybox `false` still 0)

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
| `cmp` (stderr) | `cmp: EOF on …` — compared correctly |
| `id` | **PR32:** `uid=0(user) gid=0(root) groups=0(root)` |

`PIPE_RC` / `SHPIPE_RC` is 0. `HI` did not show in the redirected log
(same stdout-flush hole as below).

## Fragile / wrong (punch these before a toolchain)

| Hole | What we saw | Why it matters |
|---|---|---|
| **busybox still `exit_group(0)`** | Trap is cleared: `hello_exit` → **`EXIT42_RC=42`**, COM1 `EX 0x2a`. `false` / differing `cmp` still `EX 0x0` with argv `[busybox] [false]`. Host of the same ELF is `exit_group(1)`. | A compiler that runs `as`/`ld` and checks `$?` will treat busybox-style fails as success. |
| **Redirected stdout still missing** | `date`, `md5sum`, `nproc` printed nothing in the capture. `date` serial is `mQbWet` (a `write` then exit). `md5sum` is `mQbcet` (close, no write). Interactive `date` has printed a UTC line on earlier days. | Last writes of a compile step can vanish if they sat in libc `FILE*` buffers. |
| **`sched_getaffinity` unproven** | `nproc` silent, no write on COM1 | Host strace shows it. |
| **`umask` / `sync` (162)** | Wired in the trap; not in the status script | Host applets issue them. |
| **`ioctl` still `-ENOTTY`** | not blocking this battery | Next slice after exit/flush: TTY / fbdev. |
| **`rt_sigreturn` `-ENOSYS`** | host glibc/busybox traces it | Fine while signals are stubs. |
| **`sendfile` pipe `-EINVAL`** | Linux-correct; `cat` uses read/write | Leave it. |
| **Pipe child stdout** | `echo HI \| cat` RC=0, `HI` not in the capture | Same flush/status story; do not treat pipelines as fully proven. |

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

## Next

1. Why glibc-static busybox `false` / `cmp` issue `exit_group(0)` on
   the guest (host `exit_group(1)`). `hello_exit` proves the trap.
2. Why `write(1, …)` after glibc `fflush` does not appear in a Haiku redirect.
3. TTY / fbdev / ioctl onto Haiku drivers (not a Linux display stack).
4. Do not expand into distro packages or pthreads until 1 is green.

Scripts: `scripts/catalog_applet_syscalls.sh` (host),
`scripts/guest_run_applets.sh` (guest battery),
`scripts/guest_run_status.sh` (status+flush). Guest fetch/POST is
Haiku curl: `curl -s --max-time 8` to `http://10.0.2.2:8083/`.
