#!/bin/sh
# Run Linux file-mmap probe. Expect MMAPFOK.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
OUT=/tmp/mmapf.out
{
	echo "=== status ==="
	cat /dev/misc/sys_compat 2>&1
	echo "=== hello_mmapf ==="
	/boot/home/sys_compat_run /boot/home/hello_mmapf
	echo MMAPF_RC=$?
	echo "=== status after ==="
	cat /dev/misc/sys_compat 2>&1
} > "$OUT" 2>&1
echo "=== mmapf.out ==="
cat "$OUT"
curl -s -X POST --data-binary @"$OUT" "$HOST/results/mmapf_out.txt" || true
echo RUN_MMAPF_DONE
