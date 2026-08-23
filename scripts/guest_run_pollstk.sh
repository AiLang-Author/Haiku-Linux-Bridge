#!/bin/sh
# Run ELF poll, blocking poll, and stack pollfd. Expect POLLOK POLLBLKOK POLLSTKOK.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
OUT=/tmp/pollstk.out
{
	echo "=== status ==="
	cat /dev/misc/sys_compat 2>&1
	echo "=== hello_poll ==="
	/boot/home/sys_compat_run /boot/home/hello_poll
	echo POLL_RC=$?
	echo "=== hello_pollblk ==="
	/boot/home/sys_compat_run /boot/home/hello_pollblk
	echo POLLBLK_RC=$?
	echo "=== hello_pollstk ==="
	/boot/home/sys_compat_run /boot/home/hello_pollstk
	echo POLLSTK_RC=$?
	echo "=== status after ==="
	cat /dev/misc/sys_compat 2>&1
} > "$OUT" 2>&1
echo "=== pollstk.out ==="
cat "$OUT"
curl -s --max-time 8 -X POST --data-binary @"$OUT" "$HOST/results/pollstk_out.txt" || true
echo RUN_POLLSTK_DONE
