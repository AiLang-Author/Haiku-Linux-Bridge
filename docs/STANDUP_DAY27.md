# Developer standup: Day 27

**Module:** `sys_compat` syscall trap (no ioctl layer)
**License:** Public Domain / CC0 1.0 Universal
**Pickup:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)
**Testers:** [STATUS.md](STATUS.md)

More static busybox applets are guest-green. `hello_pipeline`
still prints `PIPELINEOK` after the child-return trampoline change.
busybox `sh -c 'echo SHOK'` prints `SHOK`. `sh -c 'echo HI | cat'`
now gets through stamp + FS + getpid + `set_robust_list` (`COM1`
`SFgb`) then dies before `execve`; desktop stays up.

### Proof (guest 2026-08-16)

| Command | Result |
|---|---|
| `busybox id` `pwd` `true` `printf` `dirname` `basename` `od` | RC=0 (`results/ltp/more_out.txt`) |
| `hello_min` | hello line, `HELLO_RC=0` |
| `hello_pipeline` | `PIPELINEOK` — `J` `F4` `5R` `SoxXEC` `/boot/home/hello_min` `XGO` `Vv` |
| `busybox sh -c 'echo SHOK'` | `SHOK` |
| `busybox sh -c 'echo HI \| cat'` | `F2` `J` `5R` `SFgb` then Kill Thread (no `x`/`c`/`d`) |

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

### Night addendum (still Day 27)

Parent `FS_BASE` is snapshotted at clone (`rdmsr` → `gForkFS`) and
applied on stamp (`F`). `.Lexit` no longer zeros `gLinuxFS` while a
sibling CR3 is live. Child trampoline copies 0x600 of the clone
frame onto the tramp page (parent may have already `ret`'d on the
real stack).

COM1 on the pipe is now `SFgb` — `set_robust_list` **entered**. No
`B` (C helper return), no `c`/`d`/`x`. Next: does CALL_C return
(`B` is now in the helper), and is the child's `ret` RIP junk
because `rbp` still points at the parent's stack?

### Next

1. After `SFgb`, see `B` or not. Then child's `ret` / `rbp` vs
   `execve /proc/self/exe`.
2. LTP first-wave: `uname01` `TBROK` `chown` `EFAULT`.
3. ioctl still deferred.

Landmines: do not write user pointers under CLI; `gRseqPtr` /
`gLinuxFS` are still one-team; adopt-on-miss stays off.

### Morning note (2026-08-16)

Host QEMU and the :8083 fetch server hit the session 10-hour cap
overnight. Both were restarted. Guest disk is intact. Last serial
before the reset is `haiku_serial.log.pre_timeout`. `main` is
`578fdb7`. Next grind is still `SFgb` → `B` / child `ret`.
