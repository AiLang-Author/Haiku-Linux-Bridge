/*
 * Dump Haiku fcntl/seek constants from this image's headers.
 * License: Public Domain / CC0 1.0 Universal
 */
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>

int main(void)
{
	printf("O_RDONLY=0x%x O_WRONLY=0x%x O_RDWR=0x%x O_ACCMODE=0x%x\n",
	       O_RDONLY, O_WRONLY, O_RDWR, O_ACCMODE);
	printf("O_CREAT=0x%x O_EXCL=0x%x O_TRUNC=0x%x O_APPEND=0x%x\n",
	       O_CREAT, O_EXCL, O_TRUNC, O_APPEND);
	printf("O_NONBLOCK=0x%x O_CLOEXEC=0x%x O_DIRECTORY=0x%x O_NOFOLLOW=0x%x\n",
	       O_NONBLOCK, O_CLOEXEC, O_DIRECTORY, O_NOFOLLOW);
	printf("AT_FDCWD=%d SEEK_SET=%d SEEK_CUR=%d SEEK_END=%d\n",
	       AT_FDCWD, SEEK_SET, SEEK_CUR, SEEK_END);
	return 0;
}
