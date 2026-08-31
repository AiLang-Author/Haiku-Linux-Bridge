/*
 * User/kernel ioctl interface for the sys_compat LSTAR hook.
 * License: Public Domain / CC0 1.0 Universal
 */
#ifndef SYS_COMPAT_IOCTL_H
#define SYS_COMPAT_IOCTL_H

#define SYS_COMPAT_DEVICE "/dev/misc/sys_compat"

#define SYS_COMPAT_ENTER  0x53430001u
#define SYS_COMPAT_LEAVE  0x53430002u
#define SYS_COMPAT_STATUS 0x53430003u

#endif
