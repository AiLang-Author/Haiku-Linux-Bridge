/*
 * File I/O system call test suite for sys_compat
 * License: Public Domain / CC0 1.0 Universal
 */

#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/stat.h>
#include <string.h>
#include <assert.h>

int main(void)
{
    printf("[+] Running File I/O Syscall Test...\n");

    const char* filename = "/tmp/sys_compat_test.txt";
    const char test_data[] = "sys_compat file translation payload test line.\n";

    // 1. Test openat / create
    int fd = open(filename, O_CREAT | O_WRONLY | O_TRUNC, 0644);
    if (fd < 0) {
        perror("[-] open failed");
        return 1;
    }
    printf("[+] File opened successfully (fd=%d)\n", fd);

    // 2. Test write
    ssize_t written = write(fd, test_data, sizeof(test_data) - 1);
    assert(written == (ssize_t)(sizeof(test_data) - 1));
    printf("[+] Wrote %zd bytes\n", written);
    close(fd);

    // 3. Test fstat & stat
    struct stat st;
    if (stat(filename, &st) == 0) {
        printf("[+] stat successful: size=%ld bytes, mode=0%o\n", (long)st.st_size, st.st_mode);
    } else {
        perror("[-] stat failed");
    }

    // 4. Test read
    fd = open(filename, O_RDONLY);
    char buf[128] = {0};
    ssize_t read_bytes = read(fd, buf, sizeof(buf) - 1);
    printf("[+] Read back %zd bytes: %s", read_bytes, buf);
    close(fd);

    unlink(filename);
    printf("[+] File I/O Test Completed Successfully!\n");
    return 0;
}
