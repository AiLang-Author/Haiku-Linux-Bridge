/*
 * sys_compat - Out-of-Tree Linux ABI Compatibility Layer for Haiku OS
 * Synthetic VFS Router: /proc and /sys filesystem node generator
 * License: Public Domain / CC0 1.0 Universal
 */

#include <OS.h>
#include <KernelExport.h>
#include <string.h>
#include <stdio.h>
#include "linux_syscalls.h"
#include "linux_errno.h"

extern "C" status_t
proc_vfs_read_node(const char* path, char* buffer, size_t max_len, size_t* read_bytes)
{
    if (!path || !buffer || max_len == 0 || !read_bytes)
        return B_BAD_VALUE;

    system_info sys_info;
    status_t status = get_system_info(&sys_info);
    if (status != B_OK)
        return status;

    int written = 0;

    if (strcmp(path, "/proc/meminfo") == 0) {
        uint64 total_ram_kb = (sys_info.max_pages * B_PAGE_SIZE) / 1024;
        uint64 free_ram_kb  = ((sys_info.max_pages - sys_info.used_pages) * B_PAGE_SIZE) / 1024;
        written = snprintf(buffer, max_len,
            "MemTotal:       %" B_PRIu64 " kB\n"
            "MemFree:        %" B_PRIu64 " kB\n"
            "MemAvailable:   %" B_PRIu64 " kB\n"
            "Buffers:            4096 kB\n"
            "Cached:            16384 kB\n"
            "SwapTotal:             0 kB\n"
            "SwapFree:              0 kB\n",
            total_ram_kb, free_ram_kb, free_ram_kb);

    } else if (strcmp(path, "/proc/cpuinfo") == 0) {
        written = snprintf(buffer, max_len,
            "processor\t: 0\n"
            "vendor_id\t: GenuineIntel\n"
            "cpu family\t: 6\n"
            "model name\t: Haiku-Linux Compatibility Bridge Virtual CPU\n"
            "cpu MHz\t\t: 2400.000\n"
            "cpu cores\t: %" B_PRIu32 "\n"
            "bogomips\t: 4800.00\n"
            "flags\t\t: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl xtopology tsc_known_freq pni pclmulqdq ssse3 fma cx16 sse4_1 sse4_2 x2apic movbe popcnt tsc_deadline_timer aes xsave avx f16c rdrand hypervisor lahf_lm abm 3dnowprefetch fsgsbase bmi1 avx2 smep bmi2 erms invpcid rdtscp qemu64\n",
            sys_info.cpu_count);

    } else if (strcmp(path, "/proc/self/cmdline") == 0) {
        written = snprintf(buffer, max_len, "linux_app\0");

    } else if (strcmp(path, "/proc/self/exe") == 0) {
        written = snprintf(buffer, max_len, "/boot/home/linux_app");

    } else if (strcmp(path, "/proc/self/status") == 0) {
        thread_id tid = find_thread(NULL);
        written = snprintf(buffer, max_len,
            "Name:\tlinux_app\n"
            "State:\tR (running)\n"
            "Tgid:\t%" B_PRId32 "\n"
            "Pid:\t%" B_PRId32 "\n"
            "PPid:\t1\n"
            "Uid:\t0\t0\t0\t0\n"
            "Gid:\t0\t0\t0\t0\n"
            "FDSize:\t256\n"
            "Threads:\t1\n",
            tid, tid);

    } else if (strcmp(path, "/proc/mounts") == 0) {
        written = snprintf(buffer, max_len,
            "/dev/root / bfs rw,relatime 0 0\n"
            "proc /proc procfs rw,nosuid,nodev,noexec,relatime 0 0\n"
            "sysfs /sys sysfs rw,nosuid,nodev,noexec,relatime 0 0\n"
            "devtmpfs /dev devtmpfs rw,nosuid,size=2048k,nr_inodes=512,mode=755 0 0\n");

    } else if (strcmp(path, "/proc/uptime") == 0) {
        bigtime_t uptime_us = system_time();
        double uptime_sec = (double)uptime_us / 1000000.0;
        written = snprintf(buffer, max_len, "%.2f %.2f\n", uptime_sec, uptime_sec);

    } else if (strcmp(path, "/proc/stat") == 0) {
        written = snprintf(buffer, max_len,
            "cpu  1000 0 500 20000 100 0 10 0 0 0\n"
            "intr 5000\n"
            "ctxt 10000\n"
            "btime 1700000000\n"
            "processes 100\n"
            "procs_running 1\n"
            "procs_blocked 0\n");

    } else if (strcmp(path, "/sys/devices/system/cpu/online") == 0) {
        written = snprintf(buffer, max_len, "0-%" B_PRIu32 "\n",
            sys_info.cpu_count > 0 ? sys_info.cpu_count - 1 : 0);

    } else if (strncmp(path, "/proc/self/fd/", 14) == 0) {
        written = snprintf(buffer, max_len, "/dev/tty");

    } else {
        return B_ENTRY_NOT_FOUND;
    }

    if (written < 0)
        return B_ERROR;

    *read_bytes = (size_t)written;
    return B_OK;
}
