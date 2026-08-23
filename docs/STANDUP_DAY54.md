# Developer standup: Day 54

**Module:** `sys_compat` syscall trap
**License:** Public Domain / CC0 1.0 Universal
**Pickup:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)
**Testers:** [STATUS.md](STATUS.md)
**Punch-out:** [CLI_APPLET_PUNCHOUT.md](CLI_APPLET_PUNCHOUT.md)

### What landed (PR50b)

`nfds==1` pollfd is copied in the hook with user GS for any
8-aligned Linux user pointer, not only ELF `.data` at `0x40xxxx`.
Ash/stack pollfds (sys_compat_run stack ~`0x7fff…` / arena) now
get `revents`. `sPollWrote` is cleared on mark so a prior team's
stdout cannot wake timeout 0 on a new empty pipe.

fd 0 + blocking is still the tty stub (`snooze` + ready) so
interactive ash can `read()` — keystrokes are not Linux `write()`.

| Change | Why |
|---|---|
| Hook copy if `rdi` 8-aligned and `linux_user_ok` | Stack pollfd was the no-copy stub |
| C `pollfd_user` matches that range | Same `gPollSnap` path as ELF `hello_poll` |
| Clear `sPollWrote` in `.Lmark_ok` | `POLLBLKOK` stdout left the flag; next timeout 0 was a false POLLIN |
| fd 0 + `timeout != 0` still stubs | Interactive `poll(0, POLLIN, -1)` must reach `read()` |

Do not `_user_wait_for_objects` from C. Do not `user_memcpy` the pollfd.

### Guest-proven

```
/boot/home/sys_compat_run /boot/home/hello_poll
POLLOK
POLL_RC=0

/boot/home/sys_compat_run /boot/home/hello_pollblk
POLLBLKOK
POLLBLK_RC=0

/boot/home/sys_compat_run /boot/home/hello_pollstk
POLLSTKOK
POLLSTK_RC=0
```

`hello_pollstk` puts pollfd on the stack. COM1 `mQoOWoOW` then `EEX 0`.
Banner `PR50b`. No KDL.

### Do not

- `_user_wait_for_objects` from C (KDL in `user_memcpy`).
- Wait on `sPollWrote` for fd 0 blocking (hangs interactive ash).
- Trust `sPollWrote` across mark (stale stdout).

### Next

`CLONE_THREAD` wait4 / full `pthread_create` flags.
