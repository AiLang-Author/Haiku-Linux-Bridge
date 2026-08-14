# Developer standup: Day 09

**Module:** `sys_compat` syscall trap (no ioctl layer)  
**License:** Public Domain / CC0 1.0 Universal  
**Pickup doc:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)

### Decision
Linux `rseq` (334) is implemented **in this layer**, not in the Haiku kernel.

- Haiku's scheduler *does* preempt (`cpu->preempted`) and restores `%fs` from `thread->user_local_storage`. That is Haiku TLS, not `struct rseq`.
- The Haiku tree has no `rseq` (kernel or libroot). There is nothing to "turn on."
- `rseq` is a Linux userspace ABI: register a `struct rseq`, keep `cpu_id` coherent, jump `RIP` to `abort_ip` if the thread is preempted inside a critical section.
- An upstream Haiku PR would put a Linux syscall into a non-Linux kernel. Wrong contract. Sandboxes (qemu-user, gVisor, this hook) own it.

Spec used: `/home/bob/linux/kernel/rseq.c` + `include/uapi/linux/rseq.h` (`ORIG_RSEQ_SIZE=32`, `RSEQ_FLAG_UNREGISTER=1`, x86 `RSEQ_SIG=0x53053053`).

### What landed
- [x] `sys_rseq` in `syscall_hook.S`: register, same-area re-register → `-EBUSY`, unregister, length/align/flag checks matching Linux.
- [x] On register, write `rseq_cs=0`, `flags=0`, `cpu_id_start=0`, `cpu_id=0` (one logical CPU). Returning `0` *without* those stores is why the earlier fake-success stub still died — glibc saw a live rseq and `cpu_id=-1`.
- [x] Every stub `sysret` refreshes `cpu_id=0` if a registration is live.
- [x] Loader advertises `AT_RSEQ_FEATURE_SIZE=20` and `AT_RSEQ_ALIGN=32`.
- [x] `cat /dev/misc/sys_compat` prints `rseq=` / `len=` / `sig=`.
- [x] `tests/hello_rseq.s` — register, ID check, `-EBUSY`, unregister, print `RSEQOK`.

### Not in this cut
Preempt-abort (`RIP → abort_ip` on Haiku context switch) is **not** hooked. `cpu_id` never changes, so the migrate-mismatch path does not fire. Same-CPU preemption mid-CS is a known gap. Do not pretend otherwise. Do not add a Haiku scheduler hook unless a real CS user corrupts.

### Next steps
1. Guest: rebuild driver, run `hello_min` then `hello_rseq`. Want `RSEQOK` and `RSEQ_RC=0`.
2. Re-run busybox `echo`. Watch `seq=` — success is `334` then `302` (`prlimit64`).
3. ioctl still deferred.
