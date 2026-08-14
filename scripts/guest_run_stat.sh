#!/bin/sh
# Prove hello_stat then busybox ls -l (real types/sizes).
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
OUT=/tmp/stat.out
{
	echo "=== status before ==="
	cat /dev/misc/sys_compat 2>&1
	echo "=== hello_min ==="
	/boot/home/sys_compat_run /boot/home/hello_min
	echo "HELLO_RC=$?"
	echo "=== hello_stat ==="
	/boot/home/sys_compat_run /boot/home/hello_stat
	echo "STAT_RC=$?"
	echo "=== status after hello_stat ==="
	cat /dev/misc/sys_compat 2>&1
	if [ -x /boot/home/busybox ]; then
		echo "=== busybox ls -l /boot/home ==="
		/boot/home/sys_compat_run /boot/home/busybox ls -l /boot/home
		echo "LSL_RC=$?"
		echo "=== busybox ls -l /boot/home/busybox ==="
		/boot/home/sys_compat_run /boot/home/busybox ls -l /boot/home/busybox
		echo "LSLFILE_RC=$?"
		echo "=== status after ls -l ==="
		cat /dev/misc/sys_compat 2>&1
	fi
} > "$OUT" 2>&1
echo "=== stat.out ==="
cat "$OUT"
curl -s -X POST --data-binary @"$OUT" "$HOST/results/stat_out.txt" || true
if [ -f /boot/home/boot_stat.log ]; then
	curl -s -X POST --data-binary @/boot/home/boot_stat.log "$HOST/results/boot_stat.log" || true
fi
echo RUN_STAT_DONE
