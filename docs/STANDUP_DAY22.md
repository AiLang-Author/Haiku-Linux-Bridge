# Developer standup: Day 22

**Module:** `sys_compat` syscall trap (no ioctl layer)
**License:** Public Domain / CC0 1.0 Universal
**Pickup / onboarding:** [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)
**90% map:** [SYSCALL_COVERAGE.md](SYSCALL_COVERAGE.md)

Linux `execve` is guest-green. A marked team replaces itself with
another Linux ELF via Haiku `_user_exec` of `sys_compat_run`.

### Proof (guest 2026-08-15)

`hello_exec` does `execve("/boot/home/hello_min")`. The replaced
process prints hello_min's line. `EXEC_RC=0`. No `EXECFAIL`, no
`XNO`. Desktop stayed up.

COM1:

```
xXEC
/boot/home/hello_min
XGO
MMARK team=0x0000000000000255
mQWeE
```

`seq=59,1,60` (execve, write, exit). `mark=2 hits=3 last=60`.

Guest `dump_sc`: `_kern_exec nr=0x2e` sits between
`wait_for_child=0x2d` and `fork=0x2f`. `EXECfn=0xffffffff80082290`.

### How it works

`.Lexecve` stays on `gs:8`, saves `rcx`/`r11`, switches to `gKstack`
with `RBP` set (leftover user RBP #PF), STI, calls
`sys_compat_execve`. Flatten lives in BSS (12 KB autos overflow
the 16 KB kstack). Path + flatArgs are **user** addresses in
scratch at `RSP-8192`. Unmark this CR3, then
`_user_exec("/boot/home/sys_compat_run", [loader, linux_path, argv[1]…])`.
Success never returns (`team_create_thread_start`). Failure
prints `XNO st=` and restores the mark.

The new image is a native Haiku loader. It marks via `0x1337` and
`jmp`s the Linux ELF — same proven handshake as `hello_min`.

### What is still open

| Step | Result |
|---|---|
| `hello_exec` → `hello_min` | **`EXEC_RC=0`** |
| `CLONE_VM` / futex | Open (pthread) |
| ioctl | Deferred |

### Next (do not skip)

1. `futex` + `rt_sigaction` (no-op install) — pthread/glibc edges.
2. ioctl / TTY / sockets only after the CLI 90% set is green.

Landmines: `_user_exec` needs user pointers; unmark before exec so
the loader is not treated as Linux; `RBP` before C on `gKstack`;
flatten in BSS; adopt-on-every-miss stays **off**. ioctl deferred.
