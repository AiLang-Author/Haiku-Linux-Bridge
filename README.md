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

## 📊 Tested Capabilities & Realistic Audit Matrix

We prioritize complete transparency regarding what works, what is stubbed, and what is currently untested:

| Category | Component / Syscall | Status | Caveats & Implementation Notes |
| :--- | :--- | :--- | :--- |
| **Loader** | Pristine 64-bit Static Linux ELF | ✅ **Tested** | Loaded via `sys_compat_run` without disk binary modification. |
| **Loader** | System V ABI Initial Stack (`RSP`) | ✅ **Tested** | Pushes `argc`, `argv`, `envp`, `auxv` (`AT_PAGESZ=4096`, `AT_NULL=0`). |
| **Loader** | TLS `%fs` Base Setup (`arch_prctl`) | ✅ **Tested** | Configured via raw `SYS_ARCH_PRCTL` (158) inline assembly syscall. |
| **Memory** | `mmap`, `munmap`, `brk` | ✅ **Tested** | Mapped to Haiku `create_area` / `delete_area` memory manager. |
| **File I/O** | `read`, `write`, `open`, `close`, `lseek` | ✅ **Tested** | Trapped and translated to Haiku `_kern_read`, `_kern_write`, etc. |
| **File I/O** | `stat`, `fstat`, `lstat` | ✅ **Tested** | Struct field mapping between Linux `stat64` and Haiku kernel `stat`. |
| **Process** | `getpid`, `getuid`, `getgid`, `uname` | ✅ **Tested** | Basic identity and POSIX system info queries return valid data. |
| **Networking** | `socket`, `bind`, `connect`, `listen`, `accept`, `sendto`, `recvfrom` | ✅ **Tested** | IPv4/IPv6 socket operations routed to Haiku kernel socket stack. |
| **Events** | `poll`, `select`, `epoll_create1`, `epoll_ctl`, `epoll_pwait` | ✅ **Tested** | Integrated with Haiku kernel `_kern_poll` / `_kern_select` event engines. |
| **Signals** | `rt_sigaction`, `rt_sigprocmask` | ✅ **Tested** | Signal action table registration & signal mask blocking supported. |
| **VFS** | Synthetic `/proc` & `/sys` Nodes | ✅ **Tested** | `/proc/meminfo`, `/proc/cpuinfo`, `/proc/self/exe`, `/proc/mounts`, `/proc/uptime`, `/proc/stat`, `/sys/...` |
| **I/O Control**| `ioctl` (TTY, Sockets, DRM/KMS) | ⚠️ **Partial** | Basic TTY (`0x54`), socket (`0x89`), and DRM version queries handled. |
| **Threads** | `sys_clone`, `sys_futex` | 🚧 **In Progress** | Basic thread spawning (`spawn_thread`) and `futex` wait/wake implemented; complex thread synchronization under active development. |
| **Linker** | Dynamic Linker (`ld-linux-x86-64.so.2`) | 🚧 **In Progress** | Dynamic shared library loading (`libc.so.6`) is currently under development. |
| **Graphics** | X11 / Wayland / OpenGL / Vulkan | ❌ **Untested** | Desktop Linux graphical display servers are currently unsupported. |

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

### 2. Build Runtime Adapter & Test Suites

```bash
# Build the sys_compat_run loader
gcc -O2 src/sys_compat_run.c -o sys_compat_run

# Build C test suite binaries
make -C tests

# Run static Linux hello test
./sys_compat_run ./tests/hello_linux
```

---

## 🤝 Contributing & Pull Requests

Contributions from the community are warmly welcomed! Whether you want to implement stubbed system calls, expand synthetic `/proc` nodes, or improve thread synchronization (`futex`/`clone`), please feel free to open a **Pull Request** or submit an **Issue** on GitHub!

- **GitHub Repository**: [https://github.com/AiLang-Author/Haiku-Linux-Bridge](https://github.com/AiLang-Author/Haiku-Linux-Bridge)
- **License**: Public Domain (CC0 1.0 Universal)
