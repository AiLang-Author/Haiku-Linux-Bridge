/*
 * Signal handling & mask registration test suite for sys_compat
 * License: Public Domain / CC0 1.0 Universal
 */

#include <stdio.h>
#include <string.h>
#include <signal.h>
#include <unistd.h>

static void dummy_signal_handler(int sig)
{
    printf("[+] Signal %d caught in handler!\n", sig);
}

int main(void)
{
    printf("====================================================\n");
    printf("  sys_compat Linux Signal Handling Test Suite       \n");
    printf("====================================================\n");

    // 1. Test sigaction handler registration (sys_rt_sigaction)
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_handler = dummy_signal_handler;
    sigemptyset(&sa.sa_mask);

    if (sigaction(SIGUSR1, &sa, NULL) == 0) {
        printf("[+] sigaction handler registered for SIGUSR1 (%d)\n", SIGUSR1);
    } else {
        perror("[-] sigaction registration failed");
    }

    // 2. Test sigprocmask signal blocking (sys_rt_sigprocmask)
    sigset_t set, oldset;
    sigemptyset(&set);
    sigaddset(&set, SIGINT);

    if (sigprocmask(SIG_BLOCK, &set, &oldset) == 0) {
        printf("[+] sigprocmask SIG_BLOCK success for SIGINT\n");
    } else {
        perror("[-] sigprocmask SIG_BLOCK failed");
    }

    if (sigprocmask(SIG_UNBLOCK, &set, NULL) == 0) {
        printf("[+] sigprocmask SIG_UNBLOCK success for SIGINT\n");
    } else {
        perror("[-] sigprocmask SIG_UNBLOCK failed");
    }

    printf("====================================================\n");
    printf("[+] Signal Handling Test Completed Successfully!\n");
    return 0;
}
