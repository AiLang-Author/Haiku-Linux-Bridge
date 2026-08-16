# Developer standup: Day 28

**Module:** `sys_compat` syscall trap (no ioctl layer)
**License:** Public Domain / CC0 1.0 Universal
**Pickup:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)
**Testers:** [STATUS.md](STATUS.md)

Guest-installed the `rbx`/`r12`–`r15` iframe plant (`8e91d04`) and
ran `sh -c 'echo HI | cat'` without waiting on the user. The plant
is live. The pipe is still red. The parent dies after the first
clone because the Linux stack is **shared** with the child.

### Proof (guest 2026-08-16)

| Command | Result |
|---|---|
| `sh -c 'echo SHOK'` | `SHOK` `SH_ECHO_RC=0` |
| `sh -c 'true; echo SHDONE'` | `SHDONE` `SH_TRUE_RC=0` |
| `sh -c 'echo HI \| cat'` | Kill Thread 149. COM1: one `F2`, echo child `cdcWeE`, no second clone, no `x`/`XEC` |

busybox clone wrapper at `0x4e5980` is a leaf: `syscall` then
`cmp rax` / `ret`. The return address on `[userRsp]` is `0x4bdcfe`
(`mov r13d,eax` in ash's `fork()`).

COM1 on the pipe with the diagnostic hook:

```
F2 rip=0x4e59a7 rsp=… tramp=…
K0x00000000004bdcfe
J F4 5SFgT bB H
k!…
R
cdcWeE          # echo child only
```

`k!` means the 8 bytes at the parent's `[userRsp]` changed while
the parent was still in the kernel hold. The child's `ret` / frame
stores are visible in the parent aspace. Haiku `fork_team` /
`vm_copy_area` is not giving this `mmap(MAP_PRIVATE)` stack a
private COW copy.

`hello_pipeline` still works because it is asm and never `ret`s
from clone.

### What we tried (and backed out)

1. **Plant `rbx`/`r12`–`r15`** — necessary (the caller of clone uses
   `rbx`) but not sufficient. Parent dies on `ret` before that.
2. **Hold parent until child `exit`/`exec`, write the snapshot back**
   — restore `user_memcpy` did not print `N`. After the child exits
   the shared page is gone or junk (`k!` value looked like code).
3. **Parent IRETQ onto a private copy at `tramp+0x408`** — COM1 `P`
   (copy ok) then `R`, then the **desktop went solid blue**
   (app_server / Terminal died). Backed out. Do not IRETQ the parent
   onto the tramp page.

### Next

1. Make the Linux stack actually private across `_user_fork`.
   Either Haiku `mmap` of `sys_compat_run`'s stack is
   `B_SHARED_AREA`, or `vm_copy_area` is cloning it shared. Check
   `area_info.protection` on the Linux stack after mark, and
   whether `fork_team` skipped / shared that area.
2. Only then retry `echo HI | cat` (expect second `F2` + `x`/`XEC`
   + `HI` + `SHDONE`).
3. ioctl / Unix sockets still deferred.

Landmines: tramp-as-parent-stack IRETQ took down the GUI. Keep
parent IRETQ on the Linux `userRsp`. `sChildDone` is a BSS `.long`
in `syscall_hook.S` (a C `int` is a `R_X86_64_PC32` and will not
link in the driver). Force-clean `objects.*` in `go_fork.sh` —
otherwise the guest can rebuild the old `.o`.
