#include <stdio.h>
#include <unistd.h>
#include <stdint.h>

extern ssize_t _kern_read(int fd, off_t pos, void *buf, size_t n);
extern ssize_t _kern_write(int fd, off_t pos, const void *buf, size_t n);
extern int _kern_close(int fd);
extern off_t _kern_seek(int fd, off_t pos, int seekType);
extern int _kern_open(int fd, const char *path, int flags, int mode);
extern void _kern_exit_team(int status);

static uint64_t imm_from_stub(const unsigned char *b)
{
	/* movq $n, %rax is 48 c7 c0 imm32  (or 48 b8 imm64) */
	int i;
	for (i = 0; i < 20; i++) {
		if (b[i] == 0x48 && b[i + 1] == 0xc7 && b[i + 2] == 0xc0)
			return (uint64_t)(uint32_t)(b[i + 3] | (b[i + 4] << 8)
				| (b[i + 5] << 16) | (b[i + 6] << 24));
		if (b[i] == 0x48 && b[i + 1] == 0xb8) {
			uint64_t v = 0;
			int k;
			for (k = 0; k < 8; k++)
				v |= (uint64_t)b[i + 2 + k] << (8 * k);
			return v;
		}
	}
	return (uint64_t)-1;
}

static void dump(const char *name, void *p)
{
	unsigned char *b = (unsigned char *)p;
	int i;
	uint64_t n = imm_from_stub(b);
	printf("%s@%p nr=0x%llx (%llu):", name, p,
	       (unsigned long long)n, (unsigned long long)n);
	for (i = 0; i < 20; i++)
		printf(" %02x", b[i]);
	printf("\n");
}

int main(void)
{
	dump("write", (void *)&write);
	dump("_kern_read", (void *)&_kern_read);
	dump("_kern_write", (void *)&_kern_write);
	dump("_kern_close", (void *)&_kern_close);
	dump("_kern_seek", (void *)&_kern_seek);
	dump("_kern_open", (void *)&_kern_open);
	dump("_kern_exit_team", (void *)&_kern_exit_team);
	return 0;
}
