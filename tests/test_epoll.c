/*
 * Real Epoll & Pipe event multiplexing test suite for sys_compat
 * License: Public Domain / CC0 1.0 Universal
 */

#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <sys/epoll.h>

int main(void)
{
    printf("====================================================\n");
    printf("  sys_compat Real Epoll & Event Multiplexing Test   \n");
    printf("====================================================\n");

    // 1. Test pipe creation (sys_pipe)
    int pipefds[2];
    if (pipe(pipefds) < 0) {
        perror("[-] pipe creation failed");
        return 1;
    }
    printf("[+] Pipe created successfully (read_fd=%d, write_fd=%d)\n", pipefds[0], pipefds[1]);

    // 2. Test epoll_create1 (sys_epoll_create1)
    int epfd = epoll_create1(0);
    if (epfd < 0) {
        perror("[-] epoll_create1 failed");
        return 1;
    }
    printf("[+] Epoll instance created successfully (epfd=%d)\n", epfd);

    // 3. Test epoll_ctl ADD (sys_epoll_ctl)
    struct epoll_event ev;
    memset(&ev, 0, sizeof(ev));
    ev.events = EPOLLIN;
    ev.data.fd = pipefds[0];
    if (epoll_ctl(epfd, EPOLL_CTL_ADD, pipefds[0], &ev) < 0) {
        perror("[-] epoll_ctl ADD failed");
    } else {
        printf("[+] epoll_ctl ADD pipe read end success\n");
    }

    // 4. Write data to pipe
    const char* msg = "Epoll event ping!";
    write(pipefds[1], msg, strlen(msg));

    // 5. Test epoll_pwait / epoll_wait (sys_epoll_pwait)
    struct epoll_event events[4];
    memset(events, 0, sizeof(events));
    int ready = epoll_wait(epfd, events, 4, 1000);
    printf("[+] epoll_wait returned %d ready event(s)\n", ready);

    close(pipefds[0]);
    close(pipefds[1]);
    close(epfd);

    printf("====================================================\n");
    printf("[+] Epoll & Event Multiplexing Test Completed!\n");
    return 0;
}
