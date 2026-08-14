/*
 * User/kernel handshake for sys_compat. No ioctl.
 * Write the token to /dev/misc/sys_compat to mark this address space
 * as a Linux ABI team. Unknown Linux syscalls return -ENOSYS.
 * License: Public Domain / CC0 1.0 Universal
 */
#ifndef SYS_COMPAT_ABI_H
#define SYS_COMPAT_ABI_H

#define SYS_COMPAT_DEVICE "/dev/misc/sys_compat"
#define SYS_COMPAT_TOKEN  "LINUXABI"
#define SYS_COMPAT_TOKEN_LEN 8

#endif
