#!/bin/sh
# Prove hello_min, hello_util, then real Linux busybox sysutils.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
OUT=/tmp/util.out
RUNNER=/boot/home/sys_compat_run
BB=/boot/home/busybox
{
	echo "=== status before ==="
	cat /dev/misc/sys_compat 2>&1
	echo "=== hello_min ==="
	$RUNNER /boot/home/hello_min
	echo HELLO_RC=$?
	echo "=== hello_util ==="
	$RUNNER /boot/home/hello_util
	echo UTIL_RC=$?
	echo "=== busybox echo/uname/ls ==="
	$RUNNER $BB echo UTIL_ECHO
	echo ECHO_RC=$?
	$RUNNER $BB uname -a
	echo UNAME_RC=$?
	$RUNNER $BB ls /tmp
	echo LS_RC=$?
	echo "=== busybox cp/mv/ln/readlink/touch/rm ==="
	echo src > /tmp/bb_src.txt
	$RUNNER $BB cp /tmp/bb_src.txt /tmp/bb_cp.txt
	echo CP_RC=$?
	$RUNNER $BB mv /tmp/bb_cp.txt /tmp/bb_mv.txt
	echo MV_RC=$?
	$RUNNER $BB ln -s /tmp/bb_src.txt /tmp/bb_ln.txt
	echo LN_RC=$?
	$RUNNER $BB readlink /tmp/bb_ln.txt
	echo READLINK_RC=$?
	$RUNNER $BB touch /tmp/bb_touch.txt
	echo TOUCH_RC=$?
	$RUNNER $BB cat /tmp/bb_mv.txt
	echo CAT_RC=$?
	$RUNNER $BB date
	echo DATE_RC=$?
	$RUNNER $BB rm /tmp/bb_src.txt /tmp/bb_mv.txt /tmp/bb_ln.txt /tmp/bb_touch.txt
	echo RM_RC=$?
	echo "=== status after ==="
	cat /dev/misc/sys_compat 2>&1
} > "$OUT" 2>&1
echo "=== util.out ==="
cat "$OUT"
curl -s -X POST --data-binary @"$OUT" "$HOST/results/util_out.txt" || true
echo RUN_UTIL_DONE
