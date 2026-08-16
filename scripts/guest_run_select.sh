#!/bin/sh
# Run Linux select probe. Expect SELECTOK.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
OUT=/tmp/select.out
{
	echo "=== status ==="
	cat /dev/misc/sys_compat 2>&1
	echo "=== hello_select ==="
	/boot/home/sys_compat_run /boot/home/hello_select
	echo SELECT_RC=$?
	echo "=== status after ==="
	cat /dev/misc/sys_compat 2>&1
} > "$OUT" 2>&1
echo "=== select.out ==="
cat "$OUT"
curl -s -X POST --data-binary @"$OUT" "$HOST/results/select_out.txt" || true
echo RUN_SELECT_DONE
