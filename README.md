# Haiku-Linux-Bridge (`sys_compat`)

An out-of-tree **Linux ABI compatibility layer and kernel add-on for Haiku OS (x86_64)** that enables running 64-bit Linux ELF binaries natively on Haiku with **zero binary modification**.

---

## 📜 Public Domain / CC0 1.0 Universal License

This project is dedicated to the **Public Domain** under the **Creative Commons CC0 1.0 Universal License** (`LICENSE`).

> You can copy, modify, distribute, and perform the work, even for commercial purposes, all without asking permission.
> **Pull Requests and Community Contributions are very welcome!**

---

## 🎯 Architecture Overview

Unlike heavy virtualization or userspace emulation, `Haiku-Linux-Bridge` operates at the system call boundary:

1. **Kernel Add-on (`sys_compat`)**: Traps x86_64 CPU `syscall` vector instructions and decodes registers (`RAX`, `RDI`, `RSI`, `RDX`, `R10`, `R8`, `R9`) directly into Haiku kernel primitives (`_kern_*`, `create_area`, `delete_area`).
2. **Runtime Adapter (`sys_compat_run`)**:
   - **Strict NO BINARY MUTATION Policy**: Target Linux binaries remain 100% pristine and untouched on disk.
   - Dynamically loads `PT_LOAD` code and data segments into user memory using `mmap()`.
   - Constructs a compliant **x86_64 System V ABI Initial Stack Frame** (`argc`, `argv`, `envp`, `auxv`) on `RSP`.
   - Configures CPU **TLS `%fs` Segment Register** via raw inline assembly `arch_prctl(ARCH_SET_FS)`.

---

## Announcement (2026-08-19)

This repo is **C++ and x86_64 assembler** in the public domain (CC0). It is an out-of-tree Linux ABI for Haiku — a kernel add-on plus a loader — so unmodified 64-bit Linux ELFs can run without patching the binary and without a Linux kernel. That is the whole product. If you want to grind on the trap, fork it and send patches. That is why it is public commons.

**Where it is today**

- Static Linux ELFs launch with `sys_compat_run`. LTP `uname01` **exits 0**.
- A 58-applet busybox battery ran with **no Kill Thread and no KDL**.
- Host `strace` of that set is **55 unique Linux syscalls** (the old “~90” figure was a guess).
- Guest **curl** is Haiku’s own curl on BSD sockets. Fetch and POST to the host HTTP helper work (`--max-time` so a stuck POST cannot hang the script).
- `id` now prints `groups=0(root)` (`getgroups` guest-green).
- Tiny `hello_exit` (`exit_group(42)`) is **`EXIT42_RC=42`**. glibc `return 1` / `exit(1)` and busybox **`false` / differing `cmp` now exit 1**.
- Raw `write` then exit lands in a redirect (`hello_wr` prints `WRPROBE`). glibc `puts` prints **`PRINTF_OK`**. busybox **`date` / `md5sum` / `nproc` write** on a redirected fd. Linux **TTY ioctl** maps onto Haiku tty (`WINSZ 25x80`). Linux **`/dev/fb0`** is Haiku VESA (**1280x800x32**). Interactive **busybox ash** on the Terminal: **`echo SHLIVE`**. ELF **`hello_poll` `POLLOK`**. Blocking ELF **`poll(-1)` `POLLBLKOK`**. Stack **`pollfd` `POLLSTKOK`**. **`echo HI \| cat`** prints **`HI`** in a Haiku redirect. **`clone(CLONE_VM)` + child `exit`(60) `CLONEEXOK`**. **`CLONE_SETTLS` + `CHILD_CLEARTID` `CLONETLSOK`**. **`CLONE_THREAD` `wait4` `-ECHILD` `CLONETHROK`**. pthread_create flags **`CLONEPTOK`**.

Pickup: [`docs/IMPLEMENTATION_PLAN.md`](docs/IMPLEMENTATION_PLAN.md). Testers: [`docs/STATUS.md`](docs/STATUS.md). Punch-out list: [`docs/CLI_APPLET_PUNCHOUT.md`](docs/CLI_APPLET_PUNCHOUT.md).

## Current status (honest)

**Share this with testers:** [`docs/STATUS.md`](docs/STATUS.md) — what works, what to run, how to file a useful bug. Latest wrap: [`docs/STANDUP_DAY56.md`](docs/STANDUP_DAY56.md).

**Living pickup / onboarding plan:** [`docs/IMPLEMENTATION_PLAN.md`](docs/IMPLEMENTATION_PLAN.md) — read that first if you are changing the trap. Update it when a syscall lands or a trap changes.

