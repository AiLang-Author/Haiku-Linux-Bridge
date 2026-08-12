/*
 * sys_compat - Out-of-Tree Linux ABI Compatibility Layer for Haiku OS
 * License: Public Domain / CC0 1.0 Universal
 */

#ifndef LINUX_SYSCALLS_H
#define LINUX_SYSCALLS_H

#ifndef __HAIKU_ARCH_64_BIT
#define __HAIKU_ARCH_64_BIT
#endif

#include <SupportDefs.h>
#include <stdint.h>
#include "linux_sys_table.h"

#ifndef _SUPPORT_DEFS_H
typedef int64_t   int64;
typedef uint64_t  uint64;
typedef int32_t   int32;
typedef uint32_t  uint32;
typedef uint16_t  uint16;
typedef uint8_t   uint8;
typedef int32_t   status_t;
#endif

#ifdef __cplusplus
extern "C" {
#endif

// Maximum supported Linux x86_64 syscalls
#define MAX_LINUX_SYSCALLS 512

// Linux x86_64 Syscall Numbers
#define LINUX_SYS_READ             0
#define LINUX_SYS_WRITE            1
#define LINUX_SYS_OPEN             2
#define LINUX_SYS_CLOSE            3
#define LINUX_SYS_STAT             4
#define LINUX_SYS_FSTAT            5
#define LINUX_SYS_LSTAT            6
#define LINUX_SYS_POLL             7
#define LINUX_SYS_LSEEK            8
#define LINUX_SYS_MMAP             9
#define LINUX_SYS_MPROTECT         10
#define LINUX_SYS_MUNMAP           11
#define LINUX_SYS_BRK              12
#define LINUX_SYS_RT_SIGACTION     13
#define LINUX_SYS_RT_SIGPROCMASK   14
#define LINUX_SYS_IOCTL            16
#define LINUX_SYS_ACCESS           21
#define LINUX_SYS_PIPE             22
#define LINUX_SYS_SELECT           23
#define LINUX_SYS_DUP              32
#define LINUX_SYS_DUP2             33
#define LINUX_SYS_PAUSE            34
#define LINUX_SYS_NANOSLEEP        35
#define LINUX_SYS_GETPID           39
#define LINUX_SYS_SOCKET           41
#define LINUX_SYS_CONNECT          42
#define LINUX_SYS_ACCEPT           43
#define LINUX_SYS_SENDTO           44
#define LINUX_SYS_RECVFROM         45
#define LINUX_SYS_CLONE            56
#define LINUX_SYS_FORK             57
#define LINUX_SYS_VFORK            58
#define LINUX_SYS_EXECVE           59
#define LINUX_SYS_EXIT             60
#define LINUX_SYS_WAIT4            61
#define LINUX_SYS_KILL             62
#define LINUX_SYS_UNAME            63
#define LINUX_SYS_FCNTL            72
#define LINUX_SYS_GETCWD           79
#define LINUX_SYS_CHDIR            80
#define LINUX_SYS_MKDIR            83
#define LINUX_SYS_RMDIR            84
#define LINUX_SYS_UNLINK           87
#define LINUX_SYS_ARCH_PRCTL       158
#define LINUX_SYS_GETTID           186
#define LINUX_SYS_FUTEX            202
#define LINUX_SYS_OPENAT           257
#define LINUX_SYS_MKDIRAT          258
#define LINUX_SYS_FSTATAT          262
#define LINUX_SYS_UNLINKAT         263

// CPU Interrupt Register Frame
struct iframe {
    uint64 r15;
    uint64 r14;
    uint64 r13;
    uint64 r12;
    uint64 rbp;
    uint64 rbx;
    uint64 r11;
    uint64 r10;
    uint64 r9;
    uint64 r8;
    uint64 rax;
    uint64 rcx;
    uint64 rdx;
    uint64 rsi;
    uint64 rdi;
    uint64 orig_rax;
    uint64 rip;
    uint64 cs;
    uint64 rflags;
    uint64 rsp;
    uint64 ss;
};

// Linux Syscall Function Pointer Signature
typedef int64 (*linux_syscall_fn)(uint64 arg1, uint64 arg2, uint64 arg3,
                                    uint64 arg4, uint64 arg5, uint64 arg6);

// Vector Dispatcher Table
extern linux_syscall_fn gLinuxSyscallTable[MAX_LINUX_SYSCALLS];

// Dispatcher Function
int64 linux_syscall_dispatcher(struct iframe* frame);
void  linux_init_syscall_table(void);

// Linux Epoll & Signal Syscall Numbers
#define LINUX_SYS_EPOLL_CREATE1    291
#define LINUX_SYS_EPOLL_CTL        233
#define LINUX_SYS_EPOLL_PWAIT      281
#define LINUX_SYS_SIGALTSTACK      131

// Syscall handlers declarations
int64 linux_sys_read(uint64 fd, uint64 buf, uint64 count, uint64 unused1, uint64 unused2, uint64 unused3);
int64 linux_sys_write(uint64 fd, uint64 buf, uint64 count, uint64 unused1, uint64 unused2, uint64 unused3);
int64 linux_sys_openat(uint64 dirfd, uint64 pathname, uint64 flags, uint64 mode, uint64 unused1, uint64 unused2);
int64 linux_sys_close(uint64 fd, uint64 unused1, uint64 unused2, uint64 unused3, uint64 unused4, uint64 unused5);
int64 linux_sys_mmap(uint64 addr, uint64 len, uint64 prot, uint64 flags, uint64 fd, uint64 offset);
int64 linux_sys_munmap(uint64 addr, uint64 len, uint64 unused1, uint64 unused2, uint64 unused3, uint64 unused4);
int64 linux_sys_brk(uint64 brk, uint64 unused1, uint64 unused2, uint64 unused3, uint64 unused4, uint64 unused5);
int64 linux_sys_ioctl(uint64 fd, uint64 cmd, uint64 arg, uint64 unused1, uint64 unused2, uint64 unused3);
int64 linux_sys_lseek(uint64 fd, uint64 offset, uint64 whence, uint64 unused1, uint64 unused2, uint64 unused3);
int64 linux_sys_pipe(uint64 pipefd, uint64 unused1, uint64 unused2, uint64 unused3, uint64 unused4, uint64 unused5);
int64 linux_sys_poll(uint64 fds, uint64 nfds, uint64 timeout, uint64 unused1, uint64 unused2, uint64 unused3);
int64 linux_sys_select(uint64 nfds, uint64 readfds, uint64 writefds, uint64 exceptfds, uint64 timeout, uint64 unused1);
int64 linux_sys_stat(uint64 pathname, uint64 statbuf, uint64 unused1, uint64 unused2, uint64 unused3, uint64 unused4);
int64 linux_sys_fstat(uint64 fd, uint64 statbuf, uint64 unused1, uint64 unused2, uint64 unused3, uint64 unused4);
int64 linux_sys_uname(uint64 buf, uint64 unused1, uint64 unused2, uint64 unused3, uint64 unused4, uint64 unused5);
int64 linux_sys_getpid(uint64 unused1, uint64 unused2, uint64 unused3, uint64 unused4, uint64 unused5, uint64 unused6);
int64 linux_sys_gettid(uint64 unused1, uint64 unused2, uint64 unused3, uint64 unused4, uint64 unused5, uint64 unused6);
int64 linux_sys_arch_prctl(uint64 code, uint64 addr, uint64 unused1, uint64 unused2, uint64 unused3, uint64 unused4);
int64 linux_sys_getcwd(uint64 buf, uint64 size, uint64 unused1, uint64 unused2, uint64 unused3, uint64 unused4);
int64 linux_sys_chdir(uint64 path, uint64 unused1, uint64 unused2, uint64 unused3, uint64 unused4, uint64 unused5);
int64 linux_sys_access(uint64 pathname, uint64 mode, uint64 unused1, uint64 unused2, uint64 unused3, uint64 unused4);
int64 linux_sys_dup(uint64 oldfd, uint64 unused1, uint64 unused2, uint64 unused3, uint64 unused4, uint64 unused5);
int64 linux_sys_dup2(uint64 oldfd, uint64 newfd, uint64 unused1, uint64 unused2, uint64 unused3, uint64 unused4);
int64 linux_sys_fcntl(uint64 fd, uint64 cmd, uint64 arg, uint64 unused1, uint64 unused2, uint64 unused3);
int64 linux_sys_unlink(uint64 pathname, uint64 unused1, uint64 unused2, uint64 unused3, uint64 unused4, uint64 unused5);
int64 linux_sys_mkdir(uint64 pathname, uint64 mode, uint64 unused1, uint64 unused2, uint64 unused3, uint64 unused4);
int64 linux_sys_futex(uint64 uaddr, uint64 op, uint64 val, uint64 timeout, uint64 uaddr2, uint64 val3);
int64 linux_sys_socket(uint64 domain, uint64 type, uint64 protocol, uint64 unused1, uint64 unused2, uint64 unused3);
int64 linux_sys_connect(uint64 sockfd, uint64 addr, uint64 addrlen, uint64 unused1, uint64 unused2, uint64 unused3);
int64 linux_sys_accept(uint64 sockfd, uint64 addr, uint64 addrlen, uint64 unused1, uint64 unused2, uint64 unused3);
int64 linux_sys_sendto(uint64 sockfd, uint64 buf, uint64 len, uint64 flags, uint64 dest_addr, uint64 addrlen);
int64 linux_sys_recvfrom(uint64 sockfd, uint64 buf, uint64 len, uint64 flags, uint64 src_addr, uint64 addrlen);
int64 linux_sys_clone(uint64 flags, uint64 stack, uint64 parent_tid, uint64 child_tid, uint64 tls, uint64 unused1);
int64 linux_sys_execve(uint64 filename, uint64 argv, uint64 envp, uint64 unused1, uint64 unused2, uint64 unused3);
int64 linux_sys_rt_sigaction(uint64 signum, uint64 act, uint64 oldact, uint64 sigsetsize, uint64 unused1, uint64 unused2);
int64 linux_sys_rt_sigprocmask(uint64 how, uint64 set, uint64 oldset, uint64 sigsetsize, uint64 unused1, uint64 unused2);
int64 linux_sys_epoll_create1(uint64 flags, uint64 unused1, uint64 unused2, uint64 unused3, uint64 unused4, uint64 unused5);
int64 linux_sys_epoll_ctl(uint64 epfd, uint64 op, uint64 fd, uint64 event, uint64 unused1, uint64 unused2);
int64 linux_sys_epoll_pwait(uint64 epfd, uint64 events, uint64 maxevents, uint64 timeout, uint64 sigmask, uint64 sigsetsize);
int64 linux_sys_exit(uint64 error_code, uint64 unused1, uint64 unused2, uint64 unused3, uint64 unused4, uint64 unused5);

#ifdef __cplusplus
}
#endif

#endif // LINUX_SYSCALLS_H
