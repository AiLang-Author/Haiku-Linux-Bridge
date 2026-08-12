/*
 * sys_compat - Out-of-Tree Linux ABI Compatibility Layer for Haiku OS
 * License: Public Domain / CC0 1.0 Universal
 */

#include <KernelExport.h>
#include <string.h>
#include "linux_syscalls.h"
#include "linux_errno.h"

linux_syscall_fn gLinuxSyscallTable[MAX_LINUX_SYSCALLS];

void linux_init_syscall_table(void)
{
    memset(gLinuxSyscallTable, 0, sizeof(gLinuxSyscallTable));

    // Register implemented syscall vectors
    gLinuxSyscallTable[LINUX_SYS_READ]       = linux_sys_read;
    gLinuxSyscallTable[LINUX_SYS_WRITE]      = linux_sys_write;
    gLinuxSyscallTable[LINUX_SYS_OPENAT]     = linux_sys_openat;
    gLinuxSyscallTable[LINUX_SYS_CLOSE]      = linux_sys_close;
    gLinuxSyscallTable[LINUX_SYS_MMAP]       = linux_sys_mmap;
    gLinuxSyscallTable[LINUX_SYS_MUNMAP]     = linux_sys_munmap;
    gLinuxSyscallTable[LINUX_SYS_BRK]           = linux_sys_brk;
    gLinuxSyscallTable[LINUX_SYS_IOCTL]         = linux_sys_ioctl;
    gLinuxSyscallTable[LINUX_SYS_LSEEK]         = linux_sys_lseek;
    gLinuxSyscallTable[LINUX_SYS_PIPE]          = linux_sys_pipe;
    gLinuxSyscallTable[LINUX_SYS_POLL]          = linux_sys_poll;
    gLinuxSyscallTable[LINUX_SYS_SELECT]        = linux_sys_select;
    gLinuxSyscallTable[LINUX_SYS_STAT]          = linux_sys_stat;
    gLinuxSyscallTable[LINUX_SYS_FSTAT]         = linux_sys_fstat;
    gLinuxSyscallTable[LINUX_SYS_UNAME]         = linux_sys_uname;
    gLinuxSyscallTable[LINUX_SYS_GETPID]        = linux_sys_getpid;
    gLinuxSyscallTable[LINUX_SYS_GETTID]        = linux_sys_gettid;
    gLinuxSyscallTable[LINUX_SYS_ARCH_PRCTL]    = linux_sys_arch_prctl;
    gLinuxSyscallTable[LINUX_SYS_GETCWD]        = linux_sys_getcwd;
    gLinuxSyscallTable[LINUX_SYS_CHDIR]         = linux_sys_chdir;
    gLinuxSyscallTable[LINUX_SYS_ACCESS]        = linux_sys_access;
    gLinuxSyscallTable[LINUX_SYS_DUP]           = linux_sys_dup;
    gLinuxSyscallTable[LINUX_SYS_DUP2]          = linux_sys_dup2;
    gLinuxSyscallTable[LINUX_SYS_FCNTL]         = linux_sys_fcntl;
    gLinuxSyscallTable[LINUX_SYS_UNLINK]        = linux_sys_unlink;
    gLinuxSyscallTable[LINUX_SYS_MKDIR]         = linux_sys_mkdir;
    gLinuxSyscallTable[LINUX_SYS_FUTEX]         = linux_sys_futex;
    gLinuxSyscallTable[LINUX_SYS_SOCKET]        = linux_sys_socket;
    gLinuxSyscallTable[LINUX_SYS_CONNECT]       = linux_sys_connect;
    gLinuxSyscallTable[LINUX_SYS_ACCEPT]        = linux_sys_accept;
    gLinuxSyscallTable[LINUX_SYS_SENDTO]        = linux_sys_sendto;
    gLinuxSyscallTable[LINUX_SYS_RECVFROM]      = linux_sys_recvfrom;
    gLinuxSyscallTable[LINUX_SYS_CLONE]         = linux_sys_clone;
    gLinuxSyscallTable[LINUX_SYS_EXECVE]        = linux_sys_execve;
    gLinuxSyscallTable[LINUX_SYS_RT_SIGACTION]  = linux_sys_rt_sigaction;
    gLinuxSyscallTable[LINUX_SYS_RT_SIGPROCMASK] = linux_sys_rt_sigprocmask;
    gLinuxSyscallTable[LINUX_SYS_EPOLL_CREATE1] = linux_sys_epoll_create1;
    gLinuxSyscallTable[LINUX_SYS_EPOLL_CTL]     = linux_sys_epoll_ctl;
    gLinuxSyscallTable[LINUX_SYS_EPOLL_PWAIT]   = linux_sys_epoll_pwait;
    gLinuxSyscallTable[LINUX_SYS_EXIT]          = linux_sys_exit;
}

extern "C" int64
linux_syscall_dispatcher(struct iframe* frame)
{
    if (!frame)
        return -LINUX_EFAULT;

    uint64 sys_num = frame->rax;

    if (sys_num >= MAX_LINUX_SYSCALLS || gLinuxSyscallTable[sys_num] == NULL) {
        dprintf("[sys_compat] UNHANDLED SYSCALL #%" B_PRIu64 " | RAX=0x%" B_PRIx64 " RDI=0x%" B_PRIx64 " RSI=0x%" B_PRIx64 " RDX=0x%" B_PRIx64 " R10=0x%" B_PRIx64 "\n",
                sys_num, frame->rax, frame->rdi, frame->rsi, frame->rdx, frame->r10);
        return -LINUX_ENOSYS;
    }

#ifdef SYS_COMPAT_DEBUG
    dprintf("[sys_compat] Trace: Syscall #%" B_PRIu64 " (arg1=0x%" B_PRIx64 ", arg2=0x%" B_PRIx64 ", arg3=0x%" B_PRIx64 ")\n",
            sys_num, frame->rdi, frame->rsi, frame->rdx);
#endif

    // Pass x86_64 Linux ABI registers:
    // RAX: Syscall No.
    // RDI: Arg1, RSI: Arg2, RDX: Arg3, R10: Arg4, R8: Arg5, R9: Arg6
    int64 ret = gLinuxSyscallTable[sys_num](
        frame->rdi, frame->rsi, frame->rdx,
        frame->r10, frame->r8,  frame->r9
    );

#ifdef SYS_COMPAT_DEBUG
    dprintf("[sys_compat] Ret: Syscall #%" B_PRIu64 " => %" B_PRId64 " (0x%" B_PRIx64 ")\n", sys_num, ret, ret);
#endif

    return ret;
}