Order of work: **syscall layer first** (CLI / no-GUI Linux ELFs). Linux `ioctl` and extra drivers are later.

| Piece | Status |
| :--- | :--- |
| Haiku `TYPE=DRIVER` (`_KERNEL_` / `@KERNEL_BASE`) | Works — `/dev/misc/sys_compat` loads |
| LSTAR identity passthrough for Haiku threads | Works — guest boots with the hook live |
| `sys_compat_run` 4K `PT_LOAD` map | Works on guest |
| Linux `write` / `exit` remap | **Works** on Haiku — unmodified `hello_min` printed, `DONE_RC=0` |
| Mark handshake | Raw syscall `0x1337` (not ioctl, not libc `write`) |
| Linux `read` / `close` remap | **Works** — `hello_rwc` echoed stdin, `hits=4` |
| Linux `lseek` / `open` / `openat` | **Works** — `hello_fds` seeked + created `/tmp/created` |
| Linux `brk` / ANON `mmap` / `munmap` | **Works** — `hello_mmap` printed `MMAPOK`/`BRKOK` |
| Linux `arch_prctl(SET_FS)` | **Works** — updates Haiku `user_local_storage` + FS_BASE; `hello_fs` printed `FSOK` |
| Linux `rseq` (334) | **Works** — register/unregister + `cpu_id=0`. No `STAC` (Haiku has no `CR4.SMAP`). Guest: `hello_rseq` / `RSEQOK`. |
| busybox `echo` (glibc-static) | **Works** — printed `BUSYBOX_ECHO`, `last=231` (`exit_group`) |
| Linux `uname` (63) | **Works** — busybox printed `Linux haiku 6.1.0 sys_compat x86_64 GNU/Linux` |
| busybox `cat` | **Works** — printed file contents via remapped `open`/`read`/`write` |
| busybox `ls` | **Works** — `O_DIRECTORY` → `_kern_open_dir`, `getdents64` translates Haiku dirents |
| Linux `fstat` / `newfstatat` | **Works** — `_user_read_stat` + Haiku→Linux `stat` translate. `hello_stat` / `STATOK`. busybox `ls -l` shows real types and sizes. |
| Linux `mprotect` / `munmap` / `chmod` / `chown` / `truncate` / uid / tid / `prctl` | **Works** — `_kern_write_stat` (path) + arena scratch (fd). `hello_wstat` / `WSTATOK`. Day 33. |
| Linux `rename` / `symlink` / `readlink` / `stat` / `dup` / `fsync` / `clock_gettime` | **Works** — busybox `cp` `mv` `ln -s` `readlink` `touch` `rm` `cat` RC=0. `hello_util` / `UTILOK`. |
| Linux `time` / `gettimeofday` / real RTC | **Works** — `_kern_get_clock` 0xc0. busybox `date` prints **Fri Aug 14 18:17:47 UTC 2026**. |
| Linux `fcntl` / `statx` / `fadvise64` | **Works** — `_kern_fcntl` 0x76, `statx` from `read_stat`. `hello_fcntl` / `FCNTOK`. |
| busybox grep / sed / wc / head / sort / cut | **Works** — single-process, no fork. All RC=0. |
| Linux `clone` / `wait4` / `exit` | **`hello_fork` `FORKOK`.** `CLONEEXOK`. SETTLS **`CLONETLSOK`**. `CLONE_THREAD` `wait4` `-ECHILD` **`CLONETHROK`**. pthread_create flags **`CLONEPTOK`**. See Day 21 / 51–56. |
| Linux `execve` | **Works** — `hello_exec` replaced itself with `hello_min` via `_user_exec` of `sys_compat_run`. `EXEC_RC=0`. See Day 22. |
| Linux `futex` | **Works** — WAIT/WAKE on per-thread kstack. `hello_futex` / `FUTEXOK`. See Day 23. |
| Linux `poll` / `ppoll` | **Partial** — ELF `nfds==1` **`POLLOK`**. Blocking ELF `poll(-1)` **`POLLBLKOK`**. Stack pollfd **`POLLSTKOK`**. Ash fd 0 blocking still a tty stub. Day 54. |
| Linux `select` / `pselect6` | **Works** — fd_set → poll. `hello_select` / `SELECTOK`. See Day 25. |
| Linux file `mmap` | **Works** — kernel `vm_map_file` / `_vm_map_file(..., false)`. `hello_mmapf` / `MMAPFOK`. See Day 32. |
| `fork`+`execve`+`poll` | **Works** — `hello_pipeline` / `PIPELINEOK`. Mark keeps sibling CR3 slots. See Day 26. |
| busybox `sh -c` (builtin + pipe) | **Works** — `SHOK`, `echo HI \| cat` → `HI` `SH_PIPE_RC=0`, `SHDONE`. See Day 31. |
| more busybox (`id` `pwd` `printf` `dirname` `basename` `od`) | **Works** — Day 27. |
| Core 90% syscall map | `docs/SYSCALL_COVERAGE.md` |
| LTP first-wave | **uname01** passed 2 / failed 0 / broken 0, **`UNAME_RC=0`** (Day 39). |
| busybox applet battery | `false`/`cmp` RC=1. Raw `hello_wr` **`WRPROBE`**. Redirected `date`/`md5sum`/`puts` **write** (Day 44). |
| Linux `ioctl` | **TTY + fbdev.** Terminal `TCGETS`/`TIOCGWINSZ`. `/dev/fb0` is Haiku VESA **1280x800x32** with mmap. Other cmds `-ENOTTY`. |
| LTP subset | Built on the Linux host; run after busybox applets work |

