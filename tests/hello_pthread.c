/* glibc-static pthread_create + join. License: Public Domain / CC0 1.0 Universal */
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>

static void *
worker(void *arg)
{
	*(int *)arg = 42;
	return (void *)(intptr_t)0x55;
}

int
main(void)
{
	pthread_t t;
	int x;
	void *ret;

	x = 0;
	ret = 0;
	if (pthread_create(&t, NULL, worker, &x) != 0) {
		puts("PTCREATEFAIL");
		return 1;
	}
	if (pthread_join(t, &ret) != 0) {
		puts("PTJOINFAIL");
		return 1;
	}
	if (x != 42 || ret != (void *)(intptr_t)0x55) {
		puts("PTDATAFAIL");
		return 1;
	}
	puts("PTHREADOK");
	return 0;
}
