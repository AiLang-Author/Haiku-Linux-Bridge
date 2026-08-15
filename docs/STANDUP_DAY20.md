# Developer standup: Day 20

**Module:** `sys_compat` syscall trap (no ioctl layer)
**License:** Public Domain / CC0 1.0 Universal
**Pickup / onboarding:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)
**90% map:** [SYSCALL_COVERAGE.md](SYSCALL_COVERAGE.md)

`hello_fork` is guest-green. Linux `clone` + child `exit` + parent
`wait4` + `FORKOK` + both `exit`. RC=0. Desktop stays up.

### Proof (guest 2026-08-15)

COM1:

```
F4
5R
S
eEVvWeE
```

`/tmp/fork.out`: `FORKOK` then `FORK_RC=0`.
`/dev/misc/sys_compat` after: `hits=4 last=60 seq=56,61,1,60`
(clone, wait4, write, exit).

### What was actually broken

1. **`wait4` dropped `rcx`/`r11`.** Those are SYSCALL RIP/RFLAGS.
   C clobbered them; `sysretq` returned to garbage. Team crash
   dialog after `V`. Push them on `gs:8` around the C call.
2. **Child first syscall during `_user_fork` must not `CALL_C`.**
   `gKstack` is one global; parent `try_fork` is sitting on it.
   Stamp path only handles `exit`/`write`.
3. **`jne 1f` next to `KSER` jumps into the macro's UART-wait `1:`.**
   That made `S`/`X`/`e` lie. Named labels only around `KSER`.
4. **Child iframe.ip is the tramp `exit(60)` stub**, not `0x40101c`.
   Sending the child to the ELF with a leftover/wrong `ax` issued
   a non-exit first syscall (`SX`) and never died.

### What is still open

| Step | Result |
|---|---|
| Parent IRETQ to `0x40101c` | Green (Day 18 `PRE`) |
| Child tramp `exit(60)` + stamp + `_kern_exit_team` | **`S eE`** |
| Parent `wait4` + `FORKOK` | **`Vv W`, RC=0** |
| Child IRETQ to the real Linux RIP | Open |
| `execve` | Open |

### Next (do not skip)

1. Child IRETQ to Linux `0x40101c` (`ax=0` → ELF `exit`). The tramp
   stub is a crutch.
2. `execve`.
3. pthread / ioctl later.

Landmines: save `rcx`/`r11` across every C helper that `sysretq`s;
no `CALL_C` while parent is on `gKstack`; no `1f`/`2f` beside
`KSER`; adopt-on-every-miss stays **off**. ioctl deferred.
