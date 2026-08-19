/* Linux fbdev probe against Haiku VESA. License: Public Domain / CC0 */
#define _GNU_SOURCE
#include <unistd.h>
#include <sys/syscall.h>
#include <sys/mman.h>

#ifndef AT_FDCWD
#define AT_FDCWD (-100)
#endif
#define O_RDWR 2
#define FBIOGET_VSCREENINFO 0x4600
#define FBIOGET_FSCREENINFO 0x4602

static long
sys3(long n, long a, long b, long c)
{
	long r;
	__asm__ volatile ("syscall"
		: "=a"(r)
		: "a"(n), "D"(a), "S"(b), "d"(c)
		: "rcx", "r11", "memory");
	return r;
}

static long
sys6(long n, long a, long b, long c, long d, long e, long f)
{
	long r;
	register long r10 asm("r10") = d;
	register long r8 asm("r8") = e;
	register long r9 asm("r9") = f;
	__asm__ volatile ("syscall"
		: "=a"(r)
		: "a"(n), "D"(a), "S"(b), "d"(c), "r"(r10), "r"(r8), "r"(r9)
		: "rcx", "r11", "memory");
	return r;
}

static void
emit(const char* s)
{
	unsigned n = 0;
	while (s[n])
		n++;
	write(1, s, n);
}

static void
emit_long(long v)
{
	char tmp[24], out[24];
	int k = 0, n = 0;
	unsigned long u;
	if (v < 0) {
		out[n++] = '-';
		u = (unsigned long)(-v);
	} else
		u = (unsigned long)v;
	if (u == 0)
		out[n++] = '0';
	else {
		while (u) {
			tmp[k++] = (char)('0' + (u % 10));
			u /= 10;
		}
		while (k)
			out[n++] = tmp[--k];
	}
	write(1, out, (unsigned)n);
}

int
main(void)
{
	static const char path[] = "/dev/fb0";
	unsigned char var[160];
	unsigned char fix[80];
	long fd, r;
	unsigned xres, yres, bpp, slen, pitch;
	void* map;
	unsigned pix;
	int i;

	for (i = 0; i < 160; i++)
		var[i] = 0;
	for (i = 0; i < 80; i++)
		fix[i] = 0;
	fd = sys3(SYS_openat, AT_FDCWD, (long)path, O_RDWR);
	emit("FBFD=");
	emit_long(fd);
	emit("\n");
	if (fd < 0)
		return 1;
	r = sys3(SYS_ioctl, fd, FBIOGET_VSCREENINFO, (long)var);
	emit("VINF=");
	emit_long(r);
	xres = (unsigned)var[0] | ((unsigned)var[1] << 8)
		| ((unsigned)var[2] << 16) | ((unsigned)var[3] << 24);
	yres = (unsigned)var[4] | ((unsigned)var[5] << 8)
		| ((unsigned)var[6] << 16) | ((unsigned)var[7] << 24);
	bpp = (unsigned)var[24] | ((unsigned)var[25] << 8)
		| ((unsigned)var[26] << 16) | ((unsigned)var[27] << 24);
	emit(" x=");
	emit_long(xres);
	emit(" y=");
	emit_long(yres);
	emit(" bpp=");
	emit_long(bpp);
	emit("\n");
	r = sys3(SYS_ioctl, fd, FBIOGET_FSCREENINFO, (long)fix);
	emit("FINF=");
	emit_long(r);
	slen = (unsigned)fix[24] | ((unsigned)fix[25] << 8)
		| ((unsigned)fix[26] << 16) | ((unsigned)fix[27] << 24);
	pitch = (unsigned)fix[48] | ((unsigned)fix[49] << 8)
		| ((unsigned)fix[50] << 16) | ((unsigned)fix[51] << 24);
	emit(" len=");
	emit_long(slen);
	emit(" pitch=");
	emit_long(pitch);
	emit("\n");
	if (r != 0 || slen < 4096)
		return 1;
	map = (void*)sys6(SYS_mmap, 0, slen, PROT_READ | PROT_WRITE,
		MAP_SHARED, fd, 0);
	emit("FMAP=");
	emit_long((long)map);
	emit("\n");
	if ((unsigned long)map > 0xfffffffffffff000UL)
		return 1;
	pix = ((unsigned char*)map)[0]
		| ((unsigned)((unsigned char*)map)[1] << 8)
		| ((unsigned)((unsigned char*)map)[2] << 16)
		| ((unsigned)((unsigned char*)map)[3] << 24);
	emit("FPIX=");
	emit_long((long)(unsigned)pix);
	emit("\n");
	emit("FBOK\n");
	return 0;
}
