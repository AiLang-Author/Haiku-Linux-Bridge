#!/bin/sh
# Prove hello_min, then hello_rseq (Linux sys_rseq in the hook).
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
OUT=/tmp/rseq.out
{
	echo "=== status before ==="
	cat /dev/misc/sys_compat 2>&1
	echo "=== hello_min ==="
	/boot/home/sys_compat_run /boot/home/hello_min
	echo "HELLO_RC=$?"
	echo "=== hello_rseq ==="
	/boot/home/sys_compat_run /boot/home/hello_rseq
	echo "RSEQ_RC=$?"
	echo "=== status after rseq ==="
	cat /dev/misc/sys_compat 2>&1
	if [ -x /boot/home/busybox ]; then
		echo "=== busybox echo bg ==="
		/boot/home/sys_compat_run /boot/home/busybox echo BUSYBOX_ECHO > /tmp/bb_echo.out 2>&1 &
		sleep 2
		echo "=== bb_echo.out ==="
		cat /tmp/bb_echo.out 2>&1
		echo "=== status after busy ==="
		cat /dev/misc/sys_compat 2>&1
	fi
} > "$OUT" 2>&1
echo "=== rseq.out ==="
cat "$OUT"
curl -s -X POST --data-binary @"$OUT" "$HOST/results/rseq_out.txt" || true
echo RUN_RSEQ_DONE
