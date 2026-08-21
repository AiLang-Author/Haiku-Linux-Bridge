# Developer standup: Day 49

**Module:** `sys_compat` syscall trap
**License:** Public Domain / CC0 1.0 Universal
**Pickup:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)
**Testers:** [STATUS.md](STATUS.md)
**Punch-out:** [CLI_APPLET_PUNCHOUT.md](CLI_APPLET_PUNCHOUT.md)

### What landed

Re-prove `echo HI | cat` after Day 48 poll. No trap change.

| Command | Result |
|---|---|
| `sh -c 'echo SHOK'` | `SHOK`, `SH_ECHO_RC=0` |
| `sh -c 'echo HI \| cat'` | `HI`, `SH_PIPE_RC=0` |
| same, Haiku-redirected | `HI` in `/tmp/pipe_redir.txt`, `SH_PIPE_REDIR_RC=0` |
| `sh -c 'true; echo SHDONE'` | `SHDONE`, `SH_TRUE_RC=0` |

No KDL. COM1 `EEX` `ax=0xe7` (`exit_group`). Child execve of `busybox cat` still runs.

### Do not

- Treat the loader `[+]` lines in a Haiku redirect as Linux stdout. `HI` is the applet line.
- `_user_wait_for_objects` from C (Day 48 KDL).

### Next

Blocking ELF `poll(..., -1)` is `wait_for_objects_etc`. Ash `nfds==1` still stubs.
`CLONE_VM` later.
