# Developer standup: Day 52

**Module:** `sys_compat` syscall trap
**License:** Public Domain / CC0 1.0 Universal
**Pickup:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)
**Testers:** [STATUS.md](STATUS.md)
**Punch-out:** [CLI_APPLET_PUNCHOUT.md](CLI_APPLET_PUNCHOUT.md)

### What landed (PR48)

Linux `exit`(60) is Haiku `thread_exit` when the team still has
other threads. `exit_group`(231) is still team `_user_exit_team`.
A `CLONE_VM` child can die without killing the parent.

| Change | Why |
|---|---|
| Hook `.Lexit60` if `thread_count > 1` → `thread_exit` | Day 51 child hung because 60 was `exit_team` |
| Last thread of the team still `.Lexit` | Fork child is the only thread; `hello_fork` `FORKOK` |
| `exit_group`(231) unchanged | glibc `exit()` / busybox `false` |

Do not unmark CR3 on the extra-thread path (same CR3 as the parent).

### Guest-proven

```
/boot/home/sys_compat_run /boot/home/hello_fork
FORKOK
FORK_RC=0

/boot/home/sys_compat_run /boot/home/hello_clonevm
CLONEEXOK
CLONEVM_RC=0
```

Child sets a shared flag then `exit(60)`. Parent still prints.
No KDL. Banner `PR48`. COM1 `XT n=2` then parent `W` `x` `EX`.

### Do not

- Unmark CR3 on a CLONE_VM thread `exit`(60).
- `_user_fork` for `CLONE_VM`.
- `_user_wait_for_objects` from C.

### Next

`CLONE_SETTLS` / `CLONE_CHILD_CLEARTID`. Ash `nfds==1` still stubs.
