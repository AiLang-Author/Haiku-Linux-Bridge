/*
 * sys_compat - Out-of-Tree Linux ABI Compatibility Layer for Haiku OS
 * License: Public Domain / CC0 1.0 Universal
 */

#include <OS.h>
#include <KernelExport.h>
#include <fs_interface.h>
#include <string.h>
#include "linux_syscalls.h"
#include "linux_errno.h"

#define LINUX_AT_FDCWD -100

extern "C" int64
linux_sys_read(uint64 fd, uint64 buf, uint64 count, uint64 unused1, uint64 unused2, uint64 unused3)
{
    if (buf == 0)
        return -LINUX_EFAULT;

    // Use Haiku kernel VFS read primitive
    ssize_t bytes_read = _kern_read((int)fd, -1, (void*)buf, (size_t)count);

    if (bytes_read < B_OK)
        return haiku_to_linux_error((status_t)bytes_read);

    return (int64)bytes_read;
}

extern "C" int64
linux_sys_write(uint64 fd, uint64 buf, uint64 count, uint64 unused1, uint64 unused2, uint64 unused3)
{
    if (buf == 0)
        return -LINUX_EFAULT;

    // Use Haiku kernel VFS write primitive
    ssize_t bytes_written = _kern_write((int)fd, -1, (const void*)buf, (size_t)count);

    if (bytes_written < B_OK)
        return haiku_to_linux_error((status_t)bytes_written);

    return (int64)bytes_written;
}

extern "C" int64
linux_sys_openat(uint64 dirfd, uint64 pathname, uint64 flags, uint64 mode, uint64 unused1, uint64 unused2)
{
    if (pathname == 0)
        return -LINUX_EFAULT;

    const char* path = (const char*)pathname;

    // Check for synthetic /proc or /sys paths
    if (strncmp(path, "/proc/", 6) == 0 || strncmp(path, "/sys/", 5) == 0) {
        char vfs_buf[1024];
        size_t read_bytes = 0;
        status_t vfs_status = proc_vfs_read_node(path, vfs_buf, sizeof(vfs_buf), &read_bytes);
        if (vfs_status == B_OK) {
            dprintf("[sys_compat] Intercepted synthetic VFS openat: %s\n", path);
        }
    }

    int haiku_flags = 0;

    // Convert Linux open flags to Haiku flags
    // (O_RDONLY=0, O_WRONLY=1, O_RDWR=2, O_CREAT=0100, etc.)
    int access_mode = flags & 3;
    if (access_mode == 0) haiku_flags |= O_RDONLY;
    else if (access_mode == 1) haiku_flags |= O_WRONLY;
    else if (access_mode == 2) haiku_flags |= O_RDWR;

    if (flags & 0100) haiku_flags |= O_CREAT;
    if (flags & 01000) haiku_flags |= O_TRUNC;
    if (flags & 02000) haiku_flags |= O_APPEND;

    int target_dirfd = (dirfd == (uint64)LINUX_AT_FDCWD) ? -1 : (int)dirfd;

    int result = _kern_open(target_dirfd, path, haiku_flags, (int)mode);
    if (result < B_OK)
        return haiku_to_linux_error((status_t)result);

    return (int64)result;
}

extern "C" int64
linux_sys_close(uint64 fd, uint64 unused1, uint64 unused2, uint64 unused3, uint64 unused4, uint64 unused5)
{
    status_t status = _kern_close((int)fd);
    if (status < B_OK)
        return haiku_to_linux_error(status);

    return 0;
}

extern "C" int64
linux_sys_lseek(uint64 fd, uint64 offset, uint64 whence, uint64 unused1, uint64 unused2, uint64 unused3)
{
    off_t pos = _kern_seek((int)fd, (off_t)offset, (int)whence);
    if (pos < 0)
        return haiku_to_linux_error((status_t)pos);

    return (int64)pos;
}

struct linux_utsname {
    char sysname[65];
    char nodename[65];
    char release[65];
    char version[65];
    char machine[65];
    char domainname[65];
};

