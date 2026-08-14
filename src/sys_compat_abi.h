/*
 * User/kernel handshake for sys_compat. No ioctl.
 *
 * Preferred mark: unused syscall SYS_COMPAT_MARK_NR (0x1337). The
 * trampoline stores this CR3 (PCID bits cleared) and sysrets 0.
 * That is the last instruction before jmp into the Linux image —
 * no libc after it, or Haiku syscalls get treated as Linux.
 *
 * Alternate: write the token to /dev/misc/sys_compat. Same mark,
 * but libc write() may issue more Haiku syscalls on the way out.
 *
 * Unknown Linux syscalls return -ENOSYS. Device ioctl is rejected.
 * License: Public Domain / CC0 1.0 Universal
 */
#ifndef SYS_COMPAT_ABI_H
#define SYS_COMPAT_ABI_H

#define SYS_COMPAT_DEVICE "/dev/misc/sys_compat"
#define SYS_COMPAT_TOKEN  "LINUXABI"
#define SYS_COMPAT_TOKEN_LEN 8
#define SYS_COMPAT_MARK_NR 0x1337

#endif
