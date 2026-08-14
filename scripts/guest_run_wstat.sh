#!/bin/sh
# Prove hello_min then the former stub pack (chmod/uid/mprotect/...).
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
OUT=/tmp/wstat.out
RUNNER=/boot/home/sys_compat_run
{
	echo "=== status before ==="
	cat /dev/misc/sys_compat 2>&1
	echo "=== hello_min ==="
	$RUNNER /boot/home/hello_min
	echo HELLO_RC=$?
	echo "=== hello_wstat ==="
	$RUNNER /boot/home/hello_wstat
	echo WSTAT_RC=$?
	echo "=== status after ==="
	cat /dev/misc/sys_compat 2>&1
} > "$OUT" 2>&1
echo "=== wstat.out ==="
cat "$OUT"
curl -s -X POST --data-binary @"$OUT" "$HOST/results/wstat_out.txt" || true
echo RUN_WSTAT_DONE
