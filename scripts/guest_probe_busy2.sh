#!/bin/sh
# Busybox probe that does not wait on crash dialogs.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
OUT=/tmp/busy2.out
if [ ! -x /boot/home/busybox ]; then
	curl -s -o /boot/home/busybox "$HOST/payload/tests/busybox"
	chmod 755 /boot/home/busybox
fi
{
	echo "=== status before ==="
	cat /dev/misc/sys_compat 2>&1
	echo "=== busybox echo (background, 3s) ==="
	/boot/home/sys_compat_run /boot/home/busybox echo BUSYBOX_ECHO > /tmp/bb_echo.out 2>&1 &
	sleep 3
	echo "=== bb_echo.out ==="
	cat /tmp/bb_echo.out 2>&1
	echo "=== status after ==="
	cat /dev/misc/sys_compat 2>&1
} > "$OUT" 2>&1
echo "=== busy2.out ==="
cat "$OUT"
curl -s -X POST --data-binary @"$OUT" "$HOST/results/busy2_out.txt" || true
echo PROBE_BUSY2_DONE
