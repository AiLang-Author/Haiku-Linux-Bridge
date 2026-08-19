# Developer standup: Day 44

**Module:** `sys_compat` syscall trap
**License:** Public Domain / CC0 1.0 Universal
**Pickup:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)
**Testers:** [STATUS.md](STATUS.md)
**Punch-out:** [CLI_APPLET_PUNCHOUT.md](CLI_APPLET_PUNCHOUT.md)

### What landed (PR38)

Redirected glibc `puts` / busybox `date` never `write`d. Raw `hello_wr`
did. Last syscall was `SYS_exit` 60 (`ax=0x3c`), not `exit_group` 231.

Linux `_start` does `mov %rdx,%r9` (`rtld_fini`). Mark passed the fork
IRETQ tramp in `rdx` (xor-edi / `SYS_exit` 60). glibc `exit()` called
that tramp **before** `_IO_cleanup` / `fflush`. FILE* bytes died in the
buffer. Direct `write()` in `main` had already landed, so echo/clock/wr
looked fine.

| Change | Why |
|---|---|
| `xor %edx,%edx` after mark, before `jmp` entry | Static Linux `_start` must see `rtld_fini=NULL` |
| Mark sysret also zeros `rdx` | Same ABI if another loader marks |
| Banner `PR38` | Next reboot loads the hook; loader-only is live now |

### Guest-proven (loader xor, still PR37 hook)

| Probe | Result |
|---|---|
| glibc `puts` | **`PRINTF_OK`**, `PRINTF_RC=0` |
| `hello_clock` | `T=1700022793`, `CLOCK_RC=0` |
| `hello_wr` | **`WRPROBE`**, `WR_RC=0` |
| busybox `printf '%s\n' BBPRINTF_OK` | **`BBPRINTF_OK`** |
| busybox `date -u` | **`Wed Nov 15 04:41:07 UTC 2023`**, `DATE_RC=0` |
| busybox `md5sum /tmp/punch.txt` | **`56b119667b17e283b4c3535154b59aa7`** (host match), `MD5_RC=0` |
| busybox `nproc` | **`1`**, `NPROC_RC=0` |
| busybox `false` | **`FALSE_RC=1`** |
| busybox `cmp` (differ) | stderr line, **`CMP_RC=1`** |

Serial after the fix: last `ax=0xe7` (`exit_group`). `date`/`md5sum`
now have a `W`. RTC in this QEMU is Nov 2023 — that is the clock, not
a silent stdout.

### Do not

- Pass the fork tramp in `rdx` into Linux `_start`.
- Treat `ioctl` `TCGETS` as the FILE* flush fix (it was not).
- Restore callee-saved from the global `gSavedR*`.

### Next

Real TTY/fbdev ioctl onto Haiku drivers (not a Linux display stack).
`nproc` printing `1` on `-smp 4` is `sched_getaffinity` still one CPU
bit — later, not blocking CLI stdout.
