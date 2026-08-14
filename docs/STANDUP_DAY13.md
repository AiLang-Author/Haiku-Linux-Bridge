# Developer standup: Day 13

**Module:** `sys_compat` syscall trap (no ioctl layer)  
**License:** Public Domain / CC0 1.0 Universal  
**Pickup doc:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)  
**90% map:** [SYSCALL_COVERAGE.md](SYSCALL_COVERAGE.md)

Spawn diagnosis. Single-process CLI (grep etc.) is already green.
`_kern_fork` from a marked Linux team is the next base and it is hard.

### What is not blocked

Unmodified busybox **grep / sed / wc / head / sort / cut** via
`sys_compat_run`. Those applets do not `fork`. Host `strace` of this
`grep` is only numbers we already implement.

### What is blocked

Shells, pipelines (`cat \| grep`), `sh -c 'grep …'`, make, LTP clone.
That is `fork` + `wait4` + `execve`. **Not** futex / `CLONE_VM`
(pthread). Do not mix threading into the fork fix.

### Guest probes (2026-08-14)

`_kern_fork` 0x2f via `jmp` original LSTAR from a Linux-marked team
**resets the guest**. No new line in `haiku_serial.log` (triple-fault
class, not a printed KDL).

| Probe | Child | Parent | Result |
|---|---|---|---|
| `hello_fork` | Linux `exit(60)` | `wait4` | reboot |
| `hello_fork_probe` v1 | spin, no syscall | write `PRE` then `exit` | reboot, no `PRE` |
| `hello_fork_probe` v2 | spin, no syscall | write `PRE` then spin | reboot, no `PRE` |

So the crash is **inside `fork_team` or the child's first `sysret`**
(copied iframe). It is not `wait4`. It is not “the child issued a
Linux syscall.”

### Landmine (fix after fork returns)

Linux `exit` / `exit_group` are **60 / 231**. Haiku syscall **60** is
`_kern_cancel_thread`. An unmarked child's `exit(0)` becomes
`cancel_thread(0, garbage)`. Must stamp the child's CR3 (no C on the
miss path) and take the Linux `exit` → `_kern_exit_team` 0x29 path.
Adopt-on-every-miss stays **off** (that killed Terminal).

Tried and rejected: `get_team_info` on CR3-miss; sharing `gSavedRsp` /
`gKstack` with `wait4`; stamping every unmarked syscall.

### Next

1. Make `fork_team` return. Parent must be able to print `PRE`.
2. Stamp child CR3 on first Linux `write`/`exit`. Never pass 60 through.
3. `wait4`, then `execve`.
4. pthread (`futex`, `CLONE_VM`) later.
