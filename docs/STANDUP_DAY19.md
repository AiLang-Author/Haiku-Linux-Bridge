# Developer standup: Day 19

**Module:** `sys_compat` syscall trap (no ioctl layer)
**License:** Public Domain / CC0 1.0 Universal
**Pickup / onboarding:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)
**90% map:** [SYSCALL_COVERAGE.md](SYSCALL_COVERAGE.md)

Linux syscall dispatch no longer restores the user stack until
official LSTAR / `sysretq`. That is the post-fork COW-RO rule applied
to the whole marked path, not just `write`.

### What changed

- After a CR3 hit (parent) or a child stamp, the hook stays on
  `gs:8` / kernel GS.
- `.Llstar` restores user RSP + `swapgs` and jumps original LSTAR.
- `.Lret` does the same before `sysretq`.
- `CALL_C` / `getpid` / `wait4` no longer `swapgs` (already kernel).
- Clone saves user RSP from `gs:16`, not `rsp`.
- Child iframe.ip is the Linux clone return (`userRip`, `ax=0`).
- `guest_run_fork.sh` runs `hello_fork` (clone + `wait4` + `FORKOK`).

`.Lmark` still `swapgs` — it runs on the user GS before any mark.

### Proof (guest 2026-08-15)

`hello_fork`:

```
MMARK team=0x1b7
mQC123F2 rip=0x40101c
F4
S5R
V
```

`S` = child first syscall stamped during `_user_fork`.
`V` = parent `wait4` entered after official IRETQ.
No `E` (`.Lexit` remap to `_kern_exit_team`).
No `FORKOK` in `fork.out`. `sys_compat_run` then showed Haiku's
"application has encountered an error" dialog. Kernel stayed up.

### What is still open

| Step | Result |
|---|---|
| Parent IRETQ to `0x40101c` `write(PRE)` | Green (Day 18) |
| Child CR3 stamp | **`KSER S` during `_user_fork`** |
| Linux dispatch on `gs:8` | In tree; parent `wait4` reached |
| Child `exit` after stamp (`KSER E`) | Not seen |
| `wait4` returns / `FORKOK` | Not seen; team crash after `V` |
| `execve` | Not started |

### Next (do not skip)

1. Why stamp `S` does not reach `.Lexit` (`E`). Child may not be
   `rax=60`, or `.Lexit` dies before the remap.
2. Why `wait4` (`V`) then kills `sys_compat_run`. Scratch at
   user RSP−256 may be wrong; `_user_wait_for_child` layout next.
3. Then `execve`.

Landmines: `gKstack` is still one global (`-smp 4`); child runs
under `STI` inside `_user_fork`; do not `swapgs` twice on the
marked path; adopt-on-every-miss stays **off**. ioctl deferred.
