# Developer standup: Day 05

**Module:** `sys_compat` syscall trap (no ioctl layer)  
**License:** Public Domain / CC0 1.0 Universal  
**Pickup doc:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)

### Accomplishments
- [x] **First unmodified Linux ELF on Haiku.** `hello_min` (write+exit only) printed:
  `Hello from unmodified Linux binary running on Haiku via sys_compat!`
  `DONE_RC=0`, device status `mark=1 hits=2 last=60`. Evidence: `results/ltp/hello_out.txt`.
- [x] Handshake is now raw syscall `0x1337` in the LSTAR trampoline, then `jmp` in the same asm block. libc `write("LINUXABI")` was marking CR3 *then* issuing more Haiku syscalls; Linux `write` (`rax=1`) became Haiku `_kern_generic_syscall` → Kill Thread.
- [x] CR3 compare masks PCID bits. Exit remap clears `gLinuxCR3`. `cat /dev/misc/sys_compat` prints `cr3/orig/mark/hits/last`.
- [x] Guest `dump_sc` confirmed this image: `_kern_read=0x95`, `_kern_write=0x97`, `_kern_close=0x9e`, `_kern_seek=0x79`, `_kern_open=0x72`, `_kern_exit_team=0x29`. 4th arg is `r10` (`49 89 ca` in the 4-arg stubs).
- [x] `read` + `close` remaps **proven**. `hello_rwc` read stdin, wrote `RWC_PAYLOAD`, closed fd 0, exited 0. `hits=4 last=60`. Evidence: `results/ltp/rwc_out.txt`.

### Blockers / issues
- Do not `echo LINUXABI > /dev/misc/sys_compat` from a shell you still want. Mark only via `0x1337` as the last action before `jmp`.
- A `swapgs`-on-every-syscall trampoline double-faulted (Day 04). Stay on identity passthrough for unmarked CR3.

### Next steps
1. `lseek`, then `open`/`openat` (flag translation).
2. `brk` / `mmap` so busybox `echo`/`cat`/`uname` can start.
3. ioctl layer only after CLI works.
