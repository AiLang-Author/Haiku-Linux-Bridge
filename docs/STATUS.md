# Status for testers (2026-08-21, Day 49)

**Repo:** [https://github.com/AiLang-Author/Haiku-Linux-Bridge](https://github.com/AiLang-Author/Haiku-Linux-Bridge)
**License:** Public Domain / CC0 1.0 Universal
**What this is:** an out-of-tree Linux ABI for Haiku. Unmodified 64-bit Linux ELFs run on Haiku by trapping `syscall` and translating to `_kern_*`. No binary patching. No Linux kernel. No Linux userspace rewrite.

This page is the short public snapshot. Pickup / landmines for people hacking the trap: [`IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md). Per-syscall table: [`SYSCALL_COVERAGE.md`](SYSCALL_COVERAGE.md). Latest wrap: [`STANDUP_DAY49.md`](STANDUP_DAY49.md). Punch-out: [`CLI_APPLET_PUNCHOUT.md`](CLI_APPLET_PUNCHOUT.md).

**Please test. File issues.** The CLI 90% set is wide enough that outside binaries will find the next holes faster than we will.

---

## What you can expect today (`main`, Day 49)

The guest-proven path is **static 64-bit Linux ELFs** launched with `sys_compat_run`. The desktop and Haiku's own shell stay up if you do not mark a Haiku team as Linux.

| Works on the guest | How we know |
|---|---|
| Tiny Linux `write`/`exit` | `hello_min` prints, `DONE_RC=0` |
| File I/O, dirs, stat, chmod/chown/truncate, rename, symlink, time | `hello_wstat` `WSTATOK`; LTP `uname01` past `tst_tmpdir` |
| busybox **as a single process** | `echo`, `uname`, `cat`, `ls`, `cp`, `mv`, `ln -s`, `readlink`, `touch`, `rm`, `date`, `grep`, `sed`, `wc`, `head`, `sort`, `cut` |
| `clone`/`fork` + `wait4` | `hello_fork` → `FORKOK` |
| `execve` of another Linux ELF | `hello_exec` → `hello_min`, `EXEC_RC=0` |
| `futex` WAIT/WAKE | `hello_futex` → `FUTEXOK` |
| `poll` / `ppoll` / `select` | `SELECTOK`. ELF `poll(nfds==1)` `hello_poll` **`POLLOK`** (Day 48). Ash `nfds==1` still a no-copy stub |
| file `mmap` | `hello_mmapf` → `MMAPFOK` (kernel `vm_map_file`, not `_user_map_file`) |
| Combined `fork` + `execve` + `poll` | `hello_pipeline` → `PIPELINEOK` |
| busybox **`sh -c`** (builtin + pipe) | `echo SHOK`; `echo HI \| cat` → `HI` (`SH_PIPE_RC=0`); same in a Haiku redirect (`HI` in the file, Day 49); `true; echo SHDONE`. All RC=0. |
| Interactive busybox **ash** | Terminal prompt, **`echo SHLIVE`** (Day 47–48). Ash `poll(nfds=1)` still a no-copy stub |

`uname` reports `Linux haiku 6.1.0 sys_compat x86_64`. That is the layer talking, not a Linux kernel.

### In the shop, not a tester target yet

Interactive ash is guest-green (`echo SHLIVE`). ELF `hello_poll`
is **`POLLOK`** (Day 48: kernel `wait_for_objects_etc`, timeout 0
via a write flag). Ash `poll(nfds=1)` is still a no-copy stub.
`sendfile` of a regular file still returns
`-EINVAL` (pipe fallback is enough for `cat`). `munmap` of file maps is
`vm_delete_area(team)` (not `_user_unmap_memory`). LTP `uname01` is
**passed 2 / failed 0 / broken 0** and **`UNAME_RC=0`**. A 58-applet
busybox battery runs without KT/KDL. Host `strace` of that set is 55
Linux syscalls. `id` prints `groups=0(root)`. Tiny `hello_exit` is
**`EXIT42_RC=42`**. busybox **`false` exits 1**, differing **`cmp`
exits 1**. Raw `hello_wr` prints **`WRPROBE`** in a redirect.
Redirected glibc `puts` prints **`PRINTF_OK`**. busybox **`date -u`**,
**`md5sum`**, and **`nproc`** print in a Haiku redirect (Day 44: zero
`rdx` after mark so glibc `exit()` fflush runs). Guest scripts fetch
and POST with **Haiku curl** (BSD sockets) to the host at
`10.0.2.2:8083`. Desktop login starts one Terminal via `boot/launch`.
One `sys_compat` addon only.

Extra single-process applets: `id` (groups too), `pwd`, `true`,
`printf`, `dirname`, `basename`, `od`. `sys_compat_run` `$?` is
real for `hello_exit` (42), glibc `return 1`, and busybox `false` /
`cmp`. Redirected `date` / `md5sum` stdout now lands.

**Do not run `sh` pipes or glibc-static `clone` LTP on a build older
than Day 27.** A `.Lret` store into the rseq page under CLI KDLed
(`page fault, interrupts were disabled`). That store is gone on `main`.

---

## What will not work (do not file as new)

- **Dynamic glibc** (`ld-linux.so.2`) — not a supported target yet. Static first.
- **Linux `ioctl`** — TTY onto Haiku tty. fbdev `/dev/fb0` onto Haiku VESA (1280x800x32, mmap). Other families `-ENOTTY`.
- **`CLONE_VM` / pthreads** — `clone` without `CLONE_VM` only. A Linux `pthread_create` will `-ENOSYS`.
- **Real signals** — `rt_sigaction` / `rt_sigprocmask` return 0 and do nothing. `rt_sigreturn` is `-ENOSYS`.
- **Sockets, epoll, ptrace, namespaces, io_uring, bpf** — not implemented.
- **Interactive TTY `sh`** — busybox ash on a Haiku Terminal: prompt + `echo SHLIVE`. Ash `poll(nfds=1)` still does not copy the pollfd (that KDLd). ELF pipe `poll(nfds=1)` is `POLLOK`.
- **Marking a Haiku shell as Linux** — `echo LINUXABI > /dev/misc/sys_compat` from a Terminal you still want is a Kill Thread. That is expected.

A **Kill Thread** / “Oh no!” dialog on a Linux ELF is a layer bug (or an unmarked team). A **KDL** or silent reboot is a layer bug and a stop-the-line event. Haiku itself staying up is the contract.

---

## Quick test (Haiku guest or bare metal)

QEMU first. Bare metal only if you accept that a bad syscall hook can panic the box.

```bash
cd /boot/home
git clone https://github.com/AiLang-Author/Haiku-Linux-Bridge.git
cd Haiku-Linux-Bridge

make -f src/Makefile.driver
make -f src/Makefile.driver driverinstall
# reboot so /dev/misc/sys_compat appears

gcc -O2 src/sys_compat_run.c -o sys_compat_run
# hello_min is a Linux ELF — build it on Linux:
#   gcc -nostdlib -static -o tests/hello_min tests/hello_linux.s

./sys_compat_run ./tests/hello_min
```

Host-side QEMU (Linux):

```bash
./scripts/run_qemu.sh
python3 scripts/ltp_net_server.py &    # guest sees host as 10.0.2.2:8083
```

A useful first hour, all unmodified static Linux:

```bash
./sys_compat_run ./busybox echo hello
./sys_compat_run ./busybox uname -a
./sys_compat_run ./busybox ls -l /boot/home
./sys_compat_run ./busybox date -u
./sys_compat_run ./tests/hello_fork
./sys_compat_run ./tests/hello_pipeline
```

Bring your own **static** `busybox` or other static x86_64 Linux tools. Dynamic Debian/Fedora binaries are a later layer.

---

## How to file a useful bug

Open an issue on the GitHub repo. One failure per issue when you can.

**Subject:** the binary and the command, not “it crashed”.

Include:

1. **Command line** — exact `sys_compat_run …` invocation.
2. **Binary** — name, static vs dynamic (`file` output), where you got it, libc (musl / glibc-static). Attach the ELF if it is small and redistributable, or a link.
3. **Expected vs actual** — stdout, exit code, and whether the Haiku desktop survived.
4. **Failure class**
   - printed wrong / `-ENOSYS` / errno
   - Kill Thread / “Oh no!” / “Crashed program”
   - KDL (kernel debugger)
   - silent reboot (usually a triple fault)
5. **Haiku revision** — `uname -a` from a **Haiku** shell, plus whether this is QEMU or hardware.
6. **`cat /dev/misc/sys_compat`** after the run (mark / hit counters).
7. If you have COM1: the tail of `haiku_serial.log` around the failure. Letters like `F2` `F4` `5R` `S` `XEC` are the hook's breadcrumbs, not noise.

Haiku crash dialogs are scriptable. From another Terminal:

```bash
hey -o application/x-vnd.Haiku-debug_server quit of Window "Crashed program"
```

That dismisses the “Oh no!” window. It does not fix the underlying Kill Thread.

---

## What we will do with reports

- **ENOSYS on a CLI-hot syscall** — add it, or document why it is deferred (ioctl).
- **Wrong result, desktop up** — treat as a translate bug; those are the best reports.
- **Kill Thread on a marked Linux ELF** — usually a missed remap (Linux `write`=1 is Haiku `_kern_generic_syscall` if the team is unmarked).
- **KDL / reboot** — we stop feature work and fix the hook. Attach syslog / previous_syslog if you have it.
- **GUI Linux, Wine, browsers, games** — too early. The pyramid is syscall layer → CLI → later ioctl/drivers.

Rare or deprecated Linux numbers are fine as issues. We add them when someone actually hits them.

---

## Current pyramid

```
                    (later) ioctl / TTY / sockets / drivers
                 busybox sh + real pipelines     ← in progress
              fork+execve+poll  (PIPELINEOK)
           poll / select / file mmap / futex
        clone / wait4 / execve
     busybox single-process CLI
  file / stat / time / uid  (guest-green)
hello_min write+exit
```

If you only have time for one test, run `hello_pipeline` and one static busybox applet you actually use. If you have time for two, throw a static Linux tool we have never seen at `sys_compat_run` and tell us what syscall it died on.
