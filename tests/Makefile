# Tests Makefile for sys_compat
# License: Public Domain / CC0 1.0 Universal

CC ?= gcc
CFLAGS = -O2 -static -Wall

TARGETS = hello_linux test_file test_mem test_sys test_net test_ioctl test_vfs test_epoll test_signal

all: $(TARGETS)

hello_linux: hello_linux.c
	$(CC) $(CFLAGS) $< -o $@

test_file: test_file.c
	$(CC) $(CFLAGS) $< -o $@

test_mem: test_mem.c
	$(CC) $(CFLAGS) $< -o $@

test_sys: test_sys.c
	$(CC) $(CFLAGS) $< -o $@

test_net: test_net.c
	$(CC) $(CFLAGS) $< -o $@

test_ioctl: test_ioctl.c
	$(CC) $(CFLAGS) $< -o $@

test_vfs: test_vfs.c
	$(CC) $(CFLAGS) $< -o $@

test_epoll: test_epoll.c
	$(CC) $(CFLAGS) $< -o $@

test_signal: test_signal.c
	$(CC) $(CFLAGS) $< -o $@

clean:
	rm -f $(TARGETS)

.PHONY: all clean
