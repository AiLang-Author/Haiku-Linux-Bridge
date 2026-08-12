/*
 * sys_compat - Out-of-Tree Linux ABI Compatibility Layer for Haiku OS
 * License: Public Domain / CC0 1.0 Universal
 */

#include <KernelExport.h>
#include <module.h>
#include "linux_syscalls.h"

#define SYS_COMPAT_MODULE_NAME "generic/sys_compat/v1"

static status_t
std_ops(int32 op, ...)
{
    switch (op) {
        case B_MODULE_INIT:
            dprintf("[sys_compat] Initializing Linux ABI kernel translation bridge...\n");
            linux_init_syscall_table();
            dprintf("[sys_compat] Registered x86_64 syscall translation table.\n");
            return B_OK;

        case B_MODULE_UNINIT:
            dprintf("[sys_compat] Unloading Linux ABI kernel translation bridge...\n");
            return B_OK;

        default:
            return B_ERROR;
    }
}

static module_info sModuleInfo = {
    SYS_COMPAT_MODULE_NAME,
    0,
    std_ops
};

_EXPORT module_info* modules[] = {
    &sModuleInfo,
    NULL
};
