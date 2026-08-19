# Developer standup: Day 42

**Module:** `sys_compat` syscall trap
**License:** Public Domain / CC0 1.0 Universal
**Pickup:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)
**Testers:** [STATUS.md](STATUS.md)
**Punch-out:** [CLI_APPLET_PUNCHOUT.md](CLI_APPLET_PUNCHOUT.md)

### What landed (PR34)

glibc `exit(status)` parks the code in **r14** then `_exit`. Linux
SYSCALL must keep `rbx`/`rbp`/`r12–r15`. The hook did not. `_exit(1)`
was already green (`rdi` set at the stub); `exit(1)` / `return 1` came
out 0.

| Change | Why |
|---|---|
| Push callee-saved on `gs:8` at `.Llinux_go`, pop at `.Lret` | Per-thread; identity `.Llstar` abandons the kstack |
| If `exit`/`exit_group` `rdi==0` and `r14` is 1..255, use `r14` | glibc `mov %r14d,%edi; _exit` after a clobber |
| COM1 `EX <status> r14=<reg>` | See which path fired |

### Guest-proven (PR34)

| Probe | Result |
|---|---|
| `hello_exit` (`exit_group(42)`) | **`EXIT42_RC=42`** |
| `hello_ret1` (`return 1`) | **`RET1_RC=1`** (was 0) |
| `hello_exit1` (`exit(1)`) | **`EXIT1_RC=1`** (was 0) |
| `hello__exit1` (`_exit(1)`) | **`_EXIT1_RC=1`** |
| busybox `false` | **`FALSE_RC=1`** |
| busybox `true` | `TRUE_RC=0` |
| busybox `cmp` (differ) | **`CMP_RC=1`**, stderr `EOF on …` |
| busybox `echo HELLO_ARGV` | printed |
| busybox `date -u` | `DATE_RC=0`, **still no date line** in the redirect |

No KT/KDL.

### Do not

- Restore callee-saved from the **global** `gSavedR*` (two Linux
  threads race). Use this thread's `gs:8`.
- Treat a high `r14` as a status (`hello__exit1` had `r14=0x4a5f68`).

### Next

Redirected fully-buffered stdout (`date`, `md5sum`, `nproc`). Then
TTY / fbdev / ioctl onto Haiku drivers.
