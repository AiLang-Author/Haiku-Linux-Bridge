# Implementation plan (living)

**Last updated:** 2026-08-13  
**Order of work (do not skip):** syscall layer → CLI/no-GUI Linux binaries → later ioctl/drivers/graphics.

This file is the pickup document. If you are new, read this before the optimistic tables in older standups.

---

## Goal

Run **unmodified on-disk** 64-bit Linux ELFs on Haiku by trapping `syscall` and translating the Linux x86_64 ABI to Haiku `_kern_*`.

Linux `ioctl` and extra kernel drivers are **out of scope** until the syscall set below works for `hello_min`, then busybox applets (`echo`, `cat`, `uname`, `ls`).

---

## Architecture (what is actually wired)

```
Linux ELF (pristine on disk)
        |
        v
sys_compat_run  (Haiku-native loader)
  mmap PT_LOAD @ 4K pages, SysV stack, raw syscall 0x1337, jmp entry
        |
        v
CPU SYSCALL  -->  sys_compat_lstar  (LSTAR hook in kernel driver)
                    |
                    +-- rax == 0x1337     -->  store CR3 (PCID cleared), sysret 0
                    |
                    +-- CR3 != marked      -->  jmp original Haiku LSTAR  (identity)
                    |
                    +-- CR3 == marked      -->  remap Linux rax/args to Haiku _kern_*
                                               then jmp original LSTAR
                    |
                    +-- unknown Linux #    -->  sysret -ENOSYS  (no panic)
```

Handshake is **raw syscall `0x1337`**, not ioctl. `write(/dev/misc/sys_compat, "LINUXABI")` still marks, but libc `write()` can issue more Haiku syscalls after the kernel stores CR3 — that killed `hello_min`. Device `ioctl` returns `B_BAD_VALUE`. `cat /dev/misc/sys_compat` prints mark/hit counters (safe from a Haiku shell).

Marking CR3 must be the **last Haiku syscall** before `jmp` into the Linux image. After that, every `syscall` from that address space is treated as Linux. Doing `printf`/`echo` after the mark kills the Haiku team (that is expected, not a Haiku kernel bug).

If the team is **not** marked, Linux `write` (`rax=1`) is Haiku `_kern_generic_syscall` → Kill Thread. That is why a failed mark looks like a crash with no hello text.

---

## Proven vs not (2026-08-13)

| Item | Status | Evidence |
|---|---|---|
| Official Haiku `TYPE=DRIVER` link (`_KERNEL_` + `haiku_version_glue.o`) | **Works** | `nm -u` shows `dprintf@KERNEL_BASE` etc. |
| Install path `~/config/non-packaged/add-ons/kernel/drivers/` | **Works** | `/dev/misc/sys_compat` appears after reboot |
| Identity LSTAR passthrough (Haiku syscalls) | **Works** | Guest boots to desktop with hook installed |
| Loader 4K PT_LOAD map (no 64K clobber) | **Works** | Guest print: `Mapped PT_LOAD range 0x400000-0x403000` + 3 segments |
| `hello_min` host-side (Linux) | **Works** | Prints hello, rc=0 |
| Linux `write`/`exit` on Haiku via remap | **Works** | `hello_min` printed the hello line, `DONE_RC=0`, `mark=1 hits=2 last=60` (`results/ltp/hello_out.txt`) |
| Mark via raw syscall `0x1337` (no libc after) | **Works** | libc `write(LINUXABI)` was the Kill Thread; combined `syscall; jmp` is the handshake |
| Linux `read`/`close` remap | **Works** | `hello_rwc` echoed `RWC_PAYLOAD`, `DONE_RC=0`, `hits=4 last=60` (`results/ltp/rwc_out.txt`) |
| Linux `lseek` / `open` / `openat` | **Works** | `hello_fds` printed `DEFGABC`, created `/tmp/created` (`CREATED`), `hits=13 last=60` (`results/ltp/fds_out.txt`) |
| Linux `ioctl` | **Deferred** | Do not implement this layer yet |
| LTP subset staged (42 static Linux ELFs) | **Host built** | `payload/ltp/bin/` — run only after hello_min works |

