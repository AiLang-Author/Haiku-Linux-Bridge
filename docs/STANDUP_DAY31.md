# Developer standup: Day 31

**Module:** `sys_compat` syscall trap (no ioctl layer)
**License:** Public Domain / CC0 1.0 Universal
**Pickup:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)
**Testers:** [STATUS.md](STATUS.md)

`sh -c 'echo HI | cat'` is guest-green. `SHOK`, `HI`, `SHDONE`,
`SH_PIPE_RC=0`, no Kill Thread, desktop up.

### What was actually true after Day 30 `XEC`

1. **Same-page exec scratch + per-thread C stack (EX2).**
   Flatten at user `RSP-8192` hung in `user_memcpy` (COW-RO).
   `RSP-512` (same page as `…778`) plus `try_fork`/`wait4`/`execve`
   C on `gs:8-0xA00` (not the one global `gKstack`) reached
   `_kern_exec` (`XGO`) and a new marked team.
2. **`sendfile` bounce at `RSP-4096` (EX2).** Host `strace` of
   static busybox `cat` does `sendfile(1, 0, NULL, 16M)` on the
   pipe. Our bounce wrote `HI` via `_kern_write` then smashed
   cat's stack → Kill Thread after `mQbB`.
3. **`sendfile` → `-EINVAL` (EX3).** Linux needs `in_fd` mmapable;
   a pipe is `EINVAL` and cat falls back to `read`/`write`. C
   returned `fSF` then cat still died.
4. **User `rbp` (EX4/EX5).** Linux `SYSCALL` must preserve `rbp`.
   Several C paths did `mov rbp, rsp` on the kstack and never
   restored it. After `sendfile` EINVAL, `cat_main` touched
   `[rbp]` → Kill Thread (`fSF`, no `W`). After cat exited
   (`fSF WeE`), parent `wait4` did the same → Kill Thread of
   `sh -c 'echo HI | cat'` even though `HI` was already in
   `sh_out`. EX5 push/pop `rbp` on `wait4`/`execve`/`futex`/
   `poll`/`select`/`mmap_file`/`sendfile`.

### Proof (guest 2026-08-16, EX5, fresh QEMU after the 10h cap)

`results/ltp/sh_out.txt`:

```
SHOK
SH_ECHO_RC=0
HI
SH_PIPE_RC=0
SHDONE
SH_TRUE_RC=0
```

COM1: two clones (`C123` `F2` `5R`), echo `WeE`, `XEC /boot/home/busybox`
`narg=1`, cat `mQbB` `WeE`, parent `v` `eE`, then `true` `gWeE`.
Desktop up, `RUN_SH_DONE`, no crash dialog.

### Do not

- Bounce kernel `_kern_read`/`_kern_write` onto the Linux stack.
- Clobber user `rbp`/`rbx`/`r12–15` on a path that `sysretq`s.
- Hold the parent until `set_robust`.
- Commit screenshots, serial logs, or ioctl stubs.

### Next

1. Regular-file `sendfile` with a reserved user page (not the stack).
2. Interactive TTY `sh` still needs ioctl — deferred.
3. LTP first-wave / more CLI. `CLONE_VM` later.
