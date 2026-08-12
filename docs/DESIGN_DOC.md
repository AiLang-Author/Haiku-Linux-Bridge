# Design Document: Haiku Linux Compatibility Subsystem (`sys_compat`)

**Status**: Draft / Architectural Specification  
**Target Platform**: Haiku OS (x86_64)  
**Location**: Kernel Subsystem / Module (`add-ons/kernel/generic/sys_compat`)  
**License**: Public Domain / CC0 1.0 Universal  

---

## 1. Executive Summary

The `sys_compat` project provides a high-performance, kernel-level emulation and translation layer on Haiku OS. By trapping x86_64 CPU `syscall` instructions directly inside Haiku’s interrupt vectoring routines, `sys_compat` allows unmodified Linux binaries (both dynamically linked and static, zero-dependency ELFs) to execute with native performance without requiring virtual machines, userland ptrace wrappers, or source-code recompilation.

---

## 2. Architecture & Control Flow

### 2.1 Syscall Trap & Dispatch Vector

When an x86_64 `syscall` instruction executes, the CPU vectors to `x86_64_syscall_entry` in the Haiku kernel. `sys_compat` hooks into this path to evaluate executing thread state before choosing a dispatch path.

```
                    +--------------------------------+
                    |  Unmodified Linux Binary ELF   |
                    |   (x86_64 `syscall` entry)     |
                    +--------------------------------+
                                   |
                          (Hardware CPU Trap)
                                   v
                    +--------------------------------+
                    |   Haiku x86_64_syscall_entry   |
                    | - Save Registers to iframe     |
                    | - Check Thread Flags           |
                    +--------------------------------+
                                   |
                  +----------------+----------------+
                  |                                 |
     (Flag: THREAD_ABI_HAIKU)             (Flag: THREAD_ABI_LINUX)
                  |                                 |
                  v                                 v
     +--------------------------+     +---------------------------+
     | Native Haiku Dispatcher  |     |   sys_compat Dispatcher   |
     | (src/system/kernel/...)  |     | (linux_sys_dispatch.cpp)  |
     +--------------------------+     +---------------------------+
                                                    |
                                                    v
                                      +---------------------------+
                                      | Vector Array Lookup Table |
                                      |   gLinuxSyscallTable[RAX] |
                                      +---------------------------+
                                                    |
                                                    v
                                      +---------------------------+
                                      | Translated Kernel Primitive|
                                      | (e.g., linux_sys_openat)  |
                                      +---------------------------+
```

---

## 3. Detailed Component Specifications

### 3.1 Kernel Dispatch & Register Mapping

Linux x86_64 ABI passes system call arguments via specific registers that differ from Haiku’s internal system call conventions:

* **Linux Registers**: `RAX` (Syscall No.), `RDI` (Arg1), `RSI` (Arg2), `RDX` (Arg3), `R10` (Arg4), `R8` (Arg5), `R9` (Arg6).
* **Return Conventions**: `RAX` holds the return value. Negative values between `-1` and `-4095` represent Linux `-errno` values.

```cpp
// linux_sys_dispatch.cpp
#include <kernel/ksyscall.h>
#include <arch/x86/arch_cpu.h>

#define MAX_LINUX_SYSCALLS 512

typedef int64 (*linux_syscall_fn)(uint64, uint64, uint64, uint64, uint64, uint64);
extern linux_syscall_fn gLinuxSyscallTable[MAX_LINUX_SYSCALLS];

extern "C" int64
linux_syscall_dispatcher(struct iframe* frame)
{
    uint64 sys_num = frame->rax;

    if (sys_num >= MAX_LINUX_SYSCALLS || gLinuxSyscallTable[sys_num] == NULL) {
        dprintf("[sys_compat] Unhandled Linux Syscall: %" B_PRIu64 "\n", sys_num);
        return -38; // Linux ENOSYS
    }

    // Call implementation with translated ABI args
    return gLinuxSyscallTable[sys_num](
        frame->rdi, frame->rsi, frame->rdx,
        frame->r10, frame->r8,  frame->r9
    );
}
```

### 3.2 Memory Allocation & Area Mapping (`sys_mmap` / `sys_brk`)

Linux applications manage heap memory via `brk` and virtual memory ranges via `mmap`. `sys_compat` translates these calls into Haiku's underlying `area_id` memory management system (`create_area`, `resize_area`, `delete_area`).

