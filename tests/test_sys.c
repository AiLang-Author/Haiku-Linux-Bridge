/*
 * System Information & Process system call test suite for sys_compat
 * License: Public Domain / CC0 1.0 Universal
 */

#include <stdio.h>
#include <unistd.h>
#include <sys/utsname.h>
#include <sys/types.h>

int main(void)
{
    printf("[+] Running System Information Syscall Test...\n");

    // 1. Test uname
    struct utsname uts;
    if (uname(&uts) == 0) {
        printf("[+] uname: sysname=%s, release=%s, machine=%s\n",
               uts.sysname, uts.release, uts.machine);
    } else {
        perror("[-] uname failed");
    }

    // 2. Test getpid & getcwd
    pid_t pid = getpid();
    printf("[+] Process PID: %d\n", pid);

    char cwd[256] = {0};
    if (getcwd(cwd, sizeof(cwd)) != NULL) {
        printf("[+] Current Working Directory: %s\n", cwd);
    }

    printf("[+] System Information Test Completed Successfully!\n");
    return 0;
}
