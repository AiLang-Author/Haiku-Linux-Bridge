# Developer standup: Day 56

**Module:** `sys_compat` syscall trap
**License:** Public Domain / CC0 1.0 Universal
**Pickup:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)
**Testers:** [STATUS.md](STATUS.md)
**Punch-out:** [CLI_APPLET_PUNCHOUT.md](CLI_APPLET_PUNCHOUT.md)

### What landed (PR52)

glibc `pthread_create` clone flags are guest-green:

`CLONE_VM|FS|FILES|SIGHAND|THREAD|SYSVSEM|SETTLS|PARENT_SETTID|CHILD_CLEARTID`
(`0x3d0f00`).

Same-team `spawn_thread` already shares cwd and the fd table. Signal
handlers are the existing stubs. `CLONE_THREAD` without `CLONE_SIGHAND`
is now `-EINVAL` (Linux). `hello_clonethr` gained `CLONE_SIGHAND`.

| Change | Why |
|---|---|
| Accept FS/FILES/SIGHAND/SYSVSEM on the VM path | glibc pthread_create always sets them |
| `THREAD` without `SIGHAND` → `-EINVAL` | Linux `copy_process` |
| Shared-pipe write in `hello_clonept` | `CLONE_FILES` is real (same `io_context`) |

Do not implement a second fd table. Do not import Linux `n_tty`.

### Guest-proven

```
FORKOK          FORK_RC=0
CLONEEXOK       CLONEVM_RC=0
CLONETLSOK      CLONETLS_RC=0
CLONETHROK      CLONETHR_RC=0
CLONEPTOK       CLONEPT_RC=0
```

COM1: `FL=0x00000000003d0f00` then `CK` `TC` `FS0` `XTX` `Vv` `W` `EEX 0`.
Banner `PR52`. No KDL.

### Do not

- Unmark CR3 on extra-thread `exit`(60).
- `_user_fork` for `CLONE_VM`.
- `_user_wait_for_objects` from C.

### Next

A real glibc-static `pthread_create` binary (not just the flag word).
Ash fd 0 blocking still the tty stub. More ioctl cmds as ELFs issue them.
