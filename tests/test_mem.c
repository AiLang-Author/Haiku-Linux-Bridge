/*
 * Memory Management system call test suite for sys_compat
 * License: Public Domain / CC0 1.0 Universal
 */

#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <unistd.h>
#include <string.h>
#include <assert.h>

int main(void)
{
    printf("[+] Running Memory Management Syscall Test...\n");

    size_t size = 4096;

    // 1. Test mmap
    void* ptr = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (ptr == MAP_FAILED) {
        perror("[-] mmap failed");
        return 1;
    }
    printf("[+] mmap allocated memory at address: %p\n", ptr);

    // 2. Test writing & reading mapped memory
    const char msg[] = "Memory allocation verified under sys_compat.";
    memcpy(ptr, msg, sizeof(msg));
    assert(strcmp((char*)ptr, msg) == 0);
    printf("[+] Memory read/write payload verified: %s\n", (char*)ptr);

    // 3. Test munmap
    if (munmap(ptr, size) == 0) {
        printf("[+] munmap successfully unmapped memory region.\n");
    } else {
        perror("[-] munmap failed");
    }

    printf("[+] Memory Management Test Completed Successfully!\n");
    return 0;
}
