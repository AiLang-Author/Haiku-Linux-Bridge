# Developer standup: Day 33

**Module:** `sys_compat` syscall trap (no ioctl layer)
**License:** Public Domain / CC0 1.0 Universal
**Pickup:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)
**Testers:** [STATUS.md](STATUS.md)

`chown` / `ftruncate` no longer bounce a Haiku `stat` through
`gSavedRsp-256`. That slot is the red zone or unmapped, so LTP
`tst_tmpdir` died with `EFAULT`.

### What changed

Path-based `chmod`/`chown`/`truncate` copy the Linux path into a
kernel buffer and call `_kern_write_stat` (kernel pointers). The
symbol is a `T` in `kernel_x86_64`; we resolve it at load
(`WKfn=0xffffffff80104730` on hrev57937).

fd-based `fchmod`/`ftruncate`/`fchown` still need the **user** io
context (`_user_write_stat`). `_kern_write_stat` looks at the
kernel fds and misses. At mark we steal the last 4K of the loader
arena (`WRsc=`) — a real user page — and pass that as the Haiku
`stat` buffer. `brk` / ANON `mmap` never carve into it.

### Proof (guest 2026-08-16, WS2)

| Test | Result |
|---|---|
| `hello_wstat` | `WSTATOK` `WSTAT_RC=0` |
| `hello_mmapf` | `MMAPFOK` `MMAPF_RC=0` |
| `sh -c 'echo HI \| cat'` | `HI` `PIPE_RC=0` |
| LTP `uname01` | past `tst_tmpdir` `chown` and `ftruncate`. Next: `/proc/meminfo` |

COM1: `WS2` `WKfn=0xffffffff80104730` `WRsc=<arena last page>`.

### Do not

- Bounce `_user_write_stat` through `gSavedRsp-256`.
- Call `_kern_write_stat` for an fd-only op (kernel io context).
- Call `_user_write_stat` with a kernel `stat` pointer.

### Next

1. Synthetic `/proc/meminfo` (LTP `tst_memutils` after tmpdir).
2. ioctl / TTY still deferred.
