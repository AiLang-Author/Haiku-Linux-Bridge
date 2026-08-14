#!/bin/sh
# Run hello_min via the Haiku loader. Safe to run from a Haiku shell:
# the mark is a raw syscall inside sys_compat_run, not this shell.
# Posts /tmp/hello.out back to the host even if the child is killed.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
OUT=/tmp/hello.out
{
	echo "=== status before ==="
	cat /dev/misc/sys_compat 2>&1 || echo "no device"
	echo "=== run ==="
	/boot/home/sys_compat_run /boot/home/hello_min
	echo "DONE_RC=$?"
	echo "=== status after ==="
	cat /dev/misc/sys_compat 2>&1 || echo "no device"
} > "$OUT" 2>&1
echo "=== hello.out ==="
cat "$OUT"
curl -s -X POST --data-binary @"$OUT" "$HOST/results/hello_out.txt" || true
echo RUN_HELLO_DONE
