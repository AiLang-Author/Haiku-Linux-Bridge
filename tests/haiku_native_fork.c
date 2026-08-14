/* Native Haiku fork smoke. Not a Linux ELF.
 * License: Public Domain / CC0 1.0 Universal */
#include <stdio.h>
#include <unistd.h>
#include <sys/wait.h>

int
main(void)
{
	pid_t p;

	printf("NATIVE_PRE\n");
	fflush(stdout);
	p = fork();
	if (p < 0) {
		printf("NATIVE_NEG\n");
		return 1;
	}
	if (p == 0) {
		printf("NATIVE_CHILD\n");
		_exit(0);
	}
	printf("NATIVE_PARENT %d\n", (int)p);
	waitpid(p, NULL, 0);
	printf("NATIVE_OK\n");
	return 0;
}
