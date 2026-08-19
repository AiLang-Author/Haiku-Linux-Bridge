#!/bin/sh
# Guest: punch-out proof — exit status + stdout after teardown.
# Fetch/POST is Haiku curl (BSD sockets), not the Linux ABI.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
OUT=/tmp/status.out
RUN=/boot/home/sys_compat_run
BB=/boot/home/busybox
printf 'hello world\nfoo bar\nhello linux\nzzz\n' > /tmp/sa.txt
printf 'hello world\nfoo bar\n' > /tmp/sb.txt
{
	echo "=== false ==="
	$RUN $BB false
	echo FALSE_RC=$?
	echo "=== true ==="
	$RUN $BB true
	echo TRUE_RC=$?
	echo "=== cmp ==="
	$RUN $BB cmp /tmp/sa.txt /tmp/sb.txt
	echo CMP_RC=$?
	echo "=== date ==="
	$RUN $BB date -u
	echo DATE_RC=$?
	echo "=== md5 ==="
	$RUN $BB md5sum /tmp/sa.txt
	echo MD5_RC=$?
	echo "=== nproc ==="
	$RUN $BB nproc
	echo NPROC_RC=$?
	echo "=== id ==="
	$RUN $BB id
	echo ID_RC=$?
} > "$OUT" 2>&1
cat "$OUT"
curl -s --max-time 8 -X POST --data-binary @"$OUT" "$HOST/results/status_out.txt" || true
echo RUN_STATUS_DONE
