/*
 * Socket / Network system call test suite for sys_compat
 * License: Public Domain / CC0 1.0 Universal
 */

#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>

int main(void)
{
    printf("[+] Running Socket / Network Syscall Test...\n");

    // 1. Test socket creation
    int sockfd = socket(AF_INET, SOCK_STREAM, 0);
    if (sockfd < 0) {
        perror("[-] socket creation failed");
        return 1;
    }
    printf("[+] Socket created successfully (fd=%d)\n", sockfd);

    // 2. Test closing socket
    close(sockfd);

    printf("[+] Socket / Network Test Completed Successfully!\n");
    return 0;
}
