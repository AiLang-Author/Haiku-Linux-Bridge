#!/bin/sh
# Run Linux execve probe. Expect hello_min text, not EXECFAIL.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
OUT=/tmp/exec.out
{
	echo "=== status ==="
	cat /dev/misc/sys_compat 2>&1
	echo "=== hello_exec ==="
	/boot/home/sys_compat_run /boot/home/hello_exec
	echo EXEC_RC=$?
	echo "=== status after ==="
	cat /dev/misc/sys_compat 2>&1
} > "$OUT" 2>&1
echo "=== exec.out ==="
cat "$OUT"
curl -s -X POST --data-binary @"$OUT" "$HOST/results/exec_out.txt" || true
echo RUN_EXEC_DONE
