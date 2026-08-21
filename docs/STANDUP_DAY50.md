# Developer standup: Day 50

**Module:** `sys_compat` syscall trap
**License:** Public Domain / CC0 1.0 Universal
**Pickup:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)
**Testers:** [STATUS.md](STATUS.md)
**Punch-out:** [CLI_APPLET_PUNCHOUT.md](CLI_APPLET_PUNCHOUT.md)

### What landed (PR46c)

Blocking ELF `poll(..., -1)` on a pipe. Child `nanosleep` 200ms then
writes one byte; parent waits, nonblock-reads `'A'`.

| Change | Why |
|---|---|
| timeout ≠ 0 clears `sPollWrote` then snoozes until a Linux `write()` | `_user_wait_for_objects` from C still KDLs (`user_memcpy` `src=0x7fffffcfff01`) even when the ELF pollfd is `0x403020`. Kernel `wait_for_objects_etc` is `kernel=true` (wrong io context; READ on an empty pipe) |
| timeout 0 still one shot on the write flag | `hello_poll` `POLLOK` must not wait |
| A stale flag from another team's stdout must not wake `poll(-1)` | PR46b: `POLLBLKFAIL` then nonblock read `EAGAIN` |
| `nanosleep` calls `snooze` | the child delay is real (`PW`…`PE` on COM1) |

Ash `nfds==1` is still the Day 47 no-copy stub.

### Guest-proven

```
/boot/home/sys_compat_run /boot/home/hello_poll
POLLOK
POLL_RC=0

/boot/home/sys_compat_run /boot/home/hello_pollblk
POLLBLKOK
POLLBLK_RC=0
```

No KDL. Banner `PR46c`. COM1 `PW` `W` `PE` (wait, child write, wake).

### Do not

- `_user_wait_for_objects` from C (KDL in `user_memcpy`, ELF pointer or not).
- Treat kernel `wait_for_objects_etc` READ as POLLIN on an empty pipe.
- Trust a leftover `sPollWrote` from a previous Linux team on `poll(-1)`.

### Next

`CLONE_VM`. Ash `nfds==1` still stubs.
