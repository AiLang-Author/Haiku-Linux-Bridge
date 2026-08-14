/*
 * sys_compat_run - Universal Linux ELF Loader & System V ABI Stack Launcher for Haiku OS
 * Includes Inline Assembly Syscall & TLS FS_BASE Register Setup
 * License: Public Domain / CC0 1.0 Universal
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdint.h>
#include <sys/mman.h>
#include <elf.h>
#include "sys_compat_abi.h"

#define SYS_ARCH_PRCTL 158
#define ARCH_SET_FS    0x1002

static inline long linux_raw_syscall2(long num, long arg1, long arg2)
{
    long ret;
    __asm__ __volatile__ (
        "syscall"
        : "=a"(ret)
        : "a"(num), "D"(arg1), "S"(arg2)
        : "rcx", "r11", "memory"
    );
    return ret;
}

int main(int argc, char** argv)
{
    if (argc < 2) {
        printf("Usage: sys_compat_run <linux_elf_binary> [args...]\n");
        return 1;
    }

    const char* elf_path = argv[1];
    int fd = open(elf_path, O_RDONLY);
    if (fd < 0) {
        perror("[-] Failed to open Linux ELF binary");
        return 1;
    }

    Elf64_Ehdr ehdr;
    if (read(fd, &ehdr, sizeof(ehdr)) != sizeof(ehdr)) {
        perror("[-] Failed to read ELF header");
        close(fd);
        return 1;
    }

    if (memcmp(ehdr.e_ident, ELFMAG, SELFMAG) != 0) {
        printf("[-] Error: Not a valid ELF binary\n");
        close(fd);
        return 1;
    }

    printf("[+] sys_compat_run: Loading 64-bit Linux ELF '%s' (Entry: 0x%lx)...\n",
           elf_path, (unsigned long)ehdr.e_entry);

    // Read Program Headers
    Elf64_Phdr* phdrs = malloc(sizeof(Elf64_Phdr) * ehdr.e_phnum);
    lseek(fd, ehdr.e_phoff, SEEK_SET);
    if (read(fd, phdrs, sizeof(Elf64_Phdr) * ehdr.e_phnum) != (ssize_t)(sizeof(Elf64_Phdr) * ehdr.e_phnum)) {
        perror("[-] Failed to read program headers");
        free(phdrs);
        close(fd);
        return 1;
    }

    /*
     * One anonymous map covering every PT_LOAD, page-aligned (4K).
     * A 64K mask made hello_min's .text/.rodata clobber each other.
     */
    {
        uint64_t map_lo = ~(uint64_t)0;
        uint64_t map_hi = 0;
        int loads = 0;
        for (int i = 0; i < ehdr.e_phnum; i++) {
            if (phdrs[i].p_type != PT_LOAD)
                continue;
            uint64_t lo = phdrs[i].p_vaddr & ~0xFFFULL;
            uint64_t hi = (phdrs[i].p_vaddr + phdrs[i].p_memsz + 0xFFFULL) & ~0xFFFULL;
            if (lo < map_lo) map_lo = lo;
            if (hi > map_hi) map_hi = hi;
            loads++;
        }
        if (loads == 0 || map_hi <= map_lo) {
            printf("[-] No PT_LOAD segments\n");
            free(phdrs);
            close(fd);
            return 1;
        }
        size_t map_len = (size_t)(map_hi - map_lo);
        void* mapped = mmap((void*)(uintptr_t)map_lo, map_len,
                            PROT_READ | PROT_WRITE | PROT_EXEC,
                            MAP_PRIVATE | MAP_ANONYMOUS | MAP_FIXED, -1, 0);
        if (mapped == MAP_FAILED) {
            perror("[-] mmap PT_LOAD range");
            free(phdrs);
            close(fd);
            return 1;
        }
        printf("[+] Mapped PT_LOAD range 0x%lx-0x%lx (%zu bytes)\n",
               (unsigned long)map_lo, (unsigned long)map_hi, map_len);

        for (int i = 0; i < ehdr.e_phnum; i++) {
            if (phdrs[i].p_type != PT_LOAD)
                continue;
            if (phdrs[i].p_filesz == 0)
                continue;
            lseek(fd, phdrs[i].p_offset, SEEK_SET);
            if (read(fd, (void*)(uintptr_t)phdrs[i].p_vaddr,
                     phdrs[i].p_filesz) != (ssize_t)phdrs[i].p_filesz) {
                perror("[-] Failed to copy PT_LOAD");
                free(phdrs);
                close(fd);
                return 1;
            }
            printf("[+] Loaded segment %d at 0x%lx file=%zu mem=%zu\n",
                   i, (unsigned long)phdrs[i].p_vaddr,
                   (size_t)phdrs[i].p_filesz, (size_t)phdrs[i].p_memsz);
        }
    }

    free(phdrs);
    close(fd);

    // Allocate 4KB TLS Thread Local Storage area for Linux process
    void* tls_area = mmap(NULL, 4096, PROT_READ | PROT_WRITE,
                          MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (tls_area != MAP_FAILED) {
        *(void**)tls_area = tls_area; // Set self-pointer
        linux_raw_syscall2(SYS_ARCH_PRCTL, ARCH_SET_FS, (long)(uintptr_t)tls_area);
        printf("[+] Initialized TLS FS_BASE at 0x%lx via raw syscall\n", (unsigned long)(uintptr_t)tls_area);
    }

    // Allocate 1MB User Stack for Linux process
    size_t stack_size = 1024 * 1024;
    void* stack_base = mmap(NULL, stack_size, PROT_READ | PROT_WRITE,
                            MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (stack_base == MAP_FAILED) {
        perror("[-] Failed to allocate Linux stack");
        return 1;
    }

    uint64_t* sp = (uint64_t*)((uint8_t*)stack_base + stack_size);

    // 16-byte align stack pointer
    sp = (uint64_t*)((uintptr_t)sp & ~0xFULL);

    // Push Auxiliary Vector (AT_NULL = 0, 0)
    *(--sp) = 0;
    *(--sp) = 0;

    // Push AT_PAGESZ (6 = 4096)
    *(--sp) = 4096;
    *(--sp) = 6;

    // Push envp NULL terminator
    *(--sp) = 0;

    // Prepare Linux argv pointers
    int linux_argc = argc - 1;
    char** linux_argv = &argv[1];

    // Push argv NULL terminator
    *(--sp) = 0;

    // Push argv string pointers
    for (int i = linux_argc - 1; i >= 0; i--) {
        *(--sp) = (uint64_t)(uintptr_t)linux_argv[i];
    }

    // Push argc
    *(--sp) = (uint64_t)linux_argc;

    printf("[+] System V ABI Stack prepared at RSP=0x%lx (argc=%d)...\n",
           (unsigned long)(uintptr_t)sp, linux_argc);
    printf("[+] Transferring execution to Linux entry point 0x%lx...\n",
           (unsigned long)ehdr.e_entry);

    int compat_fd = open(SYS_COMPAT_DEVICE, O_RDWR);
    printf("[+] open(%s) -> %d\n", SYS_COMPAT_DEVICE, compat_fd);
    if (compat_fd < 0) {
        perror("[-] sys_compat device (is the driver loaded?)");
        return 1;
    }
    printf("[+] mark via raw syscall 0x%x then jmp 0x%lx (no libc after mark)\n",
           SYS_COMPAT_MARK_NR, (unsigned long)ehdr.e_entry);
    fflush(stdout);

    /*
     * Mark + jump in one asm block. After 0x1337 the next syscall from
     * this CR3 is Linux, so we must not return through libc.
     * Keep compat_fd open so close/free can LEAVE when the team dies.
     */
    {
        uint64_t entry_addr = ehdr.e_entry;
        uint64_t mark_nr = SYS_COMPAT_MARK_NR;
        __asm__ __volatile__(
            "mov %2, %%rax\n\t"
            "syscall\n\t"
            "mov %0, %%rsp\n\t"
            "jmp *%1\n\t"
            :
            : "r"(sp), "r"(entry_addr), "r"(mark_nr)
            : "rax", "rcx", "r11", "memory"
        );
    }

    return 0;
}
