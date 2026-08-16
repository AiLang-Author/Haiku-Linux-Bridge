# Implementation plan (living)

**Last updated:** 2026-08-15 (Day 22: Linux `execve` → `hello_min`; `EXEC_RC=0`)  
**Order of work (do not skip):** syscall layer → CLI/no-GUI Linux binaries → later ioctl/drivers/graphics.

This file is the **pickup and onboarding document**. If you are new, read
this before `DESIGN_DOC.md` (that draft is older than the live trap) and
before the optimistic tables in standups before Day 10.

Standups: [Day 13](STANDUP_DAY13.md) (first reboot diagnosis) →
[Day 14](STANDUP_DAY14.md) (ruled out Haiku fork + ELF COW) →
[Day 15](STANDUP_DAY15.md) (COM1: IRETQ itself is fine) →
[Day 16](STANDUP_DAY16.md) (official return; parent user mode lives) →
[Day 17](STANDUP_DAY17.md) (parent `PRE` after fork; guest lives) →
[Day 18](STANDUP_DAY18.md) (IRETQ to `0x40101c`; child CR3 stamps) →
[Day 19](STANDUP_DAY19.md) (kstack Linux dispatch; `wait4` reached) →
[Day 20](STANDUP_DAY20.md) (`hello_fork` / `FORKOK`) →
[Day 21](STANDUP_DAY21.md) (child IRETQ to `0x40101c`; stamp only Linux RIP) →
[Day 22](STANDUP_DAY22.md) (Linux `execve` via `_user_exec` of `sys_compat_run`).

---

## Onboarding (new developer)

You are joining an **out-of-tree Linux ABI** so unmodified 64-bit Linux
ELFs run on Haiku. Work is a pyramid: keep building the base, then a
narrower layer. The completed app is the tip. Keep feature creep down.

| Rule | Why |
|---|---|
| Syscall layer first, then CLI/no-GUI | ioctl/graphics wait until the CLI 90% set is mostly green |
| Bare Linux binaries (not compiled on Haiku) | The product is an ABI, not a port |
| Kernel must stay up | Kill Thread is OK; KDL / silent reboot is not |
| Mark (syscall `0x1337`) is the last Haiku action before `jmp` | Any libc after mark is treated as Linux and dies |
| No ioctl unless a CLI path is blocked without it | Deferred on purpose |
| Adopt-on-every-CR3-miss stays **off** | That killed Terminal / KDL |
| Do not call libroot `real_time_clock_usecs` / `system_time` from the driver | KDL on this image |
| Confirm Haiku syscall numbers on the **guest** (`payload/ltp/dump_sc.c`) | They shift between Haiku revisions |

**Live trap** is `src/syscall_hook.S` + `src/sys_compat_dev.cpp` +
`src/sys_compat_run.c`. Older `src/sys_*.cpp` / `DESIGN_DOC.md` tables
are not the running path.

**Guest:** QEMU KVM, disk-only (`-boot order=c`), serial
`haiku_serial.log` (COM1 `0x3F8`), QMP `qemu_qmp.sock`. Host HTTP at
`10.0.2.2:8083` (`scripts/ltp_net_server.py`). No UserBootscript for
risky tests. Deskbar leaf → Applications → Terminal is more reliable
than Tracker search. Do not truncate `haiku_serial.log` while QEMU
has it open — copy it first. Hook `KSER` breadcrumbs write COM1
directly; `dprintf` is silent unless `serial_debug_output` is on.
`-serial file:` is output-only (no `kdebug>` typing).

**Image:** Haiku hrev57937 (R1/beta5). After `swapgs`, GS = `arch_thread`:
`gs:0` = `Thread*`, `gs:8` = `syscall_rsp` = `kernel_stack_top`.
`KERNEL_STACK_SIZE` is 16 KB; debug builds add a 4 KB guard (area 20 KB).
This Haiku has **no CR4.SMAP** — do not emit `STAC`.

**Where we are (Day 22):** single-process Linux CLI is guest-green.
`hello_fork` is guest-green (child IRETQ to `0x40101c`). **Linux
`execve` is guest-green:** `hello_exec` replaced itself with
`hello_min` via Haiku `_user_exec` of `sys_compat_run`. COM1
`x` / `XEC` / `XGO` / `MMARK` / `WeE`, `EXEC_RC=0`, hello line
printed. Guest dump: `_kern_exec=0x2e`. Stamp-on-fork only if
user RIP is in `0x400000..0x405000` or the tramp page.

