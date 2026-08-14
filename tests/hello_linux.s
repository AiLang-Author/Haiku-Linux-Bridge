/*
 * Minimal static x86_64 Linux ELF binary for testing sys_compat
 * License: Public Domain / CC0 1.0 Universal
 */

.intel_syntax noprefix
.global _start

.section .text
_start:
    /* sys_write(fd=1, buf=msg, count=len) */
    mov rax, 1          /* Linux sys_write = 1 */
    mov rdi, 1          /* stdout = 1 */
    lea rsi, [msg]
    .att_syntax prefix
    movq $msg_len, %rdx
    .intel_syntax noprefix
    syscall             /* x86_64 CPU syscall trap */

    /* sys_exit(error_code=0) */
    mov rax, 60         /* Linux sys_exit = 60 */
    xor rdi, rdi        /* exit code 0 */
    syscall             /* x86_64 CPU syscall trap */

.section .rodata
msg:
    .ascii "Hello from unmodified Linux binary running on Haiku via sys_compat!\n"
    msg_len = . - msg
