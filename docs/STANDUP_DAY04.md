# Developer standup: Day 04

**Module:** `sys_compat` syscall trap (no ioctl layer)  
**License:** Public Domain / CC0 1.0 Universal  
**Pickup doc:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)

### Accomplishments
- [x] Wired LTP download/build/host+QEMU runners (`scripts/download_ltp.sh`, `build_ltp_subset.sh`, `ltp_net_server.py`). Suite is staged, not yet run on Haiku.
- [x] Official Haiku `TYPE=DRIVER` build (`src/Makefile.driver`) so imports are `foo@KERNEL_BASE`. `/dev/misc/sys_compat` loads after reboot.
- [x] LSTAR hook with **identity passthrough** for Haiku threads (no `swapgs`). Desktop boots with the hook live.
- [x] Handshake is `write("/dev/misc/sys_compat", "LINUXABI")`, not ioctl. Device ioctl rejected.
- [x] Loader maps all `PT_LOAD` in one 4K-aligned range (the 64K mask destroyed `hello_min` .text).
- [x] `tests/hello_linux.s` length is an immediate (`mov $0x44, %rdx`); old GAS intel `mov rdx, msg_len` loaded address `0x44` and page-faulted.
- [x] Linux `write`/`exit` remapped in `syscall_hook.S` to Haiku `_kern_write` (`0x97`) and `_kern_exit_team` (`0x29`) with the write arg shuffle. **Not yet proven on the guest.**

### Blockers / issues
- After `open(/dev/misc/sys_compat) -> 3` the Linux team still `Kill Thread`. Next step is rebuild+reboot with the remap trampoline and confirm hello text.
- A `swapgs`-on-every-syscall trampoline double-faulted KDL (our bug). Do not reintroduce stack-switch C dispatch on the Haiku path.
- Marking CR3 from a Haiku shell (`echo LINUXABI > /dev/misc/sys_compat`) kills that shell. Mark only as the last syscall before `jmp` into the Linux image.

### Next steps
1. Prove `hello_min` on Haiku.
2. Add remap rows: `read`, `close`, `lseek`, `open` — commit/push every 4–5.
3. busybox `echo`/`cat`/`uname`.
4. ioctl layer only after CLI works.
