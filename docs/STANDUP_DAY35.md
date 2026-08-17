# Developer standup: Day 35

**Module:** `sys_compat` syscall trap (no ioctl layer)
**License:** Public Domain / CC0 1.0 Universal
**Pickup:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)
**Testers:** [STATUS.md](STATUS.md)

Two guest-side quality-of-life / harness holes:

1. Desktop login now starts Terminal by itself
   (`~/config/settings/boot/UserBootscript`).
2. LTP `setpgid(0,0)` is stubbed to 0. `uname01` no longer TBROKs
   there.

### Proof (guest 2026-08-16, PR3)

| Test | Result |
|---|---|
| `UserBootscript` | `AUTOTERM_INSTALLED` (`SYS_COMPAT_AUTOTERM`) |
| `hello_wstat` | `WSTATOK` |
| `hello_mmapf` | `MMAPFOK` |
| `sh -c 'echo HI \| cat'` | `HI` `PIPE_RC=0` |
| LTP `uname01` | `TPASS uname(&un)` `TPASS sysname set to Linux`. **passed 2 / broken 0**. Then Kill Thread on teardown (`UNAME_RC=149`). |

No `setpgid` `ENOSYS` in this run.

### Do not

- Put test runners in `UserBootscript` (Terminal only).
- Treat `UNAME_RC=149` as a failed uname — the child already printed
  the summary. Teardown/exit is the next hole.

### Next

1. Why the parent/team Kill Threads after a green `uname01` summary.
2. ioctl / TTY still deferred.
