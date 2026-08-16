# Developer standup: Day 26

**Module:** `sys_compat` syscall trap (no ioctl layer)
**License:** Public Domain / CC0 1.0 Universal
**Pickup / onboarding:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)
**90% map:** [SYSCALL_COVERAGE.md](SYSCALL_COVERAGE.md)

Combined `fork`+`execve`+`poll` is guest-green. A marked parent
stays marked when the child execs another Linux ELF.

### Proof (guest 2026-08-15)

`hello_pipeline`: clone, pipe, child `dup2`+`execve(hello_min)`,
parent `poll`+read+"Hello"+`wait4`. Prints `PIPELINEOK`.
`PIPELINE_RC=0`. Desktop stayed up.

COM1: `F4` `5R` `SoxXEC` / `/boot/home/hello_min` / `XGO`
`OMMARK` `mQWeE` `VvWeE`.

### What was actually broken

Mark (`0x1337`) cleared all 8 CR3 slots then installed only the
new image. The child's loader mark **unmarked the parent**. Parent's
next Linux `write` became Haiku `_kern_generic_syscall` → Kill Thread
(RC=149). Stamp-after-fork dispatch was already right (`SX21` gone).

Mark now adds or refreshes the current CR3 and leaves other slots
alone. Parent scan of the pipe looks for `"Hello"` because
`sys_compat_run` prints `[+]` lines first.

### Next (do not skip)

1. `CLONE_VM` / pthread, or more CLI (busybox `sh` pipeline).
2. ioctl still deferred.

Landmines: mark must not wipe sibling teams; arena/FS/rseq
globals are still one-team; adopt-on-every-miss stays **off**.
ioctl deferred.
