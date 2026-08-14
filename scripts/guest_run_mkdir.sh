#!/bin/sh
# After mkdir/getcwd/chdir land: re-run uname01 + write01.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
OUT=/tmp/mkdir.out
RUNNER=/boot/home/sys_compat_run
{
	echo "=== status ==="
	cat /dev/misc/sys_compat 2>&1
	echo "=== hello_min ==="
	$RUNNER /boot/home/hello_min
	echo HELLO_RC=$?
	echo "=== uname01 ==="
	$RUNNER /boot/home/ltp/bin/uname01
	echo UNAME01_RC=$?
	echo "=== write01 ==="
	$RUNNER /boot/home/ltp/bin/write01
	echo WRITE01_RC=$?
	echo "=== status after ==="
	cat /dev/misc/sys_compat 2>&1
} > "$OUT" 2>&1
echo "=== mkdir.out ==="
cat "$OUT"
curl -s -X POST --data-binary @"$OUT" "$HOST/results/mkdir_out.txt" || true
echo RUN_MKDIR_DONE
