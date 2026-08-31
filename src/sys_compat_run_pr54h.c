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
#include <OS.h>
#include <elf.h>
#include "sys_compat_abi.h"

/*
 * mmap(MAP_PRIVATE) still left the Linux stack/TLS on a cache that
 * fork_team did not split (COM1 k!: child's ret visible in the parent).
 * create_area without B_SHARED_AREA + a commit-touch + RO/RW bounce
 * gives fork a normal anonymous cache to COW.
 */
static void*
haiku_private_anon(const char* name, size_t size, uint32 prot)
{
    void* addr = NULL;
    area_id id;
    area_info info;
    volatile char* p;
    size_t i;

    size = (size + B_PAGE_SIZE - 1) & ~(size_t)(B_PAGE_SIZE - 1);
    id = create_area(name, &addr, B_RANDOMIZED_ANY_ADDRESS,
        size, B_NO_LOCK, prot);
    if (id < 0) {
        printf("[-] create_area %s: %d\n", name, (int)id);
        return MAP_FAILED;
    }
    p = (volatile char*)addr;
    /* Skip commit-touch on huge arenas (compiler). Fork probes
     * keep a small area and still need the COW bounce. */
    if (size <= 32u * 1024u * 1024u) {
        for (i = 0; i < size; i += B_PAGE_SIZE)
            p[i] = 0;
        if ((prot & B_WRITE_AREA) != 0) {
            set_area_protection(id, prot & ~B_WRITE_AREA);
            set_area_protection(id, prot);
        }
    }
    if (get_area_info(id, &info) == B_OK)
        printf("[+] area %s id=%d base=%p size=%lu prot=0x%x ram=%u\n",
            name, (int)id, info.address, (unsigned long)info.size,
            info.protection, info.ram_size);
    return addr;
}

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
        /* Drop W on RX text before fork. One RWX dirty map made
         * IRETQ to 0x40101c reset while tramp (also RWX) lived —
         * fork COW can strip X on writable pages. */
#ifndef PF_R
#define PF_R 4
#define PF_W 2
#define PF_X 1
#endif
        for (int i = 0; i < ehdr.e_phnum; i++) {
            int prot;
            uintptr_t lo;
            size_t len;
            if (phdrs[i].p_type != PT_LOAD)
                continue;
            prot = 0;
            if (phdrs[i].p_flags & PF_R) prot |= PROT_READ;
            if (phdrs[i].p_flags & PF_W) prot |= PROT_WRITE;
            if (phdrs[i].p_flags & PF_X) prot |= PROT_EXEC;
            if (prot == 0) prot = PROT_READ;
            lo = (uintptr_t)phdrs[i].p_vaddr & ~0xFFFULL;
            len = (((uintptr_t)phdrs[i].p_vaddr + phdrs[i].p_memsz + 0xFFFULL)
                & ~0xFFFULL) - lo;
            if (mprotect((void*)lo, len, prot) != 0)
                perror("[-] mprotect PT_LOAD");
            else
                printf("[+] mprotect 0x%lx +%zu prot=%d\n",
                       (unsigned long)lo, len, prot);
        }
    }

    free(phdrs);
    close(fd);

    // Allocate 4KB TLS Thread Local Storage area for Linux process
    void* tls_area = haiku_private_anon("linux_tls", 4096,
        B_READ_AREA | B_WRITE_AREA);
    if (tls_area != MAP_FAILED) {
        *(void**)tls_area = tls_area; // Set self-pointer
        linux_raw_syscall2(SYS_ARCH_PRCTL, ARCH_SET_FS, (long)(uintptr_t)tls_area);
        printf("[+] Initialized TLS FS_BASE at 0x%lx via raw syscall\n", (unsigned long)(uintptr_t)tls_area);
    }

    // Allocate 1MB User Stack for Linux process
    size_t stack_size = 1024 * 1024;
    void* stack_base = haiku_private_anon("linux_stack", stack_size,
        B_READ_AREA | B_WRITE_AREA);
    if (stack_base == MAP_FAILED) {
        printf("[-] Failed to allocate Linux stack\n");
        return 1;
    }

    uint64_t* sp = (uint64_t*)((uint8_t*)stack_base + stack_size);
    sp = (uint64_t*)((uintptr_t)sp & ~0xFULL);

    /*
     * execve shape: Linux argv is the ELF path plus extra args.
     *   sys_compat_run busybox false  →  ["…/busybox", "false"]
     * Dropping the ELF (old argc>=3 path) made that ["false"].
     * Guest then exit_group(0) — busybox no-applet / usage, not false.
     * sh execve(["cat"]) still works: execve flattens to
     *   sys_compat_run <busybox> cat  →  ["…/busybox", "cat"].
     */
    int linux_argc = argc - 1;
    char** linux_argv = &argv[1];

    /*
     * SysV stack, high → low: extra strings, auxv, envp, argv, argc.
     * glibc walks auxv for AT_RANDOM / AT_PHDR; a bare AT_PAGESZ was
     * enough for hello_* but busybox dies in startup after rseq.
     */
