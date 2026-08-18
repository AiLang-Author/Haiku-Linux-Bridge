# Developer standup: Day 39

**Module:** `sys_compat` syscall trap (no ioctl layer)
**License:** Public Domain / CC0 1.0 Universal
**Pickup:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)
**Testers:** [STATUS.md](STATUS.md)

Finish line landed. Guest 2026-08-18:

| Test | Result |
|---|---|
| `hello_wstat` | `WSTAT_RC=0` |
| `hello_mmapf` | `MMAPF_RC=0` |
| `echo HI \| cat` | `PIPE_RC=0` |
| LTP `uname01` | **passed 2 / failed 0 / broken 0**. **`UNAME_RC=0`**. No Kill Thread. |

Kernel stayed up. COM1 after the last `linux_mmap` delete:
`ND gbc cX=2 cS e t E EX EXR` then `thread_exit` (no `TXR`).

### What made teardown finish

Host Linux of the same static `uname01` is `munmap` then `exit_group(0)`.
After a real `vm_delete_area` (`ND`) the hook sets `sExitCloses` in
**this** image (dual-load BSS). Then:

1. Identity LSTAR is banned except we no longer use it here.
2. close does not `_user_close` (`cS`) — that KTd after `ND`.
3. That close jumps to `.Lexit` (returning to glibc KTd before the
   next syscall).
4. `exit_prep` still walks the robust list (`t`).
5. `_user_exit_team` sets `CLD_EXITED` (`EX`). Official LSTAR `0x29`
   after `ND` KTd. `_user_exit_team` returns (`EXR`) — it only posts
   SIGKILL.
6. `thread_exit()` actually tears the thread down (never prints `TXR`).

`sExitCloses` is set **only** when munmap C returns 1 (`ND`). Setting
it on `set_robust_list(NULL)` made pipe `close` take down the whole
team (hung `echo HI | cat`). Do not put that trigger back.

### Landmines from this day

- `KSER` uses local labels `1:`/`2:`. `je 1f` next to `KSER` jumps
  into the UART wait (PR23 KDL: extra pops under CLI). Use named labels.
- Do not `sysret` under CLI after `_user_exit_team`.
- `sExitCloses` is global. Zero it in `.Lmark` and before `thread_exit`.
- Two load addresses of the same addon both `init`. Last LSTAR wins.

### Do not

- Stub `set_robust_list(NULL)` into `exit_team`.
- Identity-pass Linux `kill`.
- `_kern_unmap_memory` on `vm_map_file` ranges.
- Leave a second `sys_compat` under `/boot/system/non-packaged/`.

### Next

ioctl / TTY still deferred. CLI 90% set continues from a green
`uname01` exit.
