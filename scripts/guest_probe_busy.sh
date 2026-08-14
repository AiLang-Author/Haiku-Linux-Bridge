#!/bin/sh
# Probe static busybox under sys_compat. Posts device counters + output.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
OUT=/tmp/busy.out
curl -s -o /boot/home/busybox "$HOST/payload/tests/busybox"
chmod 755 /boot/home/busybox
{
	echo "=== status before ==="
	cat /dev/misc/sys_compat 2>&1
	echo "=== file ==="
	ls -l /boot/home/busybox /boot/home/sys_compat_run
	echo "=== echo ==="
	/boot/home/sys_compat_run /boot/home/busybox echo BUSYBOX_ECHO
	echo "ECHO_RC=$?"
	echo "=== status after echo ==="
	cat /dev/misc/sys_compat 2>&1
	echo "=== uname ==="
	/boot/home/sys_compat_run /boot/home/busybox uname -a
	echo "UNAME_RC=$?"
	echo "=== status after uname ==="
	cat /dev/misc/sys_compat 2>&1
	echo "=== hello_min regression ==="
	/boot/home/sys_compat_run /boot/home/hello_min
	echo "HELLO_RC=$?"
	echo "=== status after hello ==="
	cat /dev/misc/sys_compat 2>&1
} > "$OUT" 2>&1
echo "=== busy.out ==="
cat "$OUT"
curl -s -X POST --data-binary @"$OUT" "$HOST/results/busy_out.txt" || true
echo PROBE_BUSY_DONE
