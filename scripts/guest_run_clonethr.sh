#!/bin/sh
# Run clone THREAD+SETTLS+CLEARTID. Expect CLONETHROK. Keep FORKOK/CLONEEXOK/CLONETLSOK.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
OUT=/tmp/clonethr.out
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
	echo "=== hello_clonethr ==="
	/boot/home/sys_compat_run /boot/home/hello_clonethr
	echo CLONETHR_RC=$?
	echo "=== status after ==="
	cat /dev/misc/sys_compat 2>&1
} > "$OUT" 2>&1
echo "=== clonethr.out ==="
cat "$OUT"
curl -s --max-time 8 -X POST --data-binary @"$OUT" "$HOST/results/clonethr_out.txt" || true
echo RUN_CLONETHR_DONE
