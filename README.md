# Haiku-Linux-Bridge (`sys_compat`)

An out-of-tree **Linux ABI Compatibility Layer** for **Haiku OS** (x86_64).

Dedicated to the Public Domain under the **CC0 1.0 Universal License**.

---

## Overview

`Haiku-Linux-Bridge` (module name: `generic/sys_compat/v1`) is an experimental out-of-tree kernel add-on for Haiku OS. It intercepts x86_64 Linux system call CPU instructions (`syscall`), decodes the Linux register ABI from Haiku's interrupt frame (`iframe`), and translates system calls directly to Haiku's internal kernel APIs (`_kern_*`, `create_area`, `delete_area`).

The primary goal of this project is to allow 64-bit Linux ELF executables to run directly on Haiku OS without modifying Haiku's kernel core.

---

## Honest Capabilities & Audit Matrix

> [!IMPORTANT]
> **Status Disclosure**: This project is in **early active development**. While basic raw system calls and static 64-bit Linux executables function, many advanced Linux kernel features and complex runtime dependencies are currently stubbed or untested.

### 1. Fully Implemented & Tested Capabilities ✅
- **Kernel Vector Trap**: Traps x86_64 `syscall` CPU instructions at the Haiku kernel boundary.
- **Register ABI Unpacking**: Unpacks `RAX` (syscall number), `RDI`, `RSI`, `RDX`, `R10`, `R8`, `R9` from `iframe`.
- **Virtual Memory & Heap**:
  - `sys_mmap` (maps protection/flags to Haiku `create_area()`).
  - `sys_munmap` (`delete_area()`), `sys_brk` (heap break expansion).
  - `sys_arch_prctl` (`ARCH_SET_FS` / `ARCH_SET_GS`) TLS segment register configuration.
- **File System & Stat Packing**:
  - `sys_openat`, `sys_read`, `sys_write`, `sys_close`, `sys_lseek`, `sys_access`, `sys_dup`, `sys_dup2`, `sys_fcntl`, `sys_unlink`, `sys_mkdir`.
  - `sys_stat`, `sys_fstat`: Repacks Haiku `struct stat` into Linux 64-bit `struct stat` layouts.
- **Socket Creation**: `sys_socket` (maps `AF_INET`, `AF_INET6`, `AF_UNIX` to Haiku `_kern_socket`), `sys_connect`, `sys_accept`, `sys_sendto`, `sys_recvfrom`.
- **Basic TTY & ioctl**:
  - `TCGETS` (termios flags), `TIOCGWINSZ` (terminal rows/cols), `FIONBIO` (non-blocking I/O).
  - `DRM_IOCTL_VERSION` (query stub returning driver `sys_compat_drm` v1.0.0).
- **Synthetic `/proc` VFS**: Synthesizes `/proc/meminfo`, `/proc/cpuinfo`, `/proc/self/status`, `/proc/self/cmdline`, `/proc/stat`.

### 2. Partially Implemented / Stubbed Capabilities 🚧
- **Signals**: `sys_rt_sigaction` and `sys_rt_sigprocmask` store signal action handlers, but asynchronous signal frame rewriting on user stacks is not yet implemented.
- **Threading (`sys_clone`)**: Spawns a Haiku thread (`spawn_thread`), but full POSIX thread-group ID (`TGID`) namespaces require further thread management.
- **Epoll**: `sys_epoll_create1` creates pipe handles, but full epoll event wait loops (`sys_epoll_wait`) rely on basic readiness stubs.
- **DRM/KMS Display Acceleration**: Returns static display resources (`1024x768`), but does not interface directly with physical GPU hardware drivers.

### 3. Currently Untested / Out of Scope for Phase 1 ❌
- **Dynamic Linking & Shared Libraries**: Dynamically linked glibc binaries require mounting Linux shared libraries (`/lib64/ld-linux-x86-64.so.2` and `libc.so.6`) inside Haiku.
- **32-bit x86 Compatibility**: Only 64-bit (`x86_64`) system calls are supported; no 32-bit thunking layer exists.
- **Advanced Linux Subsystems**: `io_uring`, `bpf`, `seccomp`, `userfaultfd`, and namespaces (`unshare`, `setns`) are currently unhandled stubs.

---

## Directory Structure

```
.
├── LICENSE                      # CC0 1.0 Universal Public Domain Dedication
├── README.md                   # Technical documentation and capability audit
├── Makefile                    # Build system for kernel addon and syntax validation
├── docs/                       # Technical specs, architecture design, and logs
│   ├── DESIGN_DOC.md           # System call vector table design & ABI mapping
│   ├── IOCTL_PREPLANNING.md    # 32-bit ioctl bitfield decoding matrix
│   ├── STANDUP_DAY01.md        # Day 1 project setup log
│   ├── STANDUP_DAY02.md        # Day 2 kernel module implementation log
│   └── STANDUP_DAY03.md        # Day 3 QEMU test log
├── src/                        # C++ Kernel Add-on Sources (generic/sys_compat/v1)
│   ├── linux_syscalls.h        # Syscall handler function declarations
│   ├── linux_sys_table.h       # Full x86_64 Linux System Call Table (0..440+)
│   ├── linux_errno.h           # Haiku status_t to negative Linux -errno mapping
│   ├── module.cpp              # Haiku kernel module entry point (std_ops)
│   ├── dispatch.cpp            # CPU trap dispatcher & dprintf serial tracer
│   ├── sys_mem.cpp             # Memory allocation (mmap/brk/munmap/arch_prctl)
│   ├── sys_file.cpp            # File I/O, socket, signal, and process handlers
│   ├── ioctl_bridge.cpp        # TTY, Socket, and DRM ioctl translation engine
│   └── proc_vfs.cpp            # Synthetic /proc filesystem generator
├── tests/                      # Static 64-bit Linux ELF C Test Suites
│   ├── hello_linux.c           # Raw syscall write & exit test
│   ├── test_file.c             # File openat, write, read, lseek, stat, unlink
│   ├── test_mem.c              # Virtual memory mmap, payload test, munmap
│   ├── test_sys.c              # System info uname, getpid, getcwd
│   ├── test_net.c              # Network socket creation & closure test
│   ├── test_ioctl.c            # TTY & DRM ioctl query test
│   └── Makefile                # Test suites build configuration
└── scripts/                    # Automation & QEMU Execution Harness
    ├── download_haiku.sh       # Downloads official Haiku R1 Beta 5 ISO
    ├── setup_buildtools.sh     # Toolchain configurator script
    ├── run_qemu.sh             # QEMU launcher with KVM hardware acceleration
    ├── debug_qemu.sh           # QEMU debug runner capturing serial kernel log
    ├── qemu_control.py         # UNIX socket control helper (qemu_monitor.sock)
    └── automate_haiku_test.py  # Test injection automation script
```

---

## Quickstart & Build Instructions

### 1. Build Test Suites (Host Linux)
```bash
make -C tests
```

### 2. Verify Kernel Add-on Syntax
```bash
make check
```

### 3. Launch QEMU Haiku Debugging Session
```bash
./scripts/debug_qemu.sh
```

### 4. Monitor Kernel Debug Logs Live
```bash
tail -f haiku_serial.log
```

---

## License

Dedicated to the Public Domain under the [CC0 1.0 Universal License](LICENSE).
