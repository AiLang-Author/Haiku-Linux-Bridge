/* Linux TTY ioctl probe. License: Public Domain / CC0 1.0 Universal */
#define _GNU_SOURCE
#include <unistd.h>
#include <sys/syscall.h>

#define LINUX_TCGETS     0x5401
#define LINUX_TIOCGWINSZ 0x5413
#define LINUX_TIOCGPGRP  0x540F

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
	char tmp[24];
	char out[24];
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

static void
emit_hex(unsigned long v)
{
	char o[18];
	int i;
	o[0] = '0';
	o[1] = 'x';
	for (i = 0; i < 8; i++) {
		unsigned d = (unsigned)((v >> ((7 - i) * 4)) & 0xf);
		o[2 + i] = (char)(d < 10 ? '0' + d : 'a' + d - 10);
	}
	write(1, o, 10);
}

int
main(void)
{
	unsigned char term[64];
	unsigned short ws[4];
	int pgrp;
	long r;
	int i;
	unsigned long lflag;

	for (i = 0; i < 64; i++)
		term[i] = 0;
	ws[0] = ws[1] = ws[2] = ws[3] = 0;
	pgrp = 0;

	r = sys3(SYS_ioctl, 0, LINUX_TCGETS, (long)term);
	emit("TTY0=");
	emit_long(r);
	emit("\n");
	if (r == 0) {
		lflag = (unsigned long)term[12]
			| ((unsigned long)term[13] << 8)
			| ((unsigned long)term[14] << 16)
			| ((unsigned long)term[15] << 24);
		emit("LFLAG0=");
		emit_hex(lflag);
		emit("\n");
	}

	r = sys3(SYS_ioctl, 0, LINUX_TIOCGWINSZ, (long)ws);
	emit("WINSZ0=");
	emit_long(r);
	emit(" r=");
	emit_long(ws[0]);
	emit(" c=");
	emit_long(ws[1]);
	emit("\n");

	r = sys3(SYS_ioctl, 0, LINUX_TIOCGPGRP, (long)&pgrp);
	emit("PGRP0=");
	emit_long(r);
	emit(" pgid=");
	emit_long(pgrp);
	emit("\n");

	r = sys3(SYS_ioctl, 1, LINUX_TCGETS, (long)term);
	emit("TTY1=");
	emit_long(r);
	emit("\n");

	r = sys3(SYS_ioctl, 1, LINUX_TIOCGWINSZ, (long)ws);
	emit("WINSZ1=");
	emit_long(r);
	emit(" r=");
	emit_long(ws[0]);
	emit(" c=");
	emit_long(ws[1]);
	emit("\n");

	return 0;
}
