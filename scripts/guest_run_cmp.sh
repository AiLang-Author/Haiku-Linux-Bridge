#!/bin/sh
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
RUN=/boot/home/sys_compat_run
BB=/boot/home/busybox
printf 'hello world\nfoo bar\nhello linux\nzzz\n' > /tmp/sa.txt
printf 'hello world\nfoo bar\n' > /tmp/sb.txt
{
	echo "=== cmp ==="
	$RUN $BB cmp /tmp/sa.txt /tmp/sb.txt
	echo CMP_RC=$?
	echo "=== date ==="
	$RUN $BB date -u
	echo DATE_RC=$?
} > /tmp/cmp.out 2>&1
cat /tmp/cmp.out
curl -s --max-time 8 -X POST --data-binary @/tmp/cmp.out "$HOST/results/cmp_out.txt" || true
echo CMP_SCRIPT_DONE