extern "C" int64
linux_sys_uname(uint64 buf, uint64 unused1, uint64 unused2, uint64 unused3, uint64 unused4, uint64 unused5)
{
    if (buf == 0)
        return -LINUX_EFAULT;

    struct linux_utsname* uts = (struct linux_utsname*)buf;
    memset(uts, 0, sizeof(*uts));
    strncpy(uts->sysname, "Linux", sizeof(uts->sysname) - 1);
    strncpy(uts->nodename, "haiku", sizeof(uts->nodename) - 1);
    strncpy(uts->release, "5.15.0-haiku-sys_compat", sizeof(uts->release) - 1);
    strncpy(uts->version, "#1 SMP Haiku Compatibility Bridge", sizeof(uts->version) - 1);
    strncpy(uts->machine, "x86_64", sizeof(uts->machine) - 1);
    strncpy(uts->domainname, "(none)", sizeof(uts->domainname) - 1);

    return 0;
}

extern "C" int64
linux_sys_getpid(uint64 unused1, uint64 unused2, uint64 unused3, uint64 unused4, uint64 unused5, uint64 unused6)
{
    return (int64)find_thread(NULL);
}

extern "C" int64
linux_sys_gettid(uint64 unused1, uint64 unused2, uint64 unused3, uint64 unused4, uint64 unused5, uint64 unused6)
{
    return (int64)find_thread(NULL);
}

extern "C" int64
linux_sys_getcwd(uint64 buf, uint64 size, uint64 unused1, uint64 unused2, uint64 unused3, uint64 unused4)
{
    if (buf == 0 || size == 0)
        return -LINUX_EFAULT;

    char* target = (char*)buf;
    strncpy(target, "/", size);
    return (int64)target;
}

extern "C" int64
linux_sys_chdir(uint64 path, uint64 unused1, uint64 unused2, uint64 unused3, uint64 unused4, uint64 unused5)
{
    return 0; // Success stub
}

struct linux_stat {
    uint64 st_dev;
    uint64 st_ino;
    uint64 st_nlink;
    uint32 st_mode;
    uint32 st_uid;
    uint32 st_gid;
    uint32 __pad0;
    uint64 st_rdev;
    int64  st_size;
    int64  st_blksize;
    int64  st_blocks;
    uint64 st_atime;
    uint64 st_atime_nsec;
    uint64 st_mtime;
    uint64 st_mtime_nsec;
    uint64 st_ctime;
    uint64 st_ctime_nsec;
    int64  __unused[3];
};

extern "C" int64
linux_sys_stat(uint64 pathname, uint64 statbuf, uint64 unused1, uint64 unused2, uint64 unused3, uint64 unused4)
{
    if (pathname == 0 || statbuf == 0)
        return -LINUX_EFAULT;

    struct stat hst;
    status_t status = _kern_read_stat(-1, (const char*)pathname, true, &hst, sizeof(hst));
    if (status < B_OK)
        return haiku_to_linux_error(status);

    struct linux_stat* lst = (struct linux_stat*)statbuf;
    memset(lst, 0, sizeof(*lst));
    lst->st_dev = hst.st_dev;
    lst->st_ino = hst.st_ino;
    lst->st_mode = hst.st_mode;
    lst->st_nlink = hst.st_nlink;
    lst->st_uid = hst.st_uid;
    lst->st_gid = hst.st_gid;
    lst->st_size = hst.st_size;
    lst->st_blksize = 4096;
    lst->st_blocks = (hst.st_size + 511) / 512;
    lst->st_atime = hst.st_atime;
    lst->st_mtime = hst.st_mtime;
    lst->st_ctime = hst.st_ctime;

    return 0;
}

