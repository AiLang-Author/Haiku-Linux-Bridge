# Developer standup: Day 57

**Module:** `sys_compat` syscall trap
**License:** Public Domain / CC0 1.0 Universal
**Pickup:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)
**Testers:** [STATUS.md](STATUS.md)
**Punch-out:** [CLI_APPLET_PUNCHOUT.md](CLI_APPLET_PUNCHOUT.md)

### What landed (PR53d)

glibc-static `pthread_create` uses **`clone3` (435)**, not `clone` (56).
Join is `FUTEX_WAIT_BITSET` on `ctid`. Extra-thread exit must
`FUTEX_WAKE`. `user_memcpy` of that futex word KDLd; load with user GS.

`clone3`/`clone_vm` C now runs on **this thread's kstack** (`gs:8`),
not `gKstack`. A glibc child syscall while the parent was still in
`clone3` was smashing the global C stack (kernel PF at ip 0).

glibc `__clone3(args,size,fn,arg)` does `call *%rdx` in the child.
The trampoline now restores `rdx`/`r8` from C (`fn=0x40bd10`
`start_thread`).

| Change | Why |
|---|---|
| `clone3` → `clone_vm` | glibc pthread_create never calls clone(56) |
| Futex WAIT `swapgs` load | `user_memcpy` GPF `src=0x7fffffcfff01` |
| Extra-thread `FUTEX_WAKE` after `ctid=0` | `pthread_join` waits |
| `CALL_GS8` for clone_vm/clone3 | Child must not sit on `gKstack` |
| Trampoline `movabs fn,rdx` / `arg,r8` | `__clone3` `call *%rdx` |

`hello_clonept` is still **`CLONEPTOK`**. glibc `hello_pthread` reaches
`start_thread` then **Kill Thread** (kernel stays up). Not `PTHREADOK`.

### Guest-proven

```
CLONEPTOK
CLONEPT_RC=0
```

COM1 clone3: `C3 sz=0x58 fn=0x40bd10` `FL=0x3d0f00` `FN=` `AR=` `TR=0`.
Banner `PR53d`. Extra-thread `CK` `TC` `FW` `XTX` on the assembly path.

### Do not

- `user_memcpy` Linux TLS/stack futex words.
- `CALL_C` / `gKstack` for clone_vm (child races).
- Claim glibc `pthread_create` until `PTHREADOK`.

### Next

Why `start_thread` Kill Threads (`mov %fs:0x28` / TCB). Then a green
glibc-static `pthread_create`+join.
