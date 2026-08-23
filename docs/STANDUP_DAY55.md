# Developer standup: Day 55

**Module:** `sys_compat` syscall trap
**License:** Public Domain / CC0 1.0 Universal
**Pickup:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)
**Testers:** [STATUS.md](STATUS.md)
**Punch-out:** [CLI_APPLET_PUNCHOUT.md](CLI_APPLET_PUNCHOUT.md)

### What landed (PR51)

`clone(CLONE_VM|CLONE_THREAD|SETTLS|PARENT_SETTID|CHILD_CLEARTID)`
is guest-green. Same-team spawn as Day 51–53. `wait4(tid, WNOHANG)`
returns `-ECHILD` (Linux: a thread is not a waitable child). Join is
`CLONE_CHILD_CLEARTID` (`ctid==0`), not `wait4`.

| Change | Why |
|---|---|
| Record every `clone_vm` tid in `sCloneT` | `wait4` must see it after CLEARTID is taken |
| `clone_t_take` keeps the tid | Slot was cleared before parent `wait4` |
| `wait4(pid>0)` + `clone_t_has` → `-ECHILD` | Haiku `wait_for_child(tid)` is the wrong object |

Do not `_user_fork` for `CLONE_VM`. Do not treat extra-thread `exit`(60)
as `exit_team`.

### Guest-proven

```
/boot/home/sys_compat_run /boot/home/hello_fork
FORKOK
FORK_RC=0

/boot/home/sys_compat_run /boot/home/hello_clonevm
CLONEEXOK
CLONEVM_RC=0

/boot/home/sys_compat_run /boot/home/hello_clonetls
CLONETLSOK
CLONETLS_RC=0

/boot/home/sys_compat_run /boot/home/hello_clonethr
CLONETHROK
CLONETHR_RC=0
```

COM1: `CK` `TC` `FS0` `XTX` then `Vv` `W` `EEX 0`. Banner `PR51`.
No KDL.

### Do not

- Unmark CR3 on a CLONE_VM thread `exit`(60).
- Futex from extra-thread exit.
- `_user_fork` for `CLONE_VM`.

### Next

Full glibc `pthread_create` flag set (`CLONE_FS|FILES|SIGHAND|SYSVSEM`).
Ash fd 0 blocking still the tty stub.