Older C files under `src/sys_*.cpp` are a prior table of handlers. The live trap is `src/syscall_hook.S` + `src/sys_compat_dev.cpp`.

---

## ⚠️ Important Caveats & Known Limitations

> [!CAUTION]
> - **Early Development Stage**: `Haiku-Linux-Bridge` is an experimental compatibility layer under active development. Many Linux syscalls remain stubbed or unimplemented.
> - **Static Binaries Preferred**: Currently, simple static 64-bit Linux binaries work best. Complex dynamically linked glibc programs requiring `ld-linux.so.2` are not yet fully functional.
> - **Kernel Stability**: Running unvalidated syscalls in the kernel module can cause thread termination or system instability. Always test inside QEMU before running on raw hardware.

---

## 🚀 Quickstart & Building Natively inside Haiku

### 1. Direct GitHub Clone (No Login Required)

Inside Haiku Terminal:

```bash
cd /boot/home
git clone https://github.com/AiLang-Author/Haiku-Linux-Bridge.git
cd Haiku-Linux-Bridge
```

### 2. Build the driver, loader, and hello_min

```bash
# Kernel driver (official makefile-engine — required for @KERNEL_BASE)
make -f src/Makefile.driver
make -f src/Makefile.driver driverinstall
# reboot so /dev/misc/sys_compat appears

# Haiku-native loader
gcc -O2 src/sys_compat_run.c -o sys_compat_run

# Tiny Linux write+exit ELF is built on Linux:
#   gcc -nostdlib -static -o tests/hello_min tests/hello_linux.s
./sys_compat_run ./tests/hello_min
```

---

## Standardized Linux Syscall Testing (LTP)

The [Linux Test Project](https://github.com/linux-test-project/ltp) is the
standard kernel syscall suite (hundreds of `testcases/kernel/syscalls/*`
directories, `runltp` / `runtest/syscalls`, plus **kirk** — the official
QEMU / SSH / network executor). It lives under `downloads/ltp` (gitignored,
GPL-2.0).

On the Linux host, with QEMU user-net the Haiku guest reaches this machine at
`10.0.2.2`:

```bash
# 1. Fetch LTP + kirk
./scripts/download_ltp.sh

# 2. Statically compile the curated sys_compat subset (tests/ltp_sys_compat.run)
./scripts/build_ltp_subset.sh

# 3. Optional: gold baseline on this Linux host
./scripts/run_ltp_host.sh

# 4. Serve binaries / collect results over the QEMU network
python3 scripts/ltp_net_server.py &          # :8083  GET payload, POST results

# 5. With Haiku already running (./scripts/run_qemu.sh)
python3 scripts/run_ltp_haiku.py             # types curl + sys_compat_run into the guest
```

Guest results land in `results/ltp/ltp_results.txt`. Kirk itself can also drive
a *Linux* QEMU image for a comparison baseline:

```bash
./downloads/ltp/tools/kirk/kirk-src/kirk \
    --com qemu:image=PATH.qcow2:user=root:password=root \
    --sut default:com=qemu \
    --run-suite syscalls
```

---

## 🤝 Contributing & Pull Requests

Contributions from the community are warmly welcomed! Whether you want to implement stubbed system calls, expand synthetic `/proc` nodes, or improve thread synchronization (`futex`/`clone`), please feel free to open a **Pull Request** or submit an **Issue** on GitHub!

- **GitHub Repository**: [https://github.com/AiLang-Author/Haiku-Linux-Bridge](https://github.com/AiLang-Author/Haiku-Linux-Bridge)
- **License**: Public Domain (CC0 1.0 Universal)
