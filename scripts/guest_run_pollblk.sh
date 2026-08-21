#!/bin/sh
# Run timeout-0 hello_poll then blocking hello_pollblk.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
OUT=/tmp/pollblk.out
{
	echo "=== status ==="
	cat /dev/misc/sys_compat 2>&1
	echo "=== hello_poll ==="
	/boot/home/sys_compat_run /boot/home/hello_poll
	echo POLL_RC=$?
	echo "=== hello_pollblk ==="
	/boot/home/sys_compat_run /boot/home/hello_pollblk
	echo POLLBLK_RC=$?
	echo "=== status after ==="
	cat /dev/misc/sys_compat 2>&1
} > "$OUT" 2>&1
echo "=== pollblk.out ==="
cat "$OUT"
curl -s --max-time 8 -X POST --data-binary @"$OUT" "$HOST/results/pollblk_out.txt" || true
echo RUN_POLLBLK_DONE
