# Developer standup: Day 30

**Module:** `sys_compat` syscall trap (no ioctl layer)
**License:** Public Domain / CC0 1.0 Universal
**Pickup:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)
**Testers:** [STATUS.md](STATUS.md)

The parent hold until `set_robust` was the pipe killer. Dropping it
and IRETQ'ing under CLI got a **second clone** and **execve of cat**.

### What was actually true

- Day 28/29 `N`/`k!` while holding: the child `ret`+push ran on the
  Linux stack before the parent IRETQ'd. Shared or not, the parent
  then `ret`'d into junk.
- `rbx=0` at clone is real and **correct**. Ash's atfork walker
  returns 0; `xor r12d,r12d` before clone. Not a save bug.
- `preRet` on `gKstack` was a fake `N` (child C reuses that stack).
  Snapshot now lives in `gForkRetAddr` BSS.
- STI after `_user_fork` (RB2) let the child stamp/getpid onto
  `gKstack` while the parent was still there → KDL `ip 0x3`.

### What we do now

After `_user_fork`, stay CLI and IRETQ immediately. The child is
still on the tramp (`getpid`) and has not switched to the Linux
stack. Parent `ret`s on the intact slot (`K 0x4bdcfe`).

### Proof (guest 2026-08-16, `RB3`)

```
K0x00000000004bdcfe
J F4
5R                          # parent IRETQ, no hold
SFgcT                       # echo child tramp
C123F2 …                    # SECOND clone (cat)
… v … x XEC /boot …         # wait4 + execve
```

No Kill Thread on the first clone. Desktop up. The redirected
`run_sh.sh` block did not finish (no `HI` / `SHDONE` POST yet) —
likely `wait4` or cat blocked on the pipe. That is the next hole,
not the parent `ret`.

### Do not

- Hold the parent until `set_robust` (child smashes the clone
  `ret` slot first).
- STI / `user_memcpy` / `mprotect` after `_user_fork` (gKstack
  fight → KDL, or desktop down).
- IRETQ the parent onto the tramp page.

### Next

1. Unstick the post-`XEC` hang (`wait4` vs echo not closing the
   write end vs cat `execve` not marking).
2. Confirm `HI` + `SHDONE` on COM1/`sh_out`.
3. ioctl still deferred.
