/*
 * sys_compat - Out-of-Tree Linux ABI Compatibility Layer for Haiku OS
 * License: Public Domain / CC0 1.0 Universal
 */

#ifndef LINUX_ERRNO_H
#define LINUX_ERRNO_H

#include <SupportDefs.h>

#ifdef __cplusplus
extern "C" {
#endif

// Linux POSIX Errno Values
#define LINUX_EPERM         1
#define LINUX_ENOENT        2
#define LINUX_ESRCH         3
#define LINUX_EINTR         4
#define LINUX_EIO           5
#define LINUX_ENXIO         6
#define LINUX_E2BIG         7
#define LINUX_ENOEXEC       8
#define LINUX_EBADF         9
#define LINUX_ECHILD       10
#define LINUX_EAGAIN       11
#define LINUX_ENOMEM       12
#define LINUX_EACCES       13
#define LINUX_EFAULT       14
#define LINUX_EBUSY        16
#define LINUX_EEXIST       17
#define LINUX_EXDEV        18
#define LINUX_ENODEV       19
#define LINUX_ENOTDIR      20
#define LINUX_EISDIR       21
#define LINUX_EINVAL       22
#define LINUX_ENFILE       23
#define LINUX_EMFILE       24
#define LINUX_ENOTTY       25
#define LINUX_EFBIG        27
#define LINUX_ENOSPC       28
#define LINUX_ESPIPE       29
#define LINUX_EROFS        30
#define LINUX_EMLINK       31
#define LINUX_EPIPE        32
#define LINUX_ENOSYS       38

// Map Haiku status_t error codes to negative Linux -errno values
static inline int64 haiku_to_linux_error(status_t status)
{
    if (status >= B_OK)
        return (int64)status;

    switch (status) {
        case B_ENTRY_NOT_FOUND:     return -LINUX_ENOENT;
        case B_PERMISSION_DENIED:   return -LINUX_EACCES;
        case B_FILE_EXISTS:         return -LINUX_EEXIST;
        case B_BAD_VALUE:           return -LINUX_EINVAL;
        case B_NO_MEMORY:           return -LINUX_ENOMEM;
        case B_INTERRUPTED:         return -LINUX_EINTR;
        case B_DEV_FIFO_FULL:       return -LINUX_EAGAIN;
        case B_FILE_ERROR:          return -LINUX_EIO;
        case B_FILE_NOT_FOUND:      return -LINUX_ENOENT;
        case B_READ_ONLY_DEVICE:    return -LINUX_EROFS;
        case B_RESOURCE_UNAVAILABLE:return -LINUX_EAGAIN;
        default:                    return -LINUX_EINVAL;
    }
}

#ifdef __cplusplus
}
#endif

#endif // LINUX_ERRNO_H
