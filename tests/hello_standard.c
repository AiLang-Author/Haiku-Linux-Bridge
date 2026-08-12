/*
 * Standard 64-bit Linux Hello World executable for Haiku Linux Bridge
 * License: Public Domain / CC0 1.0 Universal
 */

#include <stdio.h>
#include <unistd.h>
#include <sys/types.h>

int main(int argc, char *argv[])
{
    printf("========================================================\n");
    printf("  Hello World from Standard 64-bit Linux ELF on Haiku! \n");
    printf("========================================================\n");
    printf("[+] PID: %d, PPID: %d\n", getpid(), getppid());
    printf("[+] Executable argument count: %d\n", argc);
    for (int i = 0; i < argc; i++) {
        printf("    argv[%d] = %s\n", i, argv[i]);
    }
    printf("[+] 64-bit Linux execution test passed!\n");
    return 0;
}
