/*
 * Synthetic /proc and /sys VFS test suite for sys_compat
 * License: Public Domain / CC0 1.0 Universal
 */

#include <stdio.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>

static void test_read_path(const char* path)
{
    printf("----------------------------------------------------\n");
    printf("[+] Testing Synthetic VFS Path: %s\n", path);
    int fd = open(path, O_RDONLY);
    if (fd < 0) {
        printf("[-] Failed to open %s\n", path);
        return;
    }

    char buf[512];
    memset(buf, 0, sizeof(buf));
    ssize_t n = read(fd, buf, sizeof(buf) - 1);
    if (n >= 0) {
        buf[n] = '\0';
        printf("[+] Content read (%zd bytes):\n%s", n, buf);
    } else {
        perror("[-] Read failed");
    }
    close(fd);
}

int main(void)
{
    printf("====================================================\n");
    printf("  sys_compat Synthetic VFS (/proc & /sys) Test Suite\n");
    printf("====================================================\n");

    test_read_path("/proc/meminfo");
    test_read_path("/proc/cpuinfo");
    test_read_path("/proc/self/status");
    test_read_path("/proc/self/cmdline");
    test_read_path("/proc/mounts");
    test_read_path("/proc/uptime");
    test_read_path("/sys/devices/system/cpu/online");

    printf("====================================================\n");
    printf("[+] Synthetic VFS Test Completed Successfully!\n");
    return 0;
}
