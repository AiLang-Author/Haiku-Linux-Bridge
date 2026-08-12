/*
 * sys_compat - Out-of-Tree Linux ABI Compatibility Layer for Haiku OS
 * License: Public Domain / CC0 1.0 Universal
 */

#include <OS.h>
#include <KernelExport.h>
#include <string.h>
#include <stdio.h>
#include "linux_syscalls.h"
#include "linux_errno.h"

extern "C" status_t
proc_read_meminfo(char* buffer, size_t max_len, size_t* read_bytes)
{
    if (!buffer || max_len == 0 || !read_bytes)
        return B_BAD_VALUE;

    system_info sys_info;
    status_t status = get_system_info(&sys_info);
    if (status != B_OK)
        return status;

    if (strcmp(path, "/proc/meminfo") == 0) {
        snprintf(buffer, buffer_size,
            "MemTotal:       %" B_PRId64 " kB\n"
            "MemFree:        %" B_PRId64 " kB\n"
            "MemAvailable:   %" B_PRId64 " kB\n"
            "Buffers:               0 kB\n"
            "Cached:                0 kB\n",
            (int64)((info.max_pages * B_PAGE_SIZE) / 1024),
            (int64)(((info.max_pages - info.used_pages) * B_PAGE_SIZE) / 1024),
            (int64)(((info.max_pages - info.used_pages) * B_PAGE_SIZE) / 1024));
        return B_OK;
    } else if (strcmp(path, "/proc/cpuinfo") == 0) {
        snprintf(buffer, buffer_size,
            "processor\t: 0\n"
            "vendor_id\t: GenuineIntel\n"
            "cpu family\t: 6\n"
            "model name\t: Haiku-Linux Compatibility Bridge Virtual CPU\n"
            "cpu MHz\t\t: 2400.000\n"
            "bogomips\t: 4800.00\n");
        return B_OK;
    } else if (strcmp(path, "/proc/self/cmdline") == 0) {
        snprintf(buffer, buffer_size, "linux_app\0");
        return B_OK;
    } else if (strcmp(path, "/proc/self/status") == 0) {
        snprintf(buffer, buffer_size,
            "Name:\tlinux_app\n"
            "State:\tR (running)\n"
            "Tgid:\t%" B_PRId32 "\n"
            "Pid:\t%" B_PRId32 "\n"
            "Threads:\t1\n",
            find_thread(NULL), find_thread(NULL));
        return B_OK;
    } else if (strcmp(path, "/proc/stat") == 0) {
        snprintf(buffer, buffer_size,
            "cpu  1000 0 500 20000 100 0 10 0 0 0\n"
            "intr 5000\n"
            "ctxt 10000\n");
        return B_OK;
    }

    uint64 total_ram_kb = (sys_info.max_pages * B_PAGE_SIZE) / 1024;
    uint64 free_ram_kb  = ((sys_info.max_pages - sys_info.used_pages) * B_PAGE_SIZE) / 1024;

    int written = snprintf(buffer, max_len,
        "MemTotal:       %" B_PRIu64 " kB\n"
        "MemFree:        %" B_PRIu64 " kB\n"
        "MemAvailable:   %" B_PRIu64 " kB\n"
        "Buffers:            4096 kB\n"
        "Cached:            16384 kB\n",
        total_ram_kb, free_ram_kb, free_ram_kb
    );

    if (written < 0)
        return B_ERROR;

    *read_bytes = (size_t)written;
    return B_OK;
}

extern "C" status_t
proc_read_cpuinfo(char* buffer, size_t max_len, size_t* read_bytes)
{
    if (!buffer || max_len == 0 || !read_bytes)
        return B_BAD_VALUE;

    system_info sys_info;
    status_t status = get_system_info(&sys_info);
    if (status != B_OK)
        return status;

    int written = snprintf(buffer, max_len,
        "processor\t: 0\n"
        "vendor_id\t: GenuineIntel\n"
        "cpu family\t: 6\n"
        "model name\t: x86_64 Haiku Emulated Processor\n"
        "cpu cores\t: %" B_PRIu32 "\n",
        sys_info.cpu_count
    );

    if (written < 0)
        return B_ERROR;

    *read_bytes = (size_t)written;
    return B_OK;
}
