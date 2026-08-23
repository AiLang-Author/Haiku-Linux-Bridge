#!/bin/sh
# glibc-static pthread_create+join. Expect PTHREADOK.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
OUT=/tmp/pthread.out
{
	echo "=== status ==="
	cat /dev/misc/sys_compat 2>&1
	echo "=== hello_pthread ==="
	/boot/home/sys_compat_run /boot/home/hello_pthread
	echo PTHREAD_RC=$?
	echo "=== status after ==="
	cat /dev/misc/sys_compat 2>&1
} > "$OUT" 2>&1
echo "=== pthread.out ==="
cat "$OUT"
curl -s --max-time 8 -X POST --data-binary @"$OUT" "$HOST/results/pthread_out.txt" || true
echo RUN_PTHREAD_DONE