```cpp
// linux_mem.cpp
#include <OS.h>
#include <KernelExport.h>

#define LINUX_MAP_ANONYMOUS 0x20
#define LINUX_MAP_FIXED     0x10

int64
linux_sys_mmap(uint64 addr, uint64 len, uint64 prot, uint64 flags, uint64 fd, uint64 offset)
{
    uint32 spec = B_ANY_ADDRESS;
    void* base_address = (void*)addr;

    if (flags & LINUX_MAP_FIXED)
        spec = B_EXACT_ADDRESS;

    uint32 haiku_protection = B_READ_AREA;
    if (prot & 0x2) haiku_protection |= B_WRITE_AREA; // PROT_WRITE
    if (prot & 0x4) haiku_protection |= B_EXECUTE_AREA; // PROT_EXEC

    area_id id = create_area("linux_mmap_area", &base_address, spec,
                             PAGE_ALIGN(len), B_NO_LOCK, haiku_protection);

    if (id < B_OK)
        return -12; // Linux ENOMEM

    return (int64)base_address;
}
```

### 3.3 Status & Error Mapping Subsystem

Haiku `status_t` error definitions (e.g., `B_ENTRY_NOT_FOUND`, `B_NO_MEMORY`) do not align numerically with Linux POSIX errno definitions (e.g., `ENOENT = 2`, `ENOMEM = 12`).

```cpp
// linux_errno.cpp
#include <SupportDefs.h>
#include <Errors.h>

int64
haiku_to_linux_error(status_t status)
{
    if (status >= B_OK)
        return status;

    switch (status) {
        case B_ENTRY_NOT_FOUND: return -2;   // -ENOENT
        case B_PERMISSION_DENIED: return -13; // -EACCES
        case B_FILE_EXISTS:     return -17;  // -EEXIST
        case B_BAD_VALUE:       return -22;  // -EINVAL
        case B_NO_MEMORY:       return -12;  // -ENOMEM
        case B_INTERRUPTED:     return -4;   // -EINTR
        case B_DEV_FIFO_FULL:  return -11;  // -EAGAIN
        default:                return -22;  // Default -EINVAL
    }
}
```

## Current Implementation Status & Audit

- **CPU Syscall Vector Trap**: Fully functional on `x86_64`.
- **Register ABI Unpacker**: Maps `RAX`, `RDI`, `RSI`, `RDX`, `R10`, `R8`, `R9` from Haiku `iframe`.
- **Full Syscall Table Definitions**: Complete vector definitions (`0..440+`) in `linux_sys_table.h`.
- **Memory Subsystem**: `sys_mmap`, `sys_munmap`, `sys_brk`, `sys_arch_prctl` (`ARCH_SET_FS` / `ARCH_SET_GS` TLS setup) verified.
- **File & Descriptor I/O**: `sys_openat`, `sys_read`, `sys_write`, `sys_close`, `sys_lseek`, `sys_stat`, `sys_fstat`, `sys_access`, `sys_dup`, `sys_dup2`, `sys_fcntl`, `sys_unlink`, `sys_mkdir`.
- **Sockets & Network**: `sys_socket`, `sys_connect`, `sys_accept`, `sys_sendto`, `sys_recvfrom`.
- **Ioctl Engine**: TTY (`TCGETS`, `TIOCGWINSZ`, `FIONBIO`), Sockets (`SIOCGIFCONF`, `SIOCGIFFLAGS`), DRM (`DRM_IOCTL_VERSION`).
- **Synthetic VFS**: `/proc/meminfo`, `/proc/cpuinfo`, `/proc/self/status`, `/proc/self/cmdline`, `/proc/stat`.
- **Signal & Epoll Stubs**: `sys_rt_sigaction`, `sys_rt_sigprocmask`, `sys_epoll_create1`, `sys_epoll_ctl` (functional stubs; user stack frame rewriting in progress).

---

## 4. Virtual Filesystem Layer (`/proc` & `/sys` Synthetic Engine)

Linux applications expect standard files like `/proc/self/cmdline`, `/proc/meminfo`, and `/sys/devices`. `sys_compat` registers a dynamic VFS driver under `/proc` inside Haiku's root file system that synthesizes system structures on demand from `get_system_info()`.

```cpp
// linux_proc.cpp
#include <vfs.h>
#include <system_info.h>

status_t
proc_read_meminfo(char* buffer, size_t max_len, size_t* read_bytes)
{
    system_info sys_info;
    get_system_info(&sys_info);

    uint64 total_ram_kb = (sys_info.max_pages * B_PAGE_SIZE) / 1024;
    uint64 free_ram_kb  = ((sys_info.max_pages - sys_info.used_pages) * B_PAGE_SIZE) / 1024;

    int written = snprintf(buffer, max_len,
        "MemTotal:       %" B_PRIu64 " kB\n"
        "MemFree:        %" B_PRIu64 " kB\n"
        "MemAvailable:   %" B_PRIu64 " kB\n",
        total_ram_kb, free_ram_kb, free_ram_kb
    );

    *read_bytes = (size_t)written;
    return B_OK;
}
```