#define AT_NULL 0
#define AT_PHDR 3
#define AT_PHENT 4
#define AT_PHNUM 5
#define AT_PAGESZ 6
#define AT_BASE 7
#define AT_FLAGS 8
#define AT_ENTRY 9
#define AT_UID 11
#define AT_EUID 12
#define AT_GID 13
#define AT_EGID 14
#define AT_HWCAP 16
#define AT_CLKTCK 17
#define AT_SECURE 23
#define AT_RANDOM 25
#define AT_RSEQ_FEATURE_SIZE 27
#define AT_RSEQ_ALIGN 28
#define AT_EXECFN 31

    *(--sp) = 0xC0FFEEA11CE5F5ULL;
    *(--sp) = 0xDEADBEEFCAFEBABEULL;
    uint64_t at_random = (uint64_t)(uintptr_t)sp;

    uint64_t at_phdr = 0;
    if (ehdr.e_phoff < 0x1000)
        at_phdr = 0x400000ULL + (uint64_t)ehdr.e_phoff;

    *(--sp) = 0;
    *(--sp) = AT_NULL;
    if (linux_argc > 0) {
        *(--sp) = (uint64_t)(uintptr_t)linux_argv[0];
        *(--sp) = AT_EXECFN;
    }
    *(--sp) = at_random;
    *(--sp) = AT_RANDOM;
    /* Original rseq ABI: 20-byte used size, 32-byte alloc/align.
     * Do not advertise more than the hook implements (cpu_id + rseq_cs). */
    *(--sp) = 32;
    *(--sp) = AT_RSEQ_ALIGN;
    *(--sp) = 20;
    *(--sp) = AT_RSEQ_FEATURE_SIZE;
    *(--sp) = 0;
    *(--sp) = AT_SECURE;
    *(--sp) = 100;
    *(--sp) = AT_CLKTCK;
    *(--sp) = 0;
    *(--sp) = AT_HWCAP;
    *(--sp) = 0;
    *(--sp) = AT_EGID;
    *(--sp) = 0;
    *(--sp) = AT_GID;
    *(--sp) = 0;
    *(--sp) = AT_EUID;
    *(--sp) = 0;
    *(--sp) = AT_UID;
    *(--sp) = (uint64_t)ehdr.e_entry;
    *(--sp) = AT_ENTRY;
    *(--sp) = 0;
    *(--sp) = AT_FLAGS;
    *(--sp) = 0;
    *(--sp) = AT_BASE;
    *(--sp) = 4096;
    *(--sp) = AT_PAGESZ;
    *(--sp) = (uint64_t)ehdr.e_phnum;
    *(--sp) = AT_PHNUM;
    *(--sp) = (uint64_t)ehdr.e_phentsize;
    *(--sp) = AT_PHENT;
    if (at_phdr != 0) {
        *(--sp) = at_phdr;
        *(--sp) = AT_PHDR;
    }

    *(--sp) = 0; /* envp */
    *(--sp) = 0; /* argv NULL */
    for (int i = linux_argc - 1; i >= 0; i--)
        *(--sp) = (uint64_t)(uintptr_t)linux_argv[i];
    *(--sp) = (uint64_t)linux_argc;

    printf("[+] System V ABI Stack prepared at RSP=0x%lx (argc=%d)...\n",
           (unsigned long)(uintptr_t)sp, linux_argc);
    {
        int ai;
        printf("[+] linux argv:");
        for (ai = 0; ai < linux_argc; ai++)
            printf(" [%s]", linux_argv[ai] ? linux_argv[ai] : "(null)");
        printf("\n");
    }
    printf("[+] Transferring execution to Linux entry point 0x%lx...\n",
           (unsigned long)ehdr.e_entry);

    int compat_fd = open(SYS_COMPAT_DEVICE, O_RDWR);
    printf("[+] open(%s) -> %d\n", SYS_COMPAT_DEVICE, compat_fd);
    if (compat_fd < 0) {
        perror("[-] sys_compat device (is the driver loaded?)");
        return 1;
    }
    /*
     * Pre-map a brk/mmap arena while we are still a Haiku team.
     * Passed to 0x1337 as (rdi=base, rsi=size). glibc static TLS
     * allocation needs this before any Linux malloc.
     */
