/*
 * sys_compat_run - Universal Linux ELF Launcher for Haiku OS
 * License: Public Domain / CC0 1.0 Universal
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
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

    if (ehdr.e_ident[EI_CLASS] != ELFCLASS64) {
        printf("[-] Error: Only 64-bit x86_64 Linux ELF binaries are supported\n");
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

    // Map PT_LOAD segments
    for (int i = 0; i < ehdr.e_phnum; i++) {
        if (phdrs[i].p_type == PT_LOAD) {
            void* addr = (void*)(phdrs[i].p_vaddr & ~0xFFFF);
            size_t size = (phdrs[i].p_memsz + 0xFFFF) & ~0xFFFF;
            void* mapped = mmap(addr, size, PROT_READ | PROT_WRITE | PROT_EXEC,
                                MAP_PRIVATE | MAP_ANONYMOUS | MAP_FIXED, -1, 0);
            if (mapped == MAP_FAILED) {
                perror("[-] Failed to mmap PT_LOAD segment");
                free(phdrs);
                close(fd);
                return 1;
            }

            lseek(fd, phdrs[i].p_offset, SEEK_SET);
            read(fd, (void*)phdrs[i].p_vaddr, phdrs[i].p_filesz);
            printf("[+] Mapped PT_LOAD Segment %d: 0x%lx - 0x%lx (%zu bytes)\n",
                   i, (unsigned long)phdrs[i].p_vaddr,
                   (unsigned long)(phdrs[i].p_vaddr + phdrs[i].p_memsz),
                   (size_t)phdrs[i].p_memsz);
        }
    }

    free(phdrs);
    close(fd);

    // Jump to entry point
    typedef void (*entry_func_t)(void);
    entry_func_t entry = (entry_func_t)ehdr.e_entry;

    printf("[+] Transferring execution to Linux entry point 0x%lx...\n", (unsigned long)ehdr.e_entry);
    entry();

    return 0;
}
