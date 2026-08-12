/*
 * Minimal static x86_64 Linux ELF test binary for sys_compat
 * License: Public Domain / CC0 1.0 Universal
 */

#include <unistd.h>
#include <sys/syscall.h>

int main(void)
{
    const char msg[] = "Hello from unmodified Linux binary running on Haiku via sys_compat!\n";
    
    // Test raw syscall wrapper (sys_write = 1)
    syscall(SYS_write, 1, msg, sizeof(msg) - 1);
    
    return 0;
}
