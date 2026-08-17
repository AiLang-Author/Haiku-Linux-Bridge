# Developer standup: Day 34

**Module:** `sys_compat` syscall trap (no ioctl layer)
**License:** Public Domain / CC0 1.0 Universal
**Pickup:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)
**Testers:** [STATUS.md](STATUS.md)

LTP `uname01` is past `/proc/meminfo`. The uname test itself
**TPASS**es. The harness then `TBROK`s on `setpgid(0,0)` (`ENOSYS`)
and the team gets a Kill Thread (not a KDL).

### What changed

`fopen("/proc/meminfo")` went to Haiku `_kern_open` and came back as
a raw `status_t`. glibc did not treat that as `-ENOENT`, so LTP
printed `SUCCESS (0)`.

We intercept `open`/`openat` of `/proc…` and `/sys…` only (first
four path bytes). Known nodes (`/proc/meminfo`, `/proc/cpuinfo`,
`/proc/stat`) are written into `/tmp/.linux_proc` via `_user_open` +
`_user_write` on the reserved arena page, then unlinked. The fd is
a real team fd, so `read`/`fstat`/`close` stay on the existing
LSTAR remaps.

Regular files stay on the old LSTAR open. Putting **every** open
through `CALL_C` / `gKstack` raced LTP `fork_testrun`'s `wait4`
and Kill-Threaded.

`setpgid` / `getpgrp` / `getpgid` are stubbed (0 / pid). Not yet
guest-proven (Terminal wedged after the last KT).

### Proof (guest 2026-08-16, PR2)

| Test | Result |
|---|---|
| `hello_wstat` | `WSTATOK` `WSTAT_RC=0` |
| `hello_mmapf` | `MMAPFOK` `MMAPF_RC=0` |
| `sh -c 'echo HI \| cat'` | `HI` `PIPE_RC=0` |
| LTP `uname01` | `TPASS uname(&un)` `TPASS sysname set to Linux`. Harness `TBROK setpgid ENOSYS`. `UNAME_RC=149` (Kill Thread after). |

COM1: `PR2` `OPENfn=0xffffffff80105660` `PO` ×3 (meminfo).

### Do not

- `CALL_C` every Linux `open` (gKstack vs clone parent `wait4`).
- Return a fake fd that is not in the team's io context.
- Bounce `/proc` content through `gSavedRsp`.

### Next

1. Guest-prove `setpgid` stub — should clear the harness TBROK.
2. ioctl / TTY still deferred.