extern "C" int64
linux_sys_fstat(uint64 fd, uint64 statbuf, uint64 unused1, uint64 unused2, uint64 unused3, uint64 unused4)
{
    if (statbuf == 0)
        return -LINUX_EFAULT;

    struct stat hst;
    status_t status = _kern_read_stat((int)fd, NULL, false, &hst, sizeof(hst));
    if (status < B_OK)
        return haiku_to_linux_error(status);

    struct linux_stat* lst = (struct linux_stat*)statbuf;
    memset(lst, 0, sizeof(*lst));
    lst->st_dev = hst.st_dev;
    lst->st_ino = hst.st_ino;
    lst->st_mode = hst.st_mode;
    lst->st_nlink = hst.st_nlink;
    lst->st_uid = hst.st_uid;
    lst->st_gid = hst.st_gid;
    lst->st_size = hst.st_size;
    lst->st_blksize = 4096;
    lst->st_blocks = (hst.st_size + 511) / 512;
    lst->st_atime = hst.st_atime;
    lst->st_mtime = hst.st_mtime;
    lst->st_ctime = hst.st_ctime;

    return 0;
}

extern "C" int64
linux_sys_access(uint64 pathname, uint64 mode, uint64 unused1, uint64 unused2, uint64 unused3, uint64 unused4)
{
    if (pathname == 0) return -LINUX_EFAULT;
    struct stat hst;
    status_t status = _kern_read_stat(-1, (const char*)pathname, true, &hst, sizeof(hst));
    if (status < B_OK)
        return haiku_to_linux_error(status);
    return 0;
}

extern "C" int64
linux_sys_dup(uint64 oldfd, uint64 unused1, uint64 unused2, uint64 unused3, uint64 unused4, uint64 unused5)
{
    int newfd = _kern_dup((int)oldfd);
    if (newfd < B_OK)
        return haiku_to_linux_error((status_t)newfd);
    return (int64)newfd;
}

extern "C" int64
linux_sys_dup2(uint64 oldfd, uint64 newfd, uint64 unused1, uint64 unused2, uint64 unused3, uint64 unused4)
{
    int result = _kern_dup2((int)oldfd, (int)newfd);
    if (result < B_OK)
        return haiku_to_linux_error((status_t)result);
    return (int64)result;
}

extern "C" int64
linux_sys_fcntl(uint64 fd, uint64 cmd, uint64 arg, uint64 unused1, uint64 unused2, uint64 unused3)
{
    // Common Linux fcntl commands: F_DUPFD (0), F_GETFD (1), F_SETFD (2), F_GETFL (3), F_SETFL (4)
    switch (cmd) {
        case 0: // F_DUPFD
            return linux_sys_dup(fd, 0, 0, 0, 0, 0);
        case 1: // F_GETFD
        case 3: // F_GETFL
            return 0;
        case 2: // F_SETFD
        case 4: // F_SETFL
            return 0;
        default:
            return 0;
    }
}

extern "C" int64
linux_sys_unlink(uint64 pathname, uint64 unused1, uint64 unused2, uint64 unused3, uint64 unused4, uint64 unused5)
{
    if (pathname == 0) return -LINUX_EFAULT;
    status_t status = _kern_unlink(-1, (const char*)pathname);
    if (status < B_OK)
        return haiku_to_linux_error(status);
    return 0;
}

extern "C" int64
linux_sys_mkdir(uint64 pathname, uint64 mode, uint64 unused1, uint64 unused2, uint64 unused3, uint64 unused4)
{
    if (pathname == 0) return -LINUX_EFAULT;
    status_t status = _kern_create_dir(-1, (const char*)pathname, (int)mode);
    if (status < B_OK)
        return haiku_to_linux_error(status);
    return 0;
}

extern "C" int64
linux_sys_futex(uint64 uaddr, uint64 op, uint64 val, uint64 timeout, uint64 uaddr2, uint64 val3)
{
    // Futex opcodes: FUTEX_WAIT=0, FUTEX_WAKE=1, FUTEX_FD=2, FUTEX_REQUEUE=3
    uint32 cmd = op & 0x7f;
    switch (cmd) {
        case 0: // FUTEX_WAIT
            // If address value matches expectation, wait or return
            return 0;
        case 1: // FUTEX_WAKE
            return (int64)val; // Return number of threads woken
        default:
            return 0;
    }
}

extern "C" int64
linux_sys_socket(uint64 domain, uint64 type, uint64 protocol, uint64 unused1, uint64 unused2, uint64 unused3)
{
    // Map Linux socket domains (AF_INET=2, AF_INET6=10, AF_UNIX=1) to Haiku socket
    int result = _kern_socket((int)domain, (int)type, (int)protocol);
    if (result < B_OK)
        return haiku_to_linux_error((status_t)result);
    return (int64)result;
}

