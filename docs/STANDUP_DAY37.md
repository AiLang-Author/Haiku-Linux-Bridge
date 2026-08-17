# Developer standup: Day 37

**Module:** `sys_compat` syscall trap (no ioctl layer)
**License:** Public Domain / CC0 1.0 Universal
**Pickup:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)
**Testers:** [STATUS.md](STATUS.md)

Teardown work after Day 36. Finish line is still LTP `uname01` **exit 0**
(no Kill Thread after the green 2/0/0). Not there yet.

### What landed (guest 2026-08-17)

| Item | Result |
|---|---|
| `munmap` | Real `delete_area` on tracked `linux_mmap` / `linux_*` areas. Never `_user_unmap_memory` (that was `cuU` KT). COM1 `n`, `ND` on success, `NF=` on fail. |
| Failed `delete_area` | `B_BAD_VALUE` on the LTP MAP_SHARED ipc page after fork (stale area id). Retry `area_for`; if still fail, return 0 so glibc does not take the EINVAL close/futex path. |
| `set_robust_list` | In-hook store, rdx preserved (`_Fork` returns edx). CALL_C on `gKstack` KTd at `gbB1`. Per-team table for exit_prep. |
| `get_robust_list` (274) | Implemented. |
| `exit_prep` | Walk robust list (FUTEX_OWNER_DIED + wake), clear_child_tid + wake, on this thread's `gs:8-0xA00`. COM1 `t`. |
| `wait4` | Loop on `B_WOULD_BLOCK` instead of returning 0. Hold while a second Linux CR3 is still marked (`w`). Pipe guest-showed `w` then still `HI` / `PIPE_RC=0`. |
| `hello_wstat` / `hello_mmapf` / `echo HI \| cat` | Still green (`WSTAT_RC=0`, `MMAPF_RC=0`, `PIPE_RC=0`). |
| LTP `uname01` | **passed 2 / broken 0**. `UNAME_RC=149`. Last COM1: `…WWgVvkgb`. |

### Teardown hole (still open)

After the child runs both TPASS lines, parent `wait4` returns (`v`) and
the next letters are `kgb` (kill, getpid, `set_robust_list`) then Kill
Thread. No `e`/`E`. PR10 once continued to the summary writes and
`ccNnNF=0x80000005 gbcuU` — munmap of the ipc page is the next real
unmap after the summary; `delete_area` still returns `B_BAD_VALUE` there.

Do not stub `set_robust_list(NULL)` into `exit_team`. Do not skip
`_kern_close`. Do not identity-pass Linux `kill`.

Every-sysret `apply_fs` KTd the pipe parent (reverted). Long `kser_hex`
of the robust head interleaved with clone breadcrumbs (shortened).

### Do not

- Identity-pass Linux `kill` (Haiku 62 is not kill).
- Call `_kern_unmap_memory` on `vm_map_file` ranges.
- `CALL_C` `set_robust_list` on the one global `gKstack`.
- Apply FS_BASE on every `.Lret`.
- Leave a second `sys_compat` under `/boot/system/non-packaged/`.

### Next

1. Why `uname01` KTs at `kgb` after a completed `wait4` (child CR3
   already gone from the mark table — not the live-child hold).
2. `delete_area` of the forked `linux_mmap` ipc page (`NF=B_BAD_VALUE`).
3. ioctl / TTY still deferred.
