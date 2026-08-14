# Developer standup: Day 06

**Module:** `sys_compat` syscall trap (no ioctl layer)  
**License:** Public Domain / CC0 1.0 Universal  
**Pickup doc:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)

### Accomplishments
- [x] **`lseek` proven.** Linux 8 → `_kern_seek` `0x79`. Args already match (`fd, off, whence`); `SEEK_SET/CUR/END` are 0/1/2.
- [x] **`open` / `openat` proven.** Both map to `_kern_open` `0x72`. Haiku `AT_FDCWD` is also `-100`. Access-mode bits (0/1/2) match; other bits **must** be translated — Linux `O_CREAT` `0x40` is Haiku `O_CLOEXEC`.
- [x] `hello_fds` (unmodified Linux ELF) on Haiku:
  - `lseek(3, SEEK_SET)` then `read` printed `DEFG` from `ABCDEFGHIJ`
  - `openat(AT_FDCWD, …)` then `read` printed `ABC`
  - `open(O_CREAT\|O_WRONLY\|O_TRUNC, 0644)` wrote `/tmp/created` (`CREATED`)
  - `DONE_RC=0`, `mark=1 hits=13 last=60`
  - Evidence: `results/ltp/fds_out.txt`

### Flag translation (Linux → Haiku)

| Bit | Linux | Haiku |
|---|---|---|
| ACCMODE | 0..2 | 0..2 (same) |
| O_CREAT | `0x40` | `0x200` |
| O_EXCL | `0x80` | `0x100` |
| O_TRUNC | `0x200` | `0x400` |
| O_APPEND | `0x400` | `0x800` |
| O_NONBLOCK | `0x800` | `0x80` |
| O_CLOEXEC | `0x80000` | `0x40` |
| O_DIRECTORY | `0x10000` | `0x200000` |
| O_NOFOLLOW | `0x20000` | `0x80000` |

### Next steps
1. `brk` / `mmap` / `munmap` — not a number swap; Haiku uses areas.
2. Static busybox `echo` / `cat` / `uname`.
3. ioctl still deferred.

### Proven Linux syscalls so far
`read`, `write`, `close`, `lseek`, `open`, `openat`, `exit`, `exit_group`. Handshake `0x1337`.
