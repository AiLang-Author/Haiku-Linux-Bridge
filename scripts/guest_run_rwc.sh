#!/bin/sh
# Prove Linux read+write+close+exit via inherited stdin.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
OUT=/tmp/rwc.out
{
	echo "=== status before ==="
	cat /dev/misc/sys_compat 2>&1 || echo "no device"
	echo "=== run ==="
	printf 'RWC_PAYLOAD\n' | /boot/home/sys_compat_run /boot/home/hello_rwc
	echo "DONE_RC=$?"
	echo "=== status after ==="
	cat /dev/misc/sys_compat 2>&1 || echo "no device"
} > "$OUT" 2>&1
echo "=== rwc.out ==="
cat "$OUT"
curl -s -X POST --data-binary @"$OUT" "$HOST/results/rwc_out.txt" || true
echo RUN_RWC_DONE
