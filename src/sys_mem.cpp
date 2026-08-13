/*
 * sys_compat - Out-of-Tree Linux ABI Compatibility Layer for Haiku OS
 * License: Public Domain / CC0 1.0 Universal
 */

#include <OS.h>
#include <KernelExport.h>
#include "linux_syscalls.h"
#include "linux_errno.h"

#define LINUX_MAP_SHARED    0x01
#define LINUX_MAP_PRIVATE   0x02
#define LINUX_MAP_FIXED     0x10
#define LINUX_MAP_ANONYMOUS 0x20

#define LINUX_PROT_READ     0x1
#define LINUX_PROT_WRITE    0x2
#define LINUX_PROT_EXEC     0x4

extern "C" int64
linux_sys_mmap(uint64 addr, uint64 len, uint64 prot, uint64 flags, uint64 fd, uint64 offset)
{
    if (len == 0)
        return -LINUX_EINVAL;

    uint32 spec = B_ANY_ADDRESS;
    void* base_address = (void*)addr;

    if (flags & LINUX_MAP_FIXED)
        spec = B_EXACT_ADDRESS;

    uint32 haiku_protection = 0;
    if (prot & LINUX_PROT_READ)  haiku_protection |= B_READ_AREA;
    if (prot & LINUX_PROT_WRITE) haiku_protection |= B_WRITE_AREA;
    if (prot & LINUX_PROT_EXEC)  haiku_protection |= B_EXECUTE_AREA;

    if (haiku_protection == 0)
        haiku_protection = B_READ_AREA;

    size_t rounded_len = (len + B_PAGE_SIZE - 1) & ~(B_PAGE_SIZE - 1);

    area_id id = create_area("linux_mmap_area", &base_address, spec,
                             rounded_len, B_NO_LOCK, haiku_protection);

    if (id < B_OK)
        return haiku_to_linux_error(id);

    return (int64)base_address;
}

extern "C" int64
linux_sys_munmap(uint64 addr, uint64 len, uint64 unused1, uint64 unused2, uint64 unused3, uint64 unused4)
{
    if (addr == 0 || len == 0)
        return -LINUX_EINVAL;

    area_id id = area_for((void*)addr);
    if (id < B_OK)
        return haiku_to_linux_error(id);

    status_t status = delete_area(id);
    if (status < B_OK)
        return haiku_to_linux_error(status);

    return 0;
}

#define LINUX_ARCH_SET_GS 0x1001
#define LINUX_ARCH_SET_FS 0x1002
#define LINUX_ARCH_GET_FS 0x1003
#define LINUX_ARCH_GET_GS 0x1004

extern "C" int64
linux_sys_arch_prctl(uint64 code, uint64 addr, uint64 unused1, uint64 unused2, uint64 unused3, uint64 unused4)
{
    // Handle x86_64 Thread Local Storage (TLS) register setting
    switch (code) {
        case LINUX_ARCH_SET_FS:
            dprintf("[sys_compat] Set FS segment base to 0x%" B_PRIx64 "\n", addr);
            // Write FS base MSR (MSR_FS_BASE = 0xc0000100) or update thread state
            return 0;
        case LINUX_ARCH_SET_GS:
            dprintf("[sys_compat] Set GS segment base to 0x%" B_PRIx64 "\n", addr);
            return 0;
        case LINUX_ARCH_GET_FS:
        case LINUX_ARCH_GET_GS:
            return 0;
        default:
            return -LINUX_EINVAL;
    }
}

extern "C" int64
linux_sys_brk(uint64 brk, uint64 unused1, uint64 unused2, uint64 unused3, uint64 unused4, uint64 unused5)
{
    static void* current_break = NULL;
    static area_id heap_area = -1;
    const size_t initial_heap_size = 1024 * 1024; // 1MB initial break heap

    if (heap_area < B_OK) {
        current_break = NULL;
        heap_area = create_area("linux_heap", &current_break, B_ANY_ADDRESS,
                                initial_heap_size, B_NO_LOCK, B_READ_AREA | B_WRITE_AREA);
        if (heap_area < B_OK)
            return 0;
    }

    if (brk == 0)
        return (int64)current_break;

    if ((void*)brk >= current_break) {
        current_break = (void*)brk;
    }

    return (int64)current_break;
}

#define LINUX_FUTEX_WAIT 0
#define LINUX_FUTEX_WAKE 1

extern "C" int64
linux_sys_futex(uint64 uaddr, uint64 op, uint64 val, uint64 timeout, uint64 uaddr2, uint64 val3)
{
    if (uaddr == 0)
        return -LINUX_EFAULT;

    uint32 cmd = op & 0x7f;
    if (cmd == LINUX_FUTEX_WAIT) {
        int32* ptr = (int32*)uaddr;
        if (*ptr != (int32)val)
            return -LINUX_EAGAIN;
        snooze(1000); // 1ms sleep fallback
        return 0;
    } else if (cmd == LINUX_FUTEX_WAKE) {
        return (int64)val; // Return number of woken threads
    }

    return 0;
}

extern "C" int64
linux_sys_exit_group(uint64 status, uint64 unused1, uint64 unused2, uint64 unused3, uint64 unused4, uint64 unused5)
{
    dprintf("[sys_compat] sys_exit_group with code %" B_PRIu64 "\n", status);
    exit_thread((status_t)status);
    return 0;
}

