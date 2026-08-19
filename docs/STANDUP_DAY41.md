# Developer standup: Day 41

**Module:** `sys_compat` syscall trap
**License:** Public Domain / CC0 1.0 Universal
**Pickup:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)
**Testers:** [STATUS.md](STATUS.md)
**Punch-out:** [CLI_APPLET_PUNCHOUT.md](CLI_APPLET_PUNCHOUT.md)

### What landed (PR33)

Identity LSTAR `0x29` after `.Lexit`'s stack dance delivered status 0
for every Linux `exit`/`exit_group`. Guest serial after the C path is
`EX <hex>` then `EXR` (no `TXR` — `thread_exit` does not return).

| Change | Why |
|---|---|
| Always `_user_exit_team(status)` + `thread_exit` | Same path that already finished `uname01`. Do not jmp official `0x29` from `.Lexit`. |
| `sExitStatus` | `gTmpR8` is scratch for every Linux syscall. |
| `sys_compat_run` argv | `sys_compat_run busybox false` is now `["…/busybox", "false"]` (execve shape). The old `argc>=3` drop made that `["false"]`. |
| `tests/hello_exit.s` | Raw `exit_group(42)`, no glibc. |

### Guest-proven

| Probe | Result |
|---|---|
| `hello_exit` | **`EXIT42_RC=42`**. COM1 `EX 0x2a`. |
| `true` | `TRUE_RC=0` |
| `id` | `groups=0(root)` still |
| `false` | **`FALSE_RC=0`**. COM1 `EX 0x0`. Host of the same ELF is `exit_group(1)`. argv is `[busybox] [false]`. |
| `cmp` differ | stderr printed, `CMP_RC=0`, `EX 0x0` |

The trap is no longer the thing that zeros a non-zero `rdi`. busybox
`false` / `cmp` are calling `exit_group(0)` themselves. That is the
next hole.

### Do not

- Jmp identity `0x29` from `.Lexit` after the gs:8-0xA00 switch.
- Store the exit status in `gTmpR8`.
- Drop the ELF path from Linux argv.

### Next

Why glibc-static busybox `false` (and differing `cmp`) issue
`exit_group(0)` on the guest when the same ELF on Linux issues
`exit_group(1)`. Then redirected stdout / fflush.
