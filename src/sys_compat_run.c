/*
 * sys_compat_run - Universal Linux ELF Loader & System V ABI Stack Launcher for Haiku OS
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

    // Map PT_LOAD segments (ignoring GNU extension headers)
    for (int i = 0; i < ehdr.e_phnum; i++) {
        if (phdrs[i].p_type == PT_LOAD) {
            void* addr = (void*)(phdrs[i].p_vaddr & ~0xFFFF);
            size_t size = (phdrs[i].p_memsz + 0xFFFF) & ~0xFFFF;
            void* mapped = mmap(addr, size, PROT_READ | PROT_WRITE | PROT_EXEC,
                                MAP_PRIVATE | MAP_ANONYMOUS | MAP_FIXED, -1, 0);
            if (mapped == MAP_FAILED) {
                mapped = mmap(NULL, size, PROT_READ | PROT_WRITE | PROT_EXEC,
                              MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
            }

            lseek(fd, phdrs[i].p_offset, SEEK_SET);
            read(fd, (void*)phdrs[i].p_vaddr, phdrs[i].p_filesz);
            printf("[+] Mapped Segment %d: 0x%lx (%zu bytes)\n",
                   i, (unsigned long)phdrs[i].p_vaddr, (size_t)phdrs[i].p_memsz);
        }
    }

    free(phdrs);
    close(fd);

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

    // Assembly jump: set RSP to sp and jump to e_entry
    uint64_t entry_addr = ehdr.e_entry;
    __asm__ __volatile__ (
        "mov %0, %%rsp\n\t"
        "jmp *%1\n\t"
        :
        : "r"(sp), "r"(entry_addr)
        : "memory"
    );

    return 0;
}
