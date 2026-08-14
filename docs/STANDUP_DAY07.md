# Developer standup: Day 07

**Module:** `sys_compat` syscall trap (no ioctl layer)  
**License:** Public Domain / CC0 1.0 Universal  
**Pickup doc:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)

### Accomplishments
- [x] **`brk` / ANON `mmap` / `munmap` proven** on an unmodified Linux ELF.
  - Loader maps a 32 MB arena and passes `(base, size)` to mark syscall `0x1337`.
  - Trampoline: `brk` bumps from the bottom, ANON `mmap` carves from the top, `munmap`/`mprotect` return 0.
  - `hello_mmap` printed `MMAPOK` then `BRKOK`, `MMAP_RC=0`.
  - Device after: `seq=9,1,11,12,1,60`, `map` dropped 4K from `hi`.
  - Evidence: `results/ltp/mem_out.txt`.
- [x] **`hello_min` still works** with the arena loader (`HELLO_RC=0`, `seq=1,60`).
- [x] No `wrmsr`. Kernel stayed up. Wrapper shell survived both tests.

### Busybox (glibc-static) after the arena
- TLS **allocation** now works: `brk` grew `0x…15a000` → `0x…15ad40` (+3392).
- Then `arch_prctl` (Linux 158). We return 0 without setting FS. Team stays marked (`cr3` still set, `last=158`, no exit). Hung in user code using a bad FS.
- Sequence: `brk, brk, arch_prctl`. Evidence: `results/ltp/busy2_out.txt`.
- Raw `wrmsr(IA32_FS_BASE)` is **not** the fix (Day 06: killed the Haiku wrapper). Next is a Haiku-safe SET_FS (update the thread’s saved FS).

### Proven Linux syscalls
`read`, `write`, `close`, `lseek`, `open`, `openat`, `brk`, `mmap` (ANON), `munmap`, `mprotect` (no-op), `exit`, `exit_group`. Handshake `0x1337` + arena.

### SET_FS (same day, later)
- [x] Discover `user_local_storage` offset at `dev_open` by scanning the current `Thread*` for a qword equal to `rdmsr(FS_BASE)`. This image: **`uls=0x2b0`**.
- [x] `ARCH_SET_FS` writes `[Thread+0x2b0]` then `wrmsr FS_BASE` (swapgs in/out, IF still clear).
- [x] `hello_fs` printed **`FSOK`**, `FS_RC=0`, `seq` includes 158. `hello_min` still `HELLO_RC=0`. Evidence: `results/ltp/fs_out.txt`.
- busybox after that: `brk, brk, SET_FS, set_tid_address(218), set_robust_list(273), rseq(334)`. Stubs added for 218/273/39/186; rseq returns `-ENOSYS`. Not yet a printed `BUSYBOX_ECHO`.

### Next steps
1. Watch `seq=` after the 218/273/334 stubs; add the next glibc/busybox number.
2. File-backed mmap later. ioctl still deferred.