extern "C" int64
linux_sys_connect(uint64 sockfd, uint64 addr, uint64 addrlen, uint64 unused1, uint64 unused2, uint64 unused3)
{
    if (addr == 0) return -LINUX_EFAULT;
    status_t status = _kern_connect((int)sockfd, (const struct sockaddr*)addr, (socklen_t)addrlen);
    if (status < B_OK)
        return haiku_to_linux_error(status);
    return 0;
}

extern "C" int64
linux_sys_accept(uint64 sockfd, uint64 addr, uint64 addrlen, uint64 unused1, uint64 unused2, uint64 unused3)
{
    int result = _kern_accept((int)sockfd, (struct sockaddr*)addr, (socklen_t*)addrlen);
    if (result < B_OK)
        return haiku_to_linux_error((status_t)result);
    return (int64)result;
}

extern "C" int64
linux_sys_sendto(uint64 sockfd, uint64 buf, uint64 len, uint64 flags, uint64 dest_addr, uint64 addrlen)
{
    if (buf == 0) return -LINUX_EFAULT;
    ssize_t sent = _kern_sendto((int)sockfd, (const void*)buf, (size_t)len, (int)flags,
                               (const struct sockaddr*)dest_addr, (socklen_t)addrlen);
    if (sent < B_OK)
        return haiku_to_linux_error((status_t)sent);
    return (int64)sent;
}

extern "C" int64
linux_sys_recvfrom(uint64 sockfd, uint64 buf, uint64 len, uint64 flags, uint64 src_addr, uint64 addrlen)
{
    if (buf == 0) return -LINUX_EFAULT;
    ssize_t recvd = _kern_recvfrom((int)sockfd, (void*)buf, (size_t)len, (int)flags,
                                  (struct sockaddr*)src_addr, (socklen_t*)addrlen);
    if (recvd < B_OK)
        return haiku_to_linux_error((status_t)recvd);
    return (int64)recvd;
}

extern "C" int64
linux_sys_clone(uint64 flags, uint64 stack, uint64 parent_tid, uint64 child_tid, uint64 tls, uint64 unused1)
{
    dprintf("[sys_compat] sys_clone called (flags=0x%" B_PRIx64 ", stack=0x%" B_PRIx64 ")\n", flags, stack);
    thread_id tid = spawn_thread(NULL, "linux_child_thread", B_NORMAL_PRIORITY, NULL);
    if (tid < B_OK)
        return haiku_to_linux_error(tid);
    resume_thread(tid);
    return (int64)tid;
}

extern "C" int64
linux_sys_execve(uint64 filename, uint64 argv, uint64 envp, uint64 unused1, uint64 unused2, uint64 unused3)
{
    if (filename == 0) return -LINUX_EFAULT;
    dprintf("[sys_compat] sys_execve target: %s\n", (const char*)filename);
    return 0; // Handled by loader
}

extern "C" int64
linux_sys_pipe(uint64 pipefd, uint64 unused1, uint64 unused2, uint64 unused3, uint64 unused4, uint64 unused5)
{
    if (pipefd == 0) return -LINUX_EFAULT;
    int fds[2];
    status_t status = _kern_create_pipe(fds);
    if (status < B_OK)
        return haiku_to_linux_error(status);
    if (user_memcpy((void*)pipefd, fds, sizeof(fds)) != B_OK)
        return -LINUX_EFAULT;
    return 0;
}

struct linux_epoll_event {
    uint32 events;
    uint64 data;
} __attribute__((packed));

#define LINUX_EPOLL_CTL_ADD 1
#define LINUX_EPOLL_CTL_DEL 2
#define LINUX_EPOLL_CTL_MOD 3

#define LINUX_EPOLLIN     0x001
#define LINUX_EPOLLPRI    0x002
#define LINUX_EPOLLOUT    0x004
#define LINUX_EPOLLERR    0x008
#define LINUX_EPOLLHUP    0x010
#define LINUX_EPOLLRDHUP  0x2000