**What needs doing next:** `futex` + `rt_sigaction` (pthread/glibc
edges). `CLONE_VM` later. ioctl still later.

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

## Proven vs not (2026-08-14)

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
| Linux `brk` / ANON `mmap` / `munmap` | **Works** | `hello_mmap` printed `MMAPOK`/`BRKOK`, `seq=9,1,11,12,1,60`, arena carved 4K (`results/ltp/mem_out.txt`) |
| Loader 32 MB arena via `0x1337` (rdi,rsi) | **Works** | Device `brk=`/`hi=` span 32 MB after mark; `hello_min` still `HELLO_RC=0` |
| Linux `arch_prctl(ARCH_SET_FS)` | **Works** | Writes `thread->user_local_storage` (offset `0x2b0` on this image) + `FS_BASE`. `hello_fs` printed `FSOK` (`results/ltp/fs_out.txt`) |
| Linux `rseq` (334) | **Works** | Register/unregister from `linux/kernel/rseq.c`. `cpu_id=0`. No `STAC` (this Haiku has no `CR4.SMAP` — that was `#UD`/KDL). Guest: `hello_rseq` printed `RSEQOK`, `seq=334,334,334,1,60`. |
| Linux `ioctl` | **Deferred** | Do not implement this layer yet |
| busybox `echo` (glibc-static) | **Works** | Printed `BUSYBOX_ECHO`, `hits=22`, `last=231` (`exit_group`). Kernel and wrapper shell stayed up. |
| Linux `uname` (63) | **Works** | Fills `utsname` (`Linux`/`haiku`/`6.1.0`/`sys_compat`/`x86_64`). busybox printed `Linux haiku 6.1.0 sys_compat x86_64 GNU/Linux`. |
| busybox `cat` | **Works** | Printed `catme` from `/tmp/catme`. `seq` includes `0`/`1`/`3` (read/write/close). |
| Linux `getdents64` (217) + `open` `O_DIRECTORY` | **Works** | Haiku needs `_kern_open_dir` (0x74) or `read_dir` is `B_UNSUPPORTED`. Convert Haiku `dirent` (`dev_t` is 32-bit) to `linux_dirent64`. busybox `ls /boot/home` printed real names. |
| Linux `ioctl` (16) | **Stub** | `-ENOTTY`. Enough for `ls`. |
| Linux `fstat` / `newfstatat` | **Works** | `_user_read_stat` via `kSyscallInfos[0x9c]`. Haiku `stat` (128 B, 32-bit `dev_t`) → Linux `stat` (144 B). Guest: `hello_stat` printed `STATOK`; busybox `ls -l` shows real types/sizes (`results/ltp/stat_out.txt`). |
| LTP first-wave (17 bins) | **Measured** | `hello_min` pass. 16 LTP ELFs TBROK in the harness (`mkdtemp` → `mkdir` ENOSYS). Kernel stayed up. `results/ltp/ltp_smoke.txt`. |
| Linux `mkdir`/`getcwd`/`chdir`/`unlink`/`access` | **Works** | `_kern_create_dir` 0x7b etc. LTP tmpdir is created. Next harness walls were `chown` then `statfs` (stubbed). Real test still needs `clone`. |
| Linux `mprotect`/`munmap`/`chmod`/`chown`/`truncate`/`getuid`/`prctl`/`gettid` | **Works** | Guest dump: `write_stat=0x9d` `unmap=0xd5` `mprotect=0xd6` `rename_thread=0x38`. `hello_wstat` printed `WSTATOK`, `WSTAT_RC=0`, `hits=32`. `setuid`/`setgid` are layer-local; `set_tid_address`/`set_robust_list` store and return 0/`tid`. |
| Linux `rename`/`symlink`/`readlink`/`stat`/`lstat`/`dup`/`fsync`/`clock_gettime`/`utimensat` | **Works** | Guest dump: `rename=0x81` `symlink=0x7e` `read_link=0x7d` `dup=0x9f` `fsync=0x77`. `hello_util` **UTILOK**. busybox `cp`/`mv`/`ln -s`/`readlink`/`touch`/`rm`/`cat`/`echo`/`ls` all RC=0. Hard `link` may EPERM. Adopt-on-CR3-miss is off. |
| Linux `time`/`gettimeofday`/`clock_gettime` (real RTC) | **Works** | `_kern_get_clock` **0xc0** (not libroot `real_time_clock_usecs` — that KDLs). `hello_date` **DATEOK 1786731467**. busybox `date` / `date -u` printed **Fri Aug 14 18:17:47 UTC 2026**. |
| Linux `fcntl` / `statx` / `fadvise64` | **Works** | `_kern_fcntl` **0x76** (guest dump). Linux F_* / O_APPEND / O_NONBLOCK translated. `statx` from `_kern_read_stat` (256 B, size@40 mode@28). `hello_fcntl` **FCNTOK**. `hello_min` + `hello_date` still green. |
| busybox text CLI (no spawn) | **Works** | Unmodified `grep` `wc` `sed` `head` `sort` `cut` all RC=0 on `/tmp/cli.txt`. `results/ltp/cli_out.txt`. |
| Linux `clone` / `wait4` / `exit` | **Works** | `hello_fork` `FORKOK` RC=0. Child IRETQ to `0x40101c`. Stamp RIP-guarded. Day 20–21. |
| Linux `execve` (59) | **Works** | `_user_exec` 0x2e of `sys_compat_run <linux_path>`. Unmark first. `hello_exec` → `hello_min` hello line, `EXEC_RC=0`. COM1 `xXEC` / `XGO`. Day 22. |
| Core 90% syscall map | **Written** | `docs/SYSCALL_COVERAGE.md` — remaining holes: `futex`, `poll`, real signals, `CLONE_VM`. ioctl after that. |
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
| 5 / 262 | `fstat` / `newfstatat` | `0x9c` (156) | `_kern_read_stat(fd,path,traverse,stat,statSize)` | C helper; convert 128 B Haiku `stat` → 144 B Linux `stat` |
| 83 / 258 | `mkdir` / `mkdirat` | `0x7b` (123) | `_kern_create_dir(fd,path,perms)` | C helper; Haiku `status_t` → Linux errno |
| 79 / 80 / 81 | `getcwd` / `chdir` / `fchdir` | `0x92` / `0x93` | `_kern_getcwd` / `_kern_setcwd` | `getcwd` returns the buffer pointer |
| 87 / 84 / 263 | `unlink` / `rmdir` / `unlinkat` | `0x80` / `0x7c` | `_kern_unlink` / `_kern_remove_dir` | `AT_REMOVEDIR` → remove_dir |
| 21 | `access` | `0x84` (132) | `_kern_access` | C helper |
| 10 / 11 | `mprotect` / `munmap` | `0xd6` / `0xd5` | `_kern_set_memory_protection` / `_kern_unmap_memory` | `PROT_*` low 3 bits = `B_*_AREA`. Arena carve is a no-op unmap. |
| 90 / 91 / 268 | `chmod` / `fchmod` / `fchmodat` | `0x9d` | `_kern_write_stat` + `B_STAT_MODE` | C helper; user-stack scratch for Haiku `stat` |
| 92 / 93 / 94 / 260 | `chown` / `fchown` / `lchown` / `fchownat` | `0x9d` | `_kern_write_stat` + `B_STAT_UID`/`GID` | uid/gid `-1` skips that bit |
| 76 / 77 | `truncate` / `ftruncate` | `0x9d` | `_kern_write_stat` + `B_STAT_SIZE` | C helper |
| 102 / 107 / 104 / 108 | `getuid` / `geteuid` / `getgid` / `getegid` | — | `get_team_info` or last `setuid`/`setgid` | euid aliases uid |
| 105 / 106 | `setuid` / `setgid` | — | layer-local store | enough for glibc queries; does not change Haiku creds |
| 186 / 218 / 273 | `gettid` / `set_tid_address` / `set_robust_list` | — | `find_thread(NULL)` + store | clear-tid on exit not wired |
| 157 | `prctl` | `0x38` | `_kern_rename_thread` for `PR_SET_NAME` | `GET_NAME` via `get_thread_info`; dumpable/pdeathsig return 0 |
| 82 / 264 / 316 | `rename` / `renameat` / `renameat2` | `0x81` | `_kern_rename` | `renameat2` flags≠0 → `-EINVAL` |
| 88 / 266 | `symlink` / `symlinkat` | `0x7e` | `_kern_create_symlink` | Linux (target, path) → Haiku (path, target) |
| 89 / 267 | `readlink` / `readlinkat` | `0x7d` | `_kern_read_link` | size is in/out user pointer |
| 86 / 265 | `link` / `linkat` | `0x7f` | `_kern_create_link` | may EPERM if the volume rejects hard links |
| 4 / 6 | `stat` / `lstat` | `0x9c` | same C helper as `newfstatat` | |
| 32 / 33 / 292 | `dup` / `dup2` / `dup3` | `0x9f` / `0xa0` | `_kern_dup` / `_kern_dup2` | return the new fd, not 0 |
| 74 / 75 | `fsync` / `fdatasync` | `0x77` | `_kern_fsync` | |
| 228 / 280 | `clock_gettime` / `utimensat` | `0xc0` | `_kern_get_clock` + rdtsc fallback | do **not** call libroot `real_time_clock_usecs` |
| 201 / 96 | `time` / `gettimeofday` | `0xc0` | same clock helper | busybox `date` prints real UTC |
| 72 | `fcntl` | `0x76` (118) | `_kern_fcntl` | Linux F_0/1/2/3/4/1030 → Haiku 0x1/0x2/0x4/0x8/0x10/0x200. GETFL flag xlat. Return fd/flags, not 0. |
| 332 | `statx` | `0x9c` | `_kern_read_stat` | 256-byte Linux `statx`; BASIC\|BTIME; size@40 mode@28 |
| 221 | `fadvise64` | — | no-op 0 | POSIX hint |
| 17 / 18 | `pread64` / `pwrite64` | `0x95` / `0x97` | `_kern_read`/`_kern_write` with pos | remap only |
| 19 / 20 | `writev` / `readv` | `0x98` / `0x96` | `_kern_writev`/`_kern_readv` pos=-1 | remap only |
| 22 / 293 | `pipe` / `pipe2` | `0x83` | `_kern_create_pipe` | O_CLOEXEC/NONBLOCK translated |
| 110 | `getppid` | — | `get_team_info.parent` | |
| 59 | `execve` | `0x2e` (46) | `_kern_exec` | Flatten to `sys_compat_run` + linux path; unmark; user pointers |

