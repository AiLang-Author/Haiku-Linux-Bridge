# Developer standup: Day 51

**Module:** `sys_compat` syscall trap
**License:** Public Domain / CC0 1.0 Universal
**Pickup:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)
**Testers:** [STATUS.md](STATUS.md)
**Punch-out:** [CLI_APPLET_PUNCHOUT.md](CLI_APPLET_PUNCHOUT.md)

### What landed (PR47)

Linux `clone(CLONE_VM, stack)` in the same team. `_user_spawn_thread`
+ `resume_thread`. A trampoline on the mark tramp page sets `rax=0`,
switches to the Linux child stack, and jumps to the clone return.
Same CR3, so the child is already marked.

| Change | Why |
|---|---|
| Hook: `CLONE_VM` + non-NULL stack → `sys_compat_clone_vm` | Fork-style `_user_fork` copies the address space |
| User `thread_creation_attributes` on the tramp page | `_user_spawn_thread` copies from a user pointer |
| Child hangs after storing a shared flag | Linux `exit`(60) is still team `_user_exit_team`; do not take it from a CLONE_VM child yet |
| Fork-style clone unchanged | `hello_fork` `FORKOK` |

`CLONE_SETTLS` / `CLONE_CHILD_CLEARTID` / `CLONE_THREAD` wait4 are
not in this probe.

### Guest-proven

```
/boot/home/sys_compat_run /boot/home/hello_fork
FORKOK
FORK_RC=0

/boot/home/sys_compat_run /boot/home/hello_clonevm
CLONEVMOK
CLONEVM_RC=0
```

No KDL. Banner `PR47`. COM1 `TV` `TS0x260` `TR0` `W` `eE` (`exit` 60).

### Do not

- `_user_fork` for `CLONE_VM` (that is a new team).
- Linux `exit`(60) from a CLONE_VM child (still `exit_team`).
- `_user_wait_for_objects` from C.

### Next

Thread `exit`(60) vs `exit_group`(231). Then SETTLS / CLEARTID.
Ash `nfds==1` still stubs.
