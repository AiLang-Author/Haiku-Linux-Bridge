# Developer standup: Day 15

**Module:** `sys_compat` syscall trap (no ioctl layer)
**License:** Public Domain / CC0 1.0 Universal
**Pickup / onboarding:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)
**90% map:** [SYSCALL_COVERAGE.md](SYSCALL_COVERAGE.md)

COM1 isolation wrap. `_user_fork` from a planted iframe **returns a
child team id**. The silent reboot is **not** child IRETQ and **not**
the IRETQ instruction. It is returning the parent into the Linux ELF
at `0x40101c` after `fork_team`.

### COM1 (Haiku RS232)

QEMU `-serial file:haiku_serial.log` is COM1 `0x3F8`. Hook `KSER`
writes there even when `serial_debug_output` is off. KDL also uses
this UART. `-serial file:` is output-only.

Alphabet: `M/m/Q` mark, `C123` clone, `F2/F4/F5` plant+`_user_fork`,
`P` parent dump, `7/9/Y/Z` return path.

| Test | Serial | Guest |
|---|---|---|
| Plant + `_user_fork` | `F5 st=0x1ac` / `0x1ad` | Child team created |
| Park parent in kernel after `9` (`cli; jmp .`) | Stops at `9` | **Stayed up** |
| Parent `SYSRET` (`mov rsp, linux; swapgs; sysretq`) | Stops at `9` | Reboot, no KDL |
| Parent `IRETQ` to Linux `RIP=0x40101c` | Stops at `7Y` | Reboot, no KDL |
| Parent `IRETQ` to trampoline `eb fe` + Haiku stack | Stops at `7YZ` | **Stayed up** |
| Parent `IRETQ` to `0x40101c` + Haiku stack | Stops at `7YZ` | Reboot |

Captured DF (older parent SYSRET cut): thread `sys_compat_run`,
`RIP=sys_compat_lstar+0xa63`, `RSP` = Linux user stack,
`RCX=0x23` (`USER_SS`). Kernel epilogue on the Linux stack after
`swapgs` → Double Fault.

### What we ruled out

- Child IRETQ taking the box down (parent parked; other CPUs free).
- IRETQ as an instruction (both sides can land on `eb fe`).
- Linux vs Haiku **stack** as the only trigger (Haiku stack + Linux
  RIP still reboots).
- Missing iframe / `gKstack` plant (F5 proves `_user_fork` ran).

### What is left

Return into `0x400000` after fork. Leading hypotheses: parent CR3
changed and the next Linux `write(1)` (`PRE`) misses the mark table;
the `0x400000` page is not executable after COW; first user `#PF`
after our `swapgs; iretq` still has a bad GS.

`gForkPending` already stamps CR3 on syscall `1`/`60`/`231`. Linux
`write` is also `1` — that path may be doing the wrong thing.

### Next (do not skip)

1. Re-read CR3 after `_user_fork` and stamp the parent before any
   user return. `KSER 'W'` on Linux write.
2. Parent `PRE` without a reset. Then restore the real trampoline
   (`movabs rsp/rip; jmp`) instead of `eb fe`.
3. Stamp child CR3 so Linux `exit` 60 ≠ `_kern_cancel_thread`.
4. `wait4`, then `execve`.
5. pthread / ioctl later.

Landmines this round: `jne 1f` next to `KSER` (jumps into the UART
wait); user-mode `HLT` is `#GP`; `gSavedRsp` raced under `sti` (save
on `gKstack` / dedicated globals); do not truncate `haiku_serial.log`
while QEMU has the fd; replacing the driver file does not reload the
in-memory module (reboot).

Adopt-on-every-miss stays **off**. ioctl still deferred.
