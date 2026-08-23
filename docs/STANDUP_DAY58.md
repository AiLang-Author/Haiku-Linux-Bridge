# Developer standup: Day 58 (park)

**Module:** `sys_compat` syscall trap
**License:** Public Domain / CC0 1.0 Universal
**Pickup:** [CONTINUATION.md](CONTINUATION.md) — start there
**Plan:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)
**Testers:** [STATUS.md](STATUS.md)
**Punch-out:** [CLI_APPLET_PUNCHOUT.md](CLI_APPLET_PUNCHOUT.md)

The original grinder is parking for a few weeks. The hole, the
lab, and the landmines are in CONTINUATION.md. Fork it.

### What landed

`clone3` trampoline is guest-green without glibc `start_thread`.
New probe `tests/hello_clone3fn.s` prints **`CLONE3FNOK`**.
`hello_clonept` is still **`CLONEPTOK`**.

glibc-static `hello_pthread` is **not** `PTHREADOK`. `start_thread`
takes the `stopped_start` lock (`[pd+0x613]` / `[pd+0x618]` →
`__lll_lock_wait_private`) then `abort`/`raise`. One run ended in
KDL at user `ip=0x27` with IF clear (kill stub returns 0). Kernel
was `system_reset` back to a live desktop.

| Change | Why |
|---|---|
| Revert clone3 `childStack -= 8` | SysV: 16-aligned SP at `call *%rdx` |
| TCB dump before resume | `self`, canary, locale, `ULS=0x2b0` |
| No trampoline `gettid` | `CALL_C`/`gSavedRsp` raced parent `clone_vm` → KDL |
| `KSER 'A'` on `ARCH_SET_FS` | COM1 proof SETTLS ran |
| `gettid` on `CALL_GS8` | per-thread kstack; still do not call it from the trampoline |
| `hello_clone3fn.s` | isolation: fn/arg/SETTLS without `start_thread` |

Banner `PR53g`.

### Guest-proven this day

```
CLONEPTOK
CLONEPT_RC=0
CLONE3FNOK
CLONE3FN_RC=0
```

COM1 clone3fn: `C3 sz=0x40 fn=0x401000`. glibc pthread: `C3 sz=0x58
fn=0x40bd10` `TCB0=SELF` `CAN=0xdeadbeefcafeba00` `LOC=0x4c89c0`
`A` then abort letters `g`/`k`.

### Do not

- `childStack -= 8` after 16-align.
- Any trampoline syscall that uses `gSavedRsp` / `gKstack` / `CALL_C`.
- `user_memcpy` Linux TLS/stack futex words.
- Claim `PTHREADOK` until the guest prints it.

### Next (for whoever picks this up)

Dump `pd+0x613` / `+0x618` before resume. Parent must unstop after
`clone3` returns. See [CONTINUATION.md](CONTINUATION.md).
