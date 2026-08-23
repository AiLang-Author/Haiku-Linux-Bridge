#!/bin/sh
# clone3 + SETTLS + trampoline call fn(arg). Expect CLONE3FNOK.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
OUT=/tmp/clone3fn.out
{
	echo "=== status ==="
	cat /dev/misc/sys_compat 2>&1
	echo "=== hello_clone3fn ==="
	/boot/home/sys_compat_run /boot/home/hello_clone3fn
	echo CLONE3FN_RC=$?
	echo "=== status after ==="
	cat /dev/misc/sys_compat 2>&1
} > "$OUT" 2>&1
echo "=== clone3fn.out ==="
cat "$OUT"
curl -s --max-time 8 -X POST --data-binary @"$OUT" "$HOST/results/clone3fn_out.txt" || true
echo RUN_CLONE3FN_DONE
