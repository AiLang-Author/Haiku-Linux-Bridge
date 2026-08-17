# Developer standup: Day 36

**Module:** `sys_compat` syscall trap (no ioctl layer)
**License:** Public Domain / CC0 1.0 Universal
**Pickup:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)
**Testers:** [STATUS.md](STATUS.md)

Harness + teardown work after Day 35's green `uname01` summary.

### What landed (guest 2026-08-16, PR5)

| Item | Result |
|---|---|
| `UserBootscript` | `sleep 12` then `Terminal &` + Tracker `hey`. Auto-Terminal after desktop. `hey` alone missed one boot. |
| Dual addon | System-tree leftover (`/boot/system/non-packaged/.../sys_compat`, Aug 14) loaded **after** the user copy and re-hooked LSTAR. COM1 printed `PR5` then `PR4`. Install now copies the just-built binary to the user path and deletes the system copy. |
| `kill`/`tkill`/`tgkill` | Stub 0. COM1 `k` during LTP heartbeat. Did **not** stop the teardown KT. |
| `msync`/`alarm`/`setitimer` | Stub 0. |
| `munmap` | Return 0, no `_kern_unmap_memory`. COM1 `n`. `hello_wstat` / pipe now reach `eE`. `uname01` gets past ipc `munmap` (`Nn`) then still KTs. |
| `hello_wstat` / `hello_mmapf` / `echo HI \| cat` | Still green (`WSTATOK`, `MMAPFOK`, `HI`). |
| LTP `uname01` | **passed 2 / broken 0**. `UNAME_RC=149`. Last COM1: `vWWWWWWccNngbB c`. |

### Teardown hole (still open)

After the summary, parent `do_cleanup` now does unlink + munmap (`Nn`) then `set_robust_list` (`bB`) then `close` (`c`) and dies. No `e`/`E`. Next: that last close / glibc exit prologue, not munmap.

A leftover system-tree addon will silently undo a user install. `guest_go_fork.sh` removes it.

### Do not

- Identity-pass Linux `kill` (Haiku 62 is not kill).
- Leave a second `sys_compat` under `/boot/system/non-packaged/`.
- Call `_kern_unmap_memory` on the LTP MAP_SHARED ipc page (that was the old `cuU` death).
- Put test runners in `UserBootscript`.

### Next

1. Why `uname01` still KTs after `set_robust_list` + `close` (no `e`).
2. ioctl / TTY still deferred.
