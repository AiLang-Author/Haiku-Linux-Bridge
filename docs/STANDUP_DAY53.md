# Developer standup: Day 53

**Module:** `sys_compat` syscall trap
**License:** Public Domain / CC0 1.0 Universal
**Pickup:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)
**Testers:** [STATUS.md](STATUS.md)
**Punch-out:** [CLI_APPLET_PUNCHOUT.md](CLI_APPLET_PUNCHOUT.md)

### What landed (PR49g)

`clone(CLONE_VM|SETTLS|PARENT_SETTID|CHILD_CLEARTID)` is guest-green.
The child trampoline does Linux `arch_prctl(ARCH_SET_FS)` then jumps
to the clone return. Extra-thread `exit`(60) writes 0 to `ctid`,
clears `IA32_FS_BASE`, then `_user_exit_thread` + `thread_exit`.
Last thread of the team is still `_user_exit_team`.

| Change | Why |
|---|---|
| Trampoline prefix `ARCH_SET_FS` when `CLONE_SETTLS` | Child `fs:0` is the TLS word glibc/pthreads expect |
| `CLONE_PARENT_SETTID` `user_memcpy` tid | Parent `ptid` matches clone's return |
| `CLONE_CHILD_CLEARTID` slot + extra-exit `movl $0` | Parent sees `ctid==0` without a futex |
| Extra path: `wrmsr(FS_BASE,0)` then kernel `thread_exit` | Linux FS_BASE on `thread_exit` Kill Threaded the team |
| OS.h `exit_thread()` / `kill_thread()` are not this path | From the driver they return or never deliver SIGKILLTHR |

Do not futex-wake from extra-thread exit (hung). Do not fall through
extra-thread exit into `.Lexit_have` (unmarks CR3, kills the parent).
Do not unmark CR3 on the extra-thread path.

`hello_clonetls.s` flags are `0x380100` (`VM|SETTLS|PARENT_SETTID|CLEARTID`).
`0x280100` omitted `PARENT_SETTID` and failed `Fptid`.

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
```

COM1: `PT=` `CT=` `TL=` then child `CK` `TC` `FS0` `XTX`, parent `W`
`x` `EEX` `EXR`. Banner `PR49g`. No KDL.

### Do not

- Unmark CR3 on a CLONE_VM thread `exit`(60).
- Futex from extra-thread exit.
- `_user_fork` for `CLONE_VM`.
- `_user_wait_for_objects` from C.
- OS.h `exit_thread()` from this driver (no-op).

### Next

Ash `nfds==1` still stubs. `CLONE_THREAD` wait4 / full `pthread_create`
flags later.
