# Developer standup: Day 08

**Module:** `sys_compat` syscall trap (no ioctl layer)  
**License:** Public Domain / CC0 1.0 Universal  
**Pickup doc:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)

### Accomplishments
- [x] Method is now “read `seq=`, add a remap, reboot, re-run.” The LSTAR / mark / arena / SET_FS walls are behind us. `hello_min` + `hello_fs` stay green across rebuilds.
- [x] `write(LEAVEABI)` clears `gLinuxCR3`. A leftover Linux mark after Kill Thread reused CR3 and killed `make`. Do not skip this before a Haiku build.
- [x] Stubbed the rest of the host `busybox echo` syscall list: `prlimit64` (302), `getrandom` (318), `getuid`/`getgid`/`geteuid`/`getegid`, `setuid`/`setgid`, `prctl`, `newfstatat` → `-ENOENT`, `readlinkat` → `/boot/home/busybox`.
- [x] `rseq` (334) tried as `-ENOSYS` and as `0`. Both stop at `last=334 hits=11`. glibc never issues `prlimit64` (302). Userspace dies immediately after rseq.

### Blocker
busybox glibc-static still Kill Thread (not KDL) right after `rseq`. Wrapper shell stays up. Kernel stays up.

### Later the same day
- [x] Loader now builds a real Linux auxv (`AT_PHDR`, `AT_RANDOM`, `AT_UID`, …). hello_* never needed it; glibc-static busybox does.
- [x] SET_FS uses a shared `.Lapply_fs` (ULS + `wrmsr`). Re-applying that on **every** Linux syscall was pulled — a long `%fs` spin + extra `swapgs` left the desktop without a Terminal.
- busybox still last-seen at `rseq` (334) on the pre-auxv loader. Auxv change is in-tree, not yet proven to move `seq=` past 334.

### Next steps
1. Re-run busybox with the new auxv (no per-syscall FS hammer).
2. ioctl still deferred.
