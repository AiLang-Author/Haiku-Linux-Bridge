# Developer standup: Day 40

**Module:** `sys_compat` syscall trap
**License:** Public Domain / CC0 1.0 Universal
**Pickup:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)
**Testers:** [STATUS.md](STATUS.md)
**Punch-out:** [CLI_APPLET_PUNCHOUT.md](CLI_APPLET_PUNCHOUT.md)

Busybox 1.36.1 applet battery (58 invocations) ran without Kill Thread
or KDL. Host `strace` of that set is **55 unique Linux syscalls**, not
the earlier ~90 guess.

### What landed in the trap (PR32)

| Item | Change |
|---|---|
| Exit path | After `ND`, close returns (`cS` + `.Lret`). `.Lexit` only from `exit` / `exit_group`, with the real `rdi`. No `xor rdi,rdi` on close or futex. |
| Stdio flush | After `ND`, `write` is `_user_write` on `gs:8` (not identity LSTAR). |
| `umask` (95) | In-hook, default 022 (`.data`, not `.bss`). |
| `sync` (162) | Return 0. |
| `getgroups` (115) | One gid (current). |
| `sched_getaffinity` (204) | One CPU bit. |

### Guest-proven (PR32, `guest_run_status.sh`)

Guest curl POST of the capture succeeded (`OK`, Haiku curl / BSD sockets).

| Probe | Result |
|---|---|
| `id` | `uid=0(user) gid=0(root) groups=0(root)` — **getgroups green** |
| `true` | `TRUE_RC=0` |
| `false` | **`FALSE_RC=0` (must be 1).** Host of the same ELF is `exit_group(1)`. |
| `cmp` differ | printed `cmp: EOF on /tmp/sb.txt`, **`CMP_RC=0` (must be 1)** |
| `date -u` | `DATE_RC=0`, no date line in the redirect. Serial has `W` then `e`. |
| `md5sum` | `MD5_RC=0`, no digest. Serial `mQbcet` (close, no write). |
| `nproc` | `NPROC_RC=0`, no count. Serial `mQbet` (no write). |

Kernel stayed up. No KT/KDL on this script.

### Do not

- Jump `.Lexit` from close or futex (that forced status 0 and skipped fflush).
- Set `sExitCloses` on `set_robust_list(NULL)`.
- `je 1f` next to `KSER`.
- Identity-pass Linux `kill`.
- Put a non-zero init in `.bss` (`sUmask` lives in `.data`).

### Next

1. Find why `exit_group(1)` still waits as 0 (identity `0x29` path; `false` never `ND`s).
2. Find why a post-`fflush` `write(1, …)` does not land in a redirected file.
3. Then TTY / fbdev / ioctl onto Haiku drivers (not a Linux display stack).
