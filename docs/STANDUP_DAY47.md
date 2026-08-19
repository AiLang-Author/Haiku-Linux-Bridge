# Developer standup: Day 47

**Module:** `sys_compat` syscall trap
**License:** Public Domain / CC0 1.0 Universal
**Pickup:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)
**Testers:** [STATUS.md](STATUS.md)
**Punch-out:** [CLI_APPLET_PUNCHOUT.md](CLI_APPLET_PUNCHOUT.md)

### What landed (PR41)

Interactive `busybox sh` on a Haiku Terminal. `poll(nfds=1)` used to
`user_memcpy` the pollfd and **KDL** (`General Protection Exception`
in `user_memcpy` from `sys_compat_poll`). Ash does `poll(0, POLLIN, 0)`
then `poll(..., -1)` then `read()`.

| Change | Why |
|---|---|
| `nfds==1`: timeout 0 → 0, else ready + `snooze(5ms)` | No copy of that pollfd; `read()` blocks on the tty |
| Do not `wait_for_objects` on the Terminal fd | That path KDLd |

### Guest-proven

```
/boot/home/sys_compat_run /boot/home/busybox sh
BusyBox v1.36.1 … built-in shell (ash)
~ # echo SHLIVE
SHLIVE
~ #
```

No KDL. COM1: `oOoO…` (poll returns). Serial banner `PR41`.

`hello_poll` (also `nfds==1`) is a known miss until pollfd copy is safe.

### Do not

- `user_memcpy` the ash stdin pollfd (KDL).
- Pipe `curl \| sh` when testing interactive (fd0 becomes the pipe).

### Next

Safe pollfd copy so pipe `poll(nfds=1)` works again. Then `echo HI | cat`
re-prove.
