#!/bin/sh
# Run hello_min then fork probe.
# Day 14: sys_compat_run returns after Haiku-side fork when the path
# contains "fork" (HAIKU_FORK_OK). Flip that return off to test Linux
# clone again. Expect PRE, HAIKU_FORK_OK, or a KDL — not a silent reset.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
OUT=/tmp/fork.out
{
	echo "=== status ==="
	cat /dev/misc/sys_compat 2>&1
	echo "=== hello_min ==="
	/boot/home/sys_compat_run /boot/home/hello_min
	echo HELLO_RC=$?
	echo "=== hello_fork_probe ==="
	/boot/home/sys_compat_run /boot/home/hello_fork_probe
	echo PROBE_RC=$?
	echo "=== status after ==="
	cat /dev/misc/sys_compat 2>&1
} > "$OUT" 2>&1
echo "=== fork.out ==="
cat "$OUT"
curl -s -X POST --data-binary @"$OUT" "$HOST/results/fork_out.txt" || true
echo RUN_FORK_DONE