A **double fault / KDL** on 2026-08-13 was **our** trampoline (`swapgs` on the Haiku path). Ring-0 `wrmsr(LSTAR)` can panic any OS; Haiku is not required to sandbox that. Current trampoline does **not** `swapgs` on the Haiku path. Failure mode for a bad Linux binary must stay **Kill Thread**, never KDL.

---

## Haiku syscall numbers (this image: hrev57937)

Dumped from `/boot/system/lib/libroot.so` `_kern_write` stub and `syscalls.h` order:

| Linux # | Linux name | Haiku # | Haiku name | Arg remap |
|---|---|---|---|---|
| 1 | `write(fd,buf,n)` | `0x97` (151) | `_kern_write(fd,pos,buf,n)` | `r10=n; rdx=buf; rsi=-1` |
| 60 / 231 | `exit` / `exit_group` | `0x29` (41) | `_kern_exit_team(status)` | `rdi` unchanged |
| 0 | `read` | `0x95` (149) | `_kern_read` | same shuffle as write |
| 2 | `open` | `0x72` (114) | `_kern_open(dirfd,path,mode,perms)` | `r10=mode; rdx=xlat(flags); rsi=path; rdi=AT_FDCWD(-100)` |
| 257 | `openat` | `0x72` (114) | `_kern_open` | `AT_FDCWD` is `-100` on both; flags translated |
| 3 | `close` | `0x9e` (158) | `_kern_close` | `rdi` only |
| 8 | `lseek` | `0x79` (121) | `_kern_seek` | args match; `SEEK_*=0/1/2` |

Confirm any new number with `payload/ltp/dump_sc.c` on the guest before adding it to `syscall_hook.S`.

---

## Next work (in this order)

1. **Prove the loader arena** (`brk` / ANON `mmap` / `munmap` / `mprotect` no-op). Coded, **not proven**. Do **not** `wrmsr` `FS_BASE` from the trampoline (that crashed the Haiku wrapper shell).
2. **busybox** is glibc-static. First failure was `Fatal glibc error: Cannot allocate TLS block` (5 syscalls then `exit_group` 231). After arena+fake `arch_prctl`, next missing call is still unknown — read `seq=` from `cat /dev/misc/sys_compat`.
3. **busybox static** `echo` / `uname` / `cat` — still no ioctl.

3. **busybox static** `echo` / `uname` / `cat` — still no ioctl.

4. **LTP smoke** from `tests/ltp_sys_compat.run` only after busybox applets work.

5. **ioctl / TTY / sockets extras** — only after the CLI set is real.

---

## How to build on Haiku

```bash
cd /boot/home/src          # or the git clone
# sources: sys_compat_dev.cpp syscall_hook.S sys_compat_abi.h Makefile.driver sys_compat_run.c
make -f Makefile.driver
make -f Makefile.driver driverinstall
gcc -O2 sys_compat_run.c -o /boot/home/sys_compat_run
# reboot so /dev/misc/sys_compat reloads
```

Host (Linux) QEMU:

```bash
./scripts/run_qemu.sh                 # KVM, QMP, usb-tablet, serial log
python3 scripts/ltp_net_server.py &   # guest fetches from 10.0.2.2:8083
```

Guest reaches the host at `10.0.2.2`. Do **not** `echo LINUXABI > /dev/misc/sys_compat` from a Haiku shell you still want alive.

---

## Commit cadence

Push a small commit after each of: a working new syscall, a loader/hook safety fix, or a standup refresh. Do not wait for a giant “all syscalls” PR.

---

## Files that matter

| Path | Role |
|---|---|
| `src/syscall_hook.S` | LSTAR trampoline |
| `src/sys_compat_dev.cpp` | `/dev/misc/sys_compat`, install/restore LSTAR |
| `src/sys_compat_abi.h` | device path + `LINUXABI` token |
| `src/sys_compat_run.c` | Haiku loader |
| `src/Makefile.driver` | official Haiku DRIVER makefile |
| `tests/hello_linux.s` | `hello_min` source (write+exit only) |
| `tests/ltp_sys_compat.run` | later LTP subset |
| `docs/IMPLEMENTATION_PLAN.md` | this file |
