/* glibc-static clock_gettime + write. License: Public Domain / CC0 1.0 Universal */
#define _GNU_SOURCE
#include <time.h>
#include <unistd.h>
int main(void) {
	struct timespec ts;
	char buf[64];
	int n, i;
	unsigned long s;
	if (clock_gettime(0, &ts) != 0) {
		write(1, "CLOCK_FAIL\n", 11);
		return 1;
	}
	s = (unsigned long)ts.tv_sec;
	buf[0] = 'T'; buf[1] = '=';
	n = 2;
	if (s == 0) buf[n++] = '0';
	else {
		char tmp[24]; int k = 0;
		while (s) { tmp[k++] = '0' + (s % 10); s /= 10; }
		while (k) buf[n++] = tmp[--k];
	}
	buf[n++] = '\n';
	write(1, buf, n);
	return 0;
}