Confirm any new number with `payload/ltp/dump_sc.c` on the guest before adding it to `syscall_hook.S`. Guest `unmap`/`mprotect` are `0xd5`/`0xd6` on hrev57937 — later Haiku sources insert two syscalls and shift them to `0xd7`/`0xd8`.

---

## Fork contract (Haiku source, not a tracker bug)

`_user_fork` → `fork_team` → `arch_store_fork_frame` →
`x86_get_current_iframe()`. That walk only accepts an iframe on **this
thread’s** `kernel_stack_base..top`, found via RBP, with `type` in the
low nibble (`IFRAME_TYPE_SYSCALL` = 1). Official `x86_64_syscall_entry`
plants it at `kernel_stack_top` and sets `RBP=RSP=iframe`. Comment in
`arch_thread.cpp`: *must only be called from syscalls*.

Child path is **IRETQ after `swapgs`**, not SYSRET
(`arch_restore_fork_frame` → `x86_return_to_userland`). Bad CS/SS/IP/flags
after that `swapgs` is a triple fault: no KDL, empty serial. Ticket
#18692 (DF IST) is already fixed on hrev57937; a triple fault still
looks like a silent reset.

`.Ltry_fork` now **does** call `sys_compat_try_fork`: after `swapgs` it
switches to `gKstack`, plants an `IFRAME_TYPE_SYSCALL` at the **real**
kstack top (`gs:8` / scan 16K or 20K), `RBP=RSP=iframe`, and `call`s
`_user_fork`. Child iframe: `cs=0x2b ss=0x23 flags=0x202`, `ip` =
loader trampoline (currently overwritten `eb fe`), `sp` = Haiku RSP
passed in mark `r8`. Parent return must **not** run kernel code on the
Linux user stack (`mov rsp,user; swapgs; sysretq` Double Faulted at
`sys_compat_lstar+0xa63`, `rcx=USER_SS`). Parent IRETQ from `gKstack`
to the trampoline stays up.