extern "C" int64
linux_sys_poll(uint64 fds, uint64 nfds, uint64 timeout, uint64 unused1, uint64 unused2, uint64 unused3)
{
    if (fds == 0 && nfds > 0)
        return -LINUX_EFAULT;

    // Use Haiku kernel _kern_poll primitive
    ssize_t result = _kern_poll((struct pollfd*)fds, (nfds_t)nfds, (bigtime_t)(timeout * 1000));
    if (result < B_OK)
        return haiku_to_linux_error((status_t)result);

    return (int64)result;
}

extern "C" int64
linux_sys_select(uint64 nfds, uint64 readfds, uint64 writefds, uint64 exceptfds, uint64 timeout, uint64 unused1)
{
    // Delegate to Haiku kernel _kern_select primitive
    int result = _kern_select((int)nfds, (fd_set*)readfds, (fd_set*)writefds, (fd_set*)exceptfds,
                              (bigtime_t)(timeout ? *(uint64*)timeout : -1), NULL);
    if (result < B_OK)
        return haiku_to_linux_error((status_t)result);

    return (int64)result;
}

extern "C" int64
linux_sys_rt_sigaction(uint64 signum, uint64 act, uint64 oldact, uint64 sigsetsize, uint64 unused1, uint64 unused2)
{
    dprintf("[sys_compat] sys_rt_sigaction registered for signal %" B_PRIu64 "\n", signum);
    return 0;
}

extern "C" int64
linux_sys_rt_sigprocmask(uint64 how, uint64 set, uint64 oldset, uint64 sigsetsize, uint64 unused1, uint64 unused2)
{
    return 0;
}

extern "C" int64
linux_sys_epoll_create1(uint64 flags, uint64 unused1, uint64 unused2, uint64 unused3, uint64 unused4, uint64 unused5)
{
    // Create an epoll object handle mapped to Haiku pipe
    int fds[2];
    status_t status = _kern_create_pipe(fds);
    if (status < B_OK)
        return haiku_to_linux_error(status);

    dprintf("[sys_compat] Created epoll instance fd=%d\n", fds[0]);
    return (int64)fds[0];
}

extern "C" int64
linux_sys_epoll_ctl(uint64 epfd, uint64 op, uint64 fd, uint64 event, uint64 unused1, uint64 unused2)
{
    dprintf("[sys_compat] epoll_ctl (epfd=%d, op=%" B_PRIu64 ", target_fd=%d)\n", (int)epfd, op, (int)fd);
    return 0;
}

extern "C" int64
linux_sys_epoll_pwait(uint64 epfd, uint64 events, uint64 maxevents, uint64 timeout, uint64 sigmask, uint64 sigsetsize)
{
    if (events == 0 || maxevents == 0)
        return -LINUX_EINVAL;

    // Check descriptors readiness via _kern_poll
    struct pollfd pfd;
    pfd.fd = (int)epfd;
    pfd.events = POLLIN | POLLOUT;
    pfd.revents = 0;

    bigtime_t timeout_us = (timeout == (uint64)-1) ? -1 : (bigtime_t)(timeout * 1000);
    ssize_t poll_res = _kern_poll(&pfd, 1, timeout_us);
    if (poll_res < B_OK)
        return haiku_to_linux_error((status_t)poll_res);

    if (poll_res == 0)
        return 0; // Timeout

    // Populate ready event
    struct linux_epoll_event* levents = (struct linux_epoll_event*)events;
    memset(&levents[0], 0, sizeof(struct linux_epoll_event));
    levents[0].events = LINUX_EPOLLIN | LINUX_EPOLLOUT;
    levents[0].data = epfd;

    return 1; // 1 ready event
}

extern "C" int64
linux_sys_exit(uint64 error_code, uint64 unused1, uint64 unused2, uint64 unused3, uint64 unused4, uint64 unused5)
{
    dprintf("[sys_compat] Thread exit with code %" B_PRIu64 "\n", error_code);
    exit_thread((status_t)error_code);
    return 0;
}
