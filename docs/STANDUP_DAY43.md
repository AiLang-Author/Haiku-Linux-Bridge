# Developer standup: Day 43

**Module:** `sys_compat` syscall trap
**License:** Public Domain / CC0 1.0 Universal
**Pickup:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)
**Testers:** [STATUS.md](STATUS.md)
**Punch-out:** [CLI_APPLET_PUNCHOUT.md](CLI_APPLET_PUNCHOUT.md)

### What landed (PR36–37)

Redirected `date` was silent. A last `write` then `_user_exit_team` /
SIGKILL was the first suspect.

| Change | Why |
|---|---|
| `fsync(1)` / `fsync(2)` in `sys_compat_exit_team` | Commit bytes before SIGKILL |
| COM1 `EX … ax=<last Linux nr>` | See whether the last call was `write` / `exit` / `exit_group` |
| `ioctl` `TCGETS` (0x5401) / `TIOCGWINSZ` (0x5413) return 0 | `isatty` → line-buffered stdio |
| `tests/hello_wr.s` | Raw `write(1,"WRPROBE\n")` then `exit_group(0)` |

### Guest-proven

| Probe | Result |
|---|---|
| `hello_wr` | **`WRPROBE` in the redirect**, `WR_RC=0`, last `ax=0xe7` (`exit_group`) |
| busybox `echo ECHO_STILL` | printed, last `ax=0x3c` (`exit`) |
| busybox `date -u` | `DATE_RC=0`, **still no date line**. Serial `mQbet` (**no `W`**), last `ax=0x3c` |
| busybox `md5sum` | `MD5_RC=0`, no digest. Serial `mQbcet` (close, no write) |

So a last kernel `write` **does** survive teardown (`WRPROBE`). `date` never
issues `write` at all — not a dropped-flush of a successful `write`.
glibc `exit()` here is `SYS_exit` (60), and `date` never `printf`s (or
never flushes) before that.

Always-C `_user_write` was tried; `date` still had no `W`. Reverted to
identity write except after `ND`.

### Do not

- Treat `ioctl` `TCGETS` as a real termios (buffer is not filled).
- Assume `ax=0x3c` means the trap lost a `write` — there was no `W`.

### Next

Why busybox `date` / `md5sum` never `write` on a redirected fd (host of
the same ELF does `write` then `exit_group`). Then real TTY/fbdev ioctl
onto Haiku drivers.
