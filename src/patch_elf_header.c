/*
 * patch_elf_header - Strips Linux GNU property notes & OSABI headers for Haiku loader compatibility
 * License: Public Domain / CC0 1.0 Universal
 */

#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <elf.h>

int main(int argc, char** argv)
{
    if (argc < 2) {
        printf("Usage: patch_elf_header <linux_elf_binary>\n");
        return 1;
    }

    int fd = open(argv[1], O_RDWR);
    if (fd < 0) {
        perror("[-] Failed to open binary");
        return 1;
    }

    Elf64_Ehdr ehdr;
    if (read(fd, &ehdr, sizeof(ehdr)) != sizeof(ehdr)) {
        perror("[-] Failed to read ELF header");
        close(fd);
        return 1;
    }

    // Set EI_OSABI to 0 (ELFOSABI_SYSV / Haiku default)
    ehdr.e_ident[EI_OSABI] = 0;
    ehdr.e_ident[EI_ABIVERSION] = 0;

    lseek(fd, 0, SEEK_SET);
    write(fd, &ehdr, sizeof(ehdr));

    // Inspect program headers to patch PT_GNU_PROPERTY (0x6474e553) to PT_NULL (0)
    Elf64_Phdr phdr;
    for (int i = 0; i < ehdr.e_phnum; i++) {
        off_t ph_off = ehdr.e_phoff + (i * sizeof(Elf64_Phdr));
        lseek(fd, ph_off, SEEK_SET);
        read(fd, &phdr, sizeof(phdr));

        if (phdr.p_type == 0x6474e553) { // PT_GNU_PROPERTY
            phdr.p_type = PT_NULL;
            lseek(fd, ph_off, SEEK_SET);
            write(fd, &phdr, sizeof(phdr));
            printf("[+] Patched PT_GNU_PROPERTY header %d -> PT_NULL\n", i);
        }
    }

    close(fd);
    printf("[+] Successfully patched '%s' ELF header for Haiku loader compatibility!\n", argv[1]);
    return 0;
}
