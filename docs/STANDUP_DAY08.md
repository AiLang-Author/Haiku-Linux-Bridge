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

### Next steps
1. Figure out the rseq-adjacent userspace death (TCB layout vs fake rseq).
2. Then `write` of `BUSYBOX_ECHO` should be one stub away.
3. ioctl still deferred.
