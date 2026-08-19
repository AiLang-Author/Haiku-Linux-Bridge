# Developer standup: Day 45

**Module:** `sys_compat` syscall trap
**License:** Public Domain / CC0 1.0 Universal
**Pickup:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)
**Testers:** [STATUS.md](STATUS.md)
**Punch-out:** [CLI_APPLET_PUNCHOUT.md](CLI_APPLET_PUNCHOUT.md)

### What landed (PR39)

Linux `ioctl` is no longer a stub `isatty=true`. The trap calls Haiku
`_user_ioctl` (syscall 0x99) and translates TTY payloads.

| Linux | Haiku | Buffer |
|---|---|---|
| `TCGETS`/`TCSETS`/`TCSETSW`/`TCSETSF` | `TCGETA`/`TCSETA`/`TCSETAW`/`TCSETAF` | termios (flags + `c_cc`) |
| `TIOCGWINSZ`/`TIOCSWINSZ` | `0x800C`/`0x800D` | `winsize` 8 B (same layout) |
| `TIOCGPGRP`/`TIOCSPGRP`/`TIOCSCTTY` | `0x800F`/`0x8010`/`0x8011` | `pid` 4 B |
| `FIONREAD`/`FIONBIO` | `0xbe000001`/`0xbe000000` | `int` 4 B |
| anything else | — | `-ENOTTY` |

### Guest-proven

`sh /boot/home/run_tty.sh` (not piped — a curl pipe makes fd0 a pipe):

| Probe | Result |
|---|---|
| `ioctl(0, TCGETS)` | **`TTY0=0`**, `LFLAG0=0x5b` (ISIG\|ICANON\|ECHO\|ECHOE\|ECHONL) |
| `ioctl(0, TIOCGWINSZ)` | **`WINSZ0=0 r=25 c=80`** |
| `ioctl(0, TIOCGPGRP)` | **`PGRP0=0 pgid=691`** |
| `ioctl(1, TCGETS)` on the redirect file | fails (not a tty) |
| busybox `date -u` | still prints a UTC line |

COM1: `I` breadcrumbs, last `ax=0xe7`. Banner `PR39`, `IOCTLfn=` set.
`driverinstall` re-hooks LSTAR on this image; Haiku has no `reboot(1)`.

### Do not

- Stub `TCGETS` as 0 without filling termios.
- Pipe the tty script into `sh` (`curl \| sh` steals stdin).
- Treat this as real termios for a Linux PTY stack — it is Haiku's tty.

### Next

fbdev ioctl onto Haiku graphics (not DRM). Then other ioctl families.
