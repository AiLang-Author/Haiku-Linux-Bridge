# Developer standup: Day 38

**Module:** `sys_compat` syscall trap (no ioctl layer)
**License:** Public Domain / CC0 1.0 Universal
**Pickup:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)
**Testers:** [STATUS.md](STATUS.md)

PR22 guest-proven. Finish line is still LTP `uname01` **exit 0**
(no Kill Thread after the green 2/0/0). Not there yet.

### What landed (guest 2026-08-17)

| Item | Result |
|---|---|
| Real munmap | `vm_delete_area(team, id, true)` then `_user_delete_area`. Public `delete_area()` is kernel aspace (`B_BAD_VALUE`). COM1 `VD` / `ND`. |
| `sExitCloses` | Hook sets the flag when munmap C returns 1. C write was invisible across dual-load BSS (last LSTAR wins). |
| Exit-window close | After `ND`, `.Lclose` calls `sys_compat_close` on this thread's `gs:8` (`cX=fd`). Identity `0x9e` still used before the flag (pipe stays green). |
| Orphan mmap fd | close of a deleted `linux_mmap` fd prints `cM` and returns 0 (does not `_user_close` the backing fd). |
| `linux_user_ok` | Rejects non-user pointers before `user_memcpy` (poll GPF / KDL). |
| `/boot/config-6.1.0` | Generic 6.1 kconfig. LTP parses it; TINFO gone. Not `/proc/config.gz`. |
| Terminal at login | Official `~/config/settings/boot/launch/Terminal` symlink + stock `UserBootscript` `/bin/open` loop. Extra `Terminal &` doubled windows; dropped. |
| `hello_wstat` / `hello_mmapf` / `echo HI \| cat` | Still green (`WSTAT_RC=0`, `MMAPF_RC=0`, `PIPE_RC=0`). |
| LTP `uname01` | **passed 2 / failed 0 / broken 0**. Then Kill Thread. `UNAME_RC=149`. |

### Teardown hole (still open)

Host Linux `strace` of the same static `uname01` after the summary:

```
munmap(…, 4096) = 0
exit_group(0)
```

Guest COM1 after the same summary writes: `Nn Nt=… linux_mmap` `VD` `ND`
`gbc` `cX=2` `uU` — then silence. No `e`/`E`. Kernel stayed up.

So: real delete works, the flag is visible to `.Lclose` in this image,
C close of fd 2 returned, futex entered and returned (`U`), then Kill
Thread on the way to `exit_group`. Identity LSTAR after `ND` is still
poison (that is why close had to leave `0x9e`). write / writev / read /
lseek / open still `jmp .Llstar`.

Do not stub `set_robust_list(NULL)` into `exit_team`. Do not wrap every
close. Do not identity-pass Linux `kill`. Do not `_kern_close` (kernel
aspace) for Linux fds — `_user_close` is the team table.

### Operational

Guest `curl -X POST` to `10.0.2.2:8083` often hangs the only Terminal
(Ctrl-C does not land). `run_next.sh` now `cat`s first and POST with
`--max-time 8`. Alt+N opens a second Terminal if one is wedged.
`sendkey` must map `_` to `shift-minus`.

Two load addresses of `sys_compat` both `init` (COM1 `PR22` × N).
`DUskip` only skips a second init of the **same** image. Keep one
publish point (user tree). Last LSTAR wins.

### Do not

- Identity-pass Linux `kill` (Haiku 62 is not kill).
- Call `_kern_unmap_memory` on `vm_map_file` ranges.
- `CALL_C` `set_robust_list` or close on the one global `gKstack`.
- Apply FS_BASE on every `.Lret`.
- Leave a second `sys_compat` under `/boot/system/non-packaged/`.
- Stub `set_robust_list(NULL)` into `exit_team`.

### Next

1. After `ND` (`sExitCloses`), do not `jmp .Llstar` except the final
   `_kern_exit_team` (`0x29`). Service remaining file ops on `gs:8`.
2. Guest-prove `UNAME_RC=0` with wstat / mmap / pipe still green.
3. ioctl / TTY still deferred.
