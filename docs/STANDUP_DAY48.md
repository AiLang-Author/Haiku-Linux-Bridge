# Developer standup: Day 48

**Module:** `sys_compat` syscall trap
**License:** Public Domain / CC0 1.0 Universal
**Pickup:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)
**Testers:** [STATUS.md](STATUS.md)
**Punch-out:** [CLI_APPLET_PUNCHOUT.md](CLI_APPLET_PUNCHOUT.md)

### What landed (PR45)

`hello_poll` `POLLOK` without KDL. `_user_wait_for_objects` copies
through `user_memcpy` and GPFd (`src=0x7fffffcfff01`) even after the
ELF pollfd was in hand (`P0x403018`).

| Change | Why |
|---|---|
| ELF `nfds==1` pollfd copied in the hook with user GS (`gPollSnap`) | C `user_memcpy` / kernel-GS load of `.data` KDLd |
| Kernel `wait_for_objects_etc` on a kernel `object_wait_info` | `_user_wait_for_objects` is the GPF |
| timeout 0 uses a Linux `write()` flag, not wait | wait reported `READ` on an empty pipe (`WS=1` `HE=1`) |
| Non-ELF `nfds==1` still the Day 47 stub | ash stdin pollfd stays uncopied |

### Guest-proven

```
/boot/home/sys_compat_run /boot/home/hello_poll
POLLOK
POLL_RC=0
```

```
/boot/home/sys_compat_run /boot/home/busybox sh
~ # echo SHLIVE
SHLIVE
```

No KDL. COM1: `mQoOWoOWet` (two polls, write, exit). Banner `PR45f`.
`WOKfn=0xffffffff8015afc0`.

### Do not

- `_user_wait_for_objects` from C (KDL in `user_memcpy`).
- `user_memcpy` ash's stdin pollfd.
- Treat wait `READ` on timeout 0 as POLLIN for an empty pipe.

### Next

Re-prove `echo HI | cat` in a redirect. Blocking ELF `poll(..., -1)`
uses `wait_for_objects_etc`; ash still stubs `nfds==1`.
