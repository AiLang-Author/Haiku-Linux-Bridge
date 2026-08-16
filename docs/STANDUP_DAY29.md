# Developer standup: Day 29

**Module:** `sys_compat` syscall trap (no ioctl layer)
**License:** Public Domain / CC0 1.0 Universal
**Pickup:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)
**Testers:** [STATUS.md](STATUS.md)

Tried to make the Linux stack private across `_user_fork`. The pipe
is still red. Two hard facts from COM1 `PV4`:

- `N` — `[userRsp]` in the parent changed while the parent was
  held. Day 28 `k!` hex was COM1 interleave (`c`/`d`/`W`/`E` mixed
  into `0x4bdcfe`). The one-letter compare is real: the slot moves.
- `b0` — planted `rbx` is below `0x100000` (zero or junk). Ash
  sets `rbx` to a pointer before `call clone`. We are not saving
  the user's `rbx`.

`r12=0` is expected (`xor r12d,r12d` before clone).

### What we changed

`sys_compat_run` allocates the Linux stack, TLS, tramp, and arena
with Haiku `create_area` (no `B_SHARED_AREA`), touches every page,
and bounces RO→RW so fork sees a normal anonymous cache. Guest
prints `area linux_stack … prot=0x3`.

### What we tried and backed out

| Attempt | COM1 | Result |
|---|---|---|
| Write 512-byte snapshot onto the parent stack after `_user_fork` (`U`) | `U` then `R` | Desktop solid blue |
| Parent IRETQ onto `tramp+0x408` | `P` then `R` | Desktop solid blue |
| `_kern_set_memory_protection` on the stack page after hold (`W`/`w`) | `w` (failed) | Desktop solid blue |

Do not write or `mprotect` the Linux stack from the driver after
fork. Do not IRETQ the parent onto the tramp page.

### Proof (guest 2026-08-16, `PV4`)

```
K0x00000000004bdcfe
J F4 5SFgT bB H
N
b0
R
cdcWeE
```

Echo child still runs. Parent IRETQ then Kill Thread 149. No second
`F2`. Desktop stays up on `PV4`.

### Next

1. Why `gForkRbx` is 0 — save it earlier on the LSTAR path (before
   any C / `gKstack` switch), and dump the raw value on its own line.
2. Why `N` with `create_area` — if `rbx` is the real kill, `N` may
   be the child writing through a still-shared page *or* a torn
   `user_memcpy` during `cdcWeE`. Re-read `[userRsp]` after a short
   pause so the child is quiet.
3. Then `echo HI | cat` again.

ioctl still deferred.
