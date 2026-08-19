#!/bin/sh
# Guest: fflush / last-write probe.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
RUN=/boot/home/sys_compat_run
BB=/boot/home/busybox
curl -s -o /boot/home/hello_wr "$HOST/payload/tests/hello_wr" || true
chmod 755 /boot/home/hello_wr 2>/dev/null || true
{
	echo "=== hello_wr ==="
	$RUN /boot/home/hello_wr
	echo WR_RC=$?
	echo "=== date ==="
	$RUN $BB date -u
	echo DATE_RC=$?
	echo "=== md5 ==="
	printf 'hello world\n' > /tmp/sa.txt
	$RUN $BB md5sum /tmp/sa.txt
	echo MD5_RC=$?
	echo "=== echo ==="
	$RUN $BB echo ECHO_STILL
	echo ECHO_RC=$?
} > /tmp/date.out 2>&1
cat /tmp/date.out
curl -s --max-time 8 -X POST --data-binary @/tmp/date.out "$HOST/results/date_out.txt" || true
echo RUN_DATE_DONE
