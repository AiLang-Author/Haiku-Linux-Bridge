#!/bin/sh
# Run Linux futex WAIT/WAKE probe. Expect FUTEXOK.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
OUT=/tmp/futex.out
{
	echo "=== status ==="
	cat /dev/misc/sys_compat 2>&1
	echo "=== hello_futex ==="
	/boot/home/sys_compat_run /boot/home/hello_futex
	echo FUTEX_RC=$?
	echo "=== status after ==="
	cat /dev/misc/sys_compat 2>&1
} > "$OUT" 2>&1
echo "=== futex.out ==="
cat "$OUT"
curl -s -X POST --data-binary @"$OUT" "$HOST/results/futex_out.txt" || true
echo RUN_FUTEX_DONE
