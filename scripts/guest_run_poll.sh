#!/bin/sh
# Run Linux pipe2+poll probe. Expect POLLOK.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
OUT=/tmp/poll.out
{
	echo "=== status ==="
	cat /dev/misc/sys_compat 2>&1
	echo "=== hello_poll ==="
	/boot/home/sys_compat_run /boot/home/hello_poll
	echo POLL_RC=$?
	echo "=== status after ==="
	cat /dev/misc/sys_compat 2>&1
} > "$OUT" 2>&1
echo "=== poll.out ==="
cat "$OUT"
curl -s --max-time 8 -X POST --data-binary @"$OUT" "$HOST/results/poll_out.txt" || true
echo RUN_POLL_DONE
