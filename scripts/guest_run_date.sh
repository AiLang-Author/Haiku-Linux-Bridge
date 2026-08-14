#!/bin/sh
# Prove time/gettimeofday + busybox date. Then hello_min still works.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
OUT=/tmp/date.out
RUNNER=/boot/home/sys_compat_run
BB=/boot/home/busybox
{
	echo "=== status before ==="
	cat /dev/misc/sys_compat 2>&1
	echo "=== hello_min ==="
	$RUNNER /boot/home/hello_min
	echo HELLO_RC=$?
	echo "=== hello_date ==="
	$RUNNER /boot/home/hello_date
	echo DATE_RC=$?
	echo "=== busybox date ==="
	$RUNNER $BB date
	echo BBDATE_RC=$?
	echo "=== busybox date -u ==="
	$RUNNER $BB date -u
	echo BBDATEU_RC=$?
	echo "=== status after ==="
	cat /dev/misc/sys_compat 2>&1
} > "$OUT" 2>&1
echo "=== date.out ==="
cat "$OUT"
curl -s -X POST --data-binary @"$OUT" "$HOST/results/date_out.txt" || true
echo RUN_DATE_DONE
