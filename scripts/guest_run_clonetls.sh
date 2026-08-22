#!/bin/sh
# Run clone SETTLS+CLEARTID probe. Expect CLONETLSOK. Keep FORKOK/CLONEEXOK.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
OUT=/tmp/clonetls.out
{
	echo "=== status ==="
	cat /dev/misc/sys_compat 2>&1
	echo "=== hello_fork ==="
	/boot/home/sys_compat_run /boot/home/hello_fork
	echo FORK_RC=$?
	echo "=== hello_clonevm ==="
	/boot/home/sys_compat_run /boot/home/hello_clonevm
	echo CLONEVM_RC=$?
	echo "=== hello_clonetls ==="
	/boot/home/sys_compat_run /boot/home/hello_clonetls
	echo CLONETLS_RC=$?
	echo "=== status after ==="
	cat /dev/misc/sys_compat 2>&1
} > "$OUT" 2>&1
echo "=== clonetls.out ==="
cat "$OUT"
curl -s --max-time 8 -X POST --data-binary @"$OUT" "$HOST/results/clonetls_out.txt" || true
echo RUN_CLONETLS_DONE