`sys_compat_run` skips the 32 MB arena when the path contains `"fork"`,
maps a 4K RXW trampoline, and does **no** Haiku-side `fork()` before
mark (that sequence rebooted before Linux clone). Mark `0x1337` takes
`rdx=tramp`, `r8=haiku RSP`.

Do not use `0xffffff0000000000` as a kstack upper bound — that address
is *below* real Haiku stacks (`0xffffffff877f0000`). `gKstack` is still
a single global (QEMU `-smp 4`). `jne 1f` next to `KSER` jumps into the
macro’s UART-wait `1:` — use `.Lnotclone`. User-mode `HLT` is `#GP`.
Do not truncate `haiku_serial.log` while QEMU holds the fd.

---

## Next work (in this order)

See `docs/SYSCALL_COVERAGE.md` for the ~90-syscall “90% of software” table.

1. **`futex` + `rt_sigaction` (no-op install)** — pthread/glibc edges.
   `clone`/`wait4`/`execve`/`exit` are guest-green. Adopt-on-every-miss
   stays off.
2. **ioctl / TTY / sockets** — only after the CLI 90% set is green.
   Rare/deprecated numbers wait for a filed issue.

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
| `tests/hello_rseq.s` | Linux `rseq` register / EBUSY / unregister |
| `tests/hello_stat.s` | Linux `newfstatat` + `fstat` (dir vs file, size match) |
| `tests/hello_wstat.s` | uid/tid/prctl/mprotect/chmod/chown/truncate pack |
| `tests/hello_util.s` | rename/symlink/readlink/stat/clock/dup/fsync/utimensat |
| `tests/hello_date.s` | `time` + `gettimeofday` + `clock_gettime` (unix sec) |
| `tests/hello_fcntl.s` | `fcntl` GET/SET FL/FD + DUPFD + `statx` + `fadvise64` |
| `scripts/guest_run_cli.sh` | busybox grep/sed/wc/head/sort/cut |
| `tests/hello_fork_probe.s` | Linux clone then parent `PRE` + both spin (no child syscall) |
| `tests/haiku_native_fork.c` | Native Haiku `fork()` smoke (gcc on the guest) |
| `tests/hello_fork.s` | clone + wait4; `FORKOK` Day 20–21 |
| `tests/hello_exec.s` | Linux `execve("/boot/home/hello_min")`; `EXEC_RC=0` Day 22 |
| `scripts/guest_go_fork.sh` | Guest: fetch sources, build driver, no bootscript |
| `scripts/guest_run_fork.sh` | Guest: fork probe only; POST `fork_out.txt` |
| `scripts/guest_run_exec.sh` | Guest: execve probe; POST `exec_out.txt` |
| `scripts/guest_term.py` | Host: open Haiku Terminal via Tracker + type |
| `docs/STANDUP_DAY14.md` | Day 14 wrap: `_kern_fork` itself is fine |
| `docs/STANDUP_DAY15.md` | Day 15 wrap: COM1 isolation of the reboot |
| `docs/STANDUP_DAY16.md` | Day 16 wrap: official return, parent user mode |
| `docs/STANDUP_DAY17.md` | Day 17 wrap: parent `PRE` after fork |
| `docs/STANDUP_DAY18.md` | Day 18 wrap: IRETQ to `0x40101c`; child stamp |
| `docs/STANDUP_DAY19.md` | Day 19 wrap: kstack dispatch; `wait4` entered |
| `docs/STANDUP_DAY20.md` | Day 20 wrap: `hello_fork` / `FORKOK` |
| `docs/STANDUP_DAY21.md` | Day 21 wrap: child to `0x40101c`; RIP-guarded stamp |
| `docs/STANDUP_DAY22.md` | Day 22 wrap: Linux `execve` / `hello_min` |
| `scripts/guest_dump_syslog.sh` | Pull `/var/log/previous_syslog` after a reset |
| `docs/SYSCALL_COVERAGE.md` | Core ~90 syscall 90% map |
| `tests/ltp_sys_compat.run` | later LTP subset |
| `docs/IMPLEMENTATION_PLAN.md` | this file |
| `docs/SYSCALL_COVERAGE.md` | Core ~90 syscall 90% map |
| `tests/ltp_sys_compat.run` | later LTP subset |
| `docs/IMPLEMENTATION_PLAN.md` | this file |
