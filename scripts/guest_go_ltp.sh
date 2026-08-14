#!/bin/sh
# Stage first-wave LTP bins and arm a one-shot smoke (no driver rebuild).
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
curl -s -o /boot/home/run_ltp.sh "$HOST/scripts/guest_run_ltp.sh"
chmod 755 /boot/home/run_ltp.sh
mkdir -p /boot/home/ltp/bin
for name in hello_min uname01 exit01 getpid01 gettid01 write01 read01 close01 \
	open01 openat01 lseek01 fstat02 stat01 brk01 mmap01 munmap01 arch_prctl01; do
	src="$HOST/payload/ltp/bin/$name"
	[ "$name" = hello_min ] && src="$HOST/payload/tests/hello_min"
	curl -s -o "/boot/home/ltp/bin/$name" "$src"
	chmod 755 "/boot/home/ltp/bin/$name"
done
ls -l /boot/home/ltp/bin | head
echo GO_LTP_DONE
# run immediately; do not reboot
sh /boot/home/run_ltp.sh
