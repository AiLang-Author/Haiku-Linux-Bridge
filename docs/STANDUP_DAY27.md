# Developer standup: Day 27

**Module:** `sys_compat` syscall trap (no ioctl layer)
**License:** Public Domain / CC0 1.0 Universal
**Pickup:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)
**Testers:** [STATUS.md](STATUS.md)

More static busybox applets are guest-green. `hello_pipeline`
still prints `PIPELINEOK` after the child-return trampoline change.
busybox `sh -c 'echo SHOK'` prints `SHOK`. `sh -c 'echo HI | cat'`
stamps the child (`COM1` `5RS`) then dies; desktop stays up.

### Proof (guest 2026-08-16)

| Command | Result |
|---|---|
| `busybox id` `pwd` `true` `printf` `dirname` `basename` `od` | RC=0 (`results/ltp/more_out.txt`) |
| `hello_min` | hello line, `HELLO_RC=0` |
| `hello_pipeline` | `PIPELINEOK` — `J` `F4` `5R` `SoxXEC` `/boot/home/hello_min` `XGO` `Vv` |
| `busybox sh -c 'echo SHOK'` | `SHOK` |
| `busybox sh -c 'echo HI \| cat'` | child `F2` `J` `5RS` then team dies (no KDL) |

### What broke (and what we changed)

1. **Stamp window** — busybox clone return is `0x4e59a7`, outside the
   old `0x400000..0x405000` guard. Widened to `0x1000000`.
2. **Child stack / FS** — glibc clone immediately does `mov rax,fs:0x10`.
   Haiku fork does not copy Linux `FS_BASE`. Child trampoline now
   `getpid` (stamps + `apply_fs`), `xor eax,eax` (so `hello_pipeline`
   still sees a child), then switches to the Linux stack and jumps to
   the clone return.
3. **KDL** — `.Lret` stored into `gRseqPtr` under CLI. After fork that
   user page is COW-RO → `page fault, interrupts were disabled` at
   `sys_compat_lstar+0x2240`. That store is gone. `user_memcpy` into
   the tramp page is done with `sti`.
4. **`/proc/self/exe` + `sendfile`** — wired for ash `exec` of `cat`.
   Not guest-proven on the pipe (team dies first).

### Next

1. After `5RS`, find the next child syscall that kills the team
   (likely `set_robust_list` / `execve /proc/self/exe` / `sendfile`).
2. LTP first-wave: `uname01` reached the binary then `TBROK` `chown`
   `EFAULT`. Do not run clone/exec LTP until the rseq/FS path is
   boring.
3. ioctl still deferred.

Landmines: do not write user pointers under CLI; `gRseqPtr` /
`gLinuxFS` are still one-team; adopt-on-miss stays off.