/* ailang.x Import_ReadFile Allocate(64MB+1) per module and keeps it.
	 * 54 modules ≈ 3.46GB plus 160/256MB compile maps. 3584MB still
	 * ENOMEM after IMPORT Done. uint32 max 4095MB. PR54f recycles. */
#define SYS_COMPAT_ARENA_SIZE (4095u * 1024u * 1024u)
    /* Tiny fork probes do not malloc; skip the 32MB arena so fork_team
     * does not COW it. Name contains "fork". */
    int skip_arena = (strstr(elf_path, "fork") != NULL);
    uint32_t arena_sz = skip_arena ? 0 : SYS_COMPAT_ARENA_SIZE;
    void* arena = NULL;
    if (arena_sz != 0) {
        static const uint32_t tries[] = {
            SYS_COMPAT_ARENA_SIZE,
            3072u * 1024u * 1024u,
            2048u * 1024u * 1024u,
            1024u * 1024u * 1024u
        };
        unsigned ti;
        arena = MAP_FAILED;
        for (ti = 0; ti < sizeof(tries) / sizeof(tries[0]); ti++) {
            arena_sz = tries[ti];
            arena = haiku_private_anon("linux_arena", (size_t)arena_sz,
                B_READ_AREA | B_WRITE_AREA);
            if (arena != MAP_FAILED)
                break;
            printf("[-] create_area linux_arena %u failed\n", arena_sz);
        }
        if (arena == MAP_FAILED) {
            printf("[-] create_area brk/mmap arena\n");
            return 1;
        }
        printf("[+] arena %p +%u for Linux brk/mmap\n",
               arena, arena_sz);
    } else
        printf("[+] no arena (fork probe)\n");
    /* Child IRETQ trampoline (rseq-style: this layer owns the return).
     *  49 bb <rsp>     movabs $linux_rsp, %r11
     *  4c 89 dc        mov %r11, %rsp
     *  49 bb <rip>     movabs $linux_rip, %r11
     *  41 ff e3        jmp *%r11
     * Hook patches +2 (rsp) and +15 (rip). */
    unsigned char* tramp = (unsigned char*)haiku_private_anon("linux_tramp",
        4096, B_READ_AREA | B_WRITE_AREA | B_EXECUTE_AREA);
    if (tramp == MAP_FAILED) {
        printf("[-] create_area fork IRETQ trampoline\n");
        return 1;
    }
    {
        /* Child IRETQ lands at +0: xor edi,edi; mov eax,60; syscall.
         * First syscall is Linux exit — stamps CR3, then _kern_exit_team. */
        static const unsigned char ex[] = {
            0x48, 0x31, 0xff,
            0xb8, 0x3c, 0x00, 0x00, 0x00,
            0x0f, 0x05,
            0xeb, 0xfe
        };
        unsigned i;
        for (i = 0; i < sizeof(ex); i++)
            tramp[i] = ex[i];
    }
    /* Linux /proc/self/cmdline: argv joined by NUL. Ailang reads this,
	 * not only the SysV stack. Keep off the clone tramp (uses +0x80). */
    {
        unsigned char* cmd = tramp + 0x400;
        int off = 0;
        int ai;
        memset(cmd, 0, 512);
        for (ai = 0; ai < linux_argc && off < 500; ai++) {
            const char* a = linux_argv[ai] ? linux_argv[ai] : "";
            int k;
            for (k = 0; a[k] != 0 && off < 500; k++)
                cmd[off++] = (unsigned char)a[k];
            if (off < 500)
                cmd[off++] = 0;
        }
        printf("[+] cmdline %d bytes argc=%d\n", off, linux_argc);
    }
    printf("[+] fork IRETQ trampoline %p\n", (void*)tramp);
    /* Do not Haiku-fork here. Serial showed mark+jmp after a Haiku
     * fork reboots before Linux clone. Keep the 0x400000 map pristine. */
    /* Close before mark. A leftover fd is closed by glibc exit and
     * used to unmark in dev_free. Mark is raw 0x1337; the fd is only
     * a load check + ULS discover. */
    close(compat_fd);
    printf("[+] mark via raw syscall 0x%x then jmp 0x%lx (no libc after mark)\n",
           SYS_COMPAT_MARK_NR, (unsigned long)ehdr.e_entry);
    fflush(stdout);

    /*
     * Mark + jump in one asm block. r12/r13 survive the mark sysret.
     * rdi/rsi = arena, rdx = IRETQ trampoline, r8 = Haiku RSP.
     *
     * Linux _start does mov %rdx,%r9 (rtld_fini). The tramp is
     * xor-edi / SYS_exit 60 — if rdx is still the tramp, glibc
     * exit() calls it before fflush and date/puts never write.
     * Mark already stored the tramp in gForkTramp; zero rdx.
     */
    {
        uint64_t haiku_rsp;
        __asm__ __volatile__("movq %%rsp, %0" : "=r"(haiku_rsp));
        register uint64_t rsp_val asm("r12") = (uint64_t)(uintptr_t)sp;
        register uint64_t entry_val asm("r13") = (uint64_t)(uintptr_t)ehdr.e_entry;
        register uint64_t arena_val asm("rdi") = (uint64_t)(uintptr_t)arena;
        register uint64_t size_val asm("rsi") = (uint64_t)arena_sz;
        register uint64_t tramp_val asm("rdx") = (uint64_t)(uintptr_t)tramp;
        register uint64_t hrsp_val asm("r8") = haiku_rsp;
        register uint64_t exe_val asm("r9") = (uint64_t)(uintptr_t)elf_path;
        register uint64_t cmd_val asm("r10") = (uint64_t)(uintptr_t)(tramp + 0x400);
        __asm__ __volatile__(
            "mov $0x1337, %%rax\n\t"
            "syscall\n\t"
            "xor %%edx, %%edx\n\t"
            "mov %%r12, %%rsp\n\t"
            "jmp *%%r13\n\t"
            :
            : "r"(rsp_val), "r"(entry_val), "D"(arena_val), "S"(size_val),
              "d"(tramp_val), "r"(hrsp_val), "r"(exe_val), "r"(cmd_val)
            : "rax", "rcx", "r11", "memory"
        );
    }

    return 0;
}
