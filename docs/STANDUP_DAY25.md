# Developer standup: Day 25

**Module:** `sys_compat` syscall trap (no ioctl layer)
**License:** Public Domain / CC0 1.0 Universal
**Pickup / onboarding:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)
**90% map:** [SYSCALL_COVERAGE.md](SYSCALL_COVERAGE.md)

`select` and file `mmap` are guest-green. A forked child's first
syscall is now dispatched (not just `exit`/`write`). Combined
`fork`+`execve`+`poll` reached `hello_min` in the child; the parent
team crashed after poll woke.

### Proof (guest 2026-08-15)

`hello_select`: `SELECTOK`, `SELECT_RC=0`. COM1 `sSWsSWeE`.
`seq=293,23,1,23,1,60`.

`hello_mmapf`: `MMAPFOK`, `MMAPF_RC=0`. File `mmap` of
`/boot/home/hello_min` sees ELF `7f 45 4c 46`. COM1 `MmWeE`.
Guest dump: `_kern_map_file=0xd4`. `MAPFfn=0xffffffff8012c970`.

### Stamp after fork

Stamp used to return `-ENOSYS` unless the first child syscall was
`exit`/`write` (`SX21` = `dup2`). Parent has already IRETQ'd, so
`.Lstamp_done` now `jmp .Llinux_go`. Child `hello_pipeline` reached
`execve` (`xXEC` / `XGO`) and `hello_min` ran (`WeE`).

### Pipeline still open

Parent `sys_compat_run hello_pipeline` hit Haiku's team-error
dialog after poll returned (COM1 `O` mixed into the child's
`MARK` print). No `PIPELINEOK`. Next: parent join after a
blocking `poll`/`read` across child `execve`.

### Next (do not skip)

1. Finish `fork`+`execve`+`poll` parent join (`hello_pipeline`).
2. ioctl still deferred.

Landmines: stamp RIP-guard stays; dispatch the stamped syscall;
`_user_map_file` needs user name + `void**`; adopt-on-every-miss
stays **off**. ioctl deferred.
