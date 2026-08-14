#!/bin/sh
# Prove hello_min, hello_fcntl (fcntl+statx), hello_date still works.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
OUT=/tmp/fcntl.out
RUNNER=/boot/home/sys_compat_run
{
	echo "=== status before ==="
	cat /dev/misc/sys_compat 2>&1
	echo "=== hello_min ==="
	$RUNNER /boot/home/hello_min
	echo HELLO_RC=$?
	echo "=== hello_fcntl ==="
	$RUNNER /boot/home/hello_fcntl
	echo FCNTL_RC=$?
	echo "=== hello_date ==="
	$RUNNER /boot/home/hello_date
	echo DATE_RC=$?
	echo "=== status after ==="
	cat /dev/misc/sys_compat 2>&1
} > "$OUT" 2>&1
echo "=== fcntl.out ==="
cat "$OUT"
curl -s -X POST --data-binary @"$OUT" "$HOST/results/fcntl_out.txt" || true
echo RUN_FCNTL_DONE
