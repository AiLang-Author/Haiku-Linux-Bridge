#!/bin/sh
# Extra static busybox applets + identity. No shell spawn.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
OUT=/tmp/more.out
RUN=/boot/home/sys_compat_run
BB=/boot/home/busybox
if [ ! -x "$BB" ]; then
	curl -s -o "$BB" "$HOST/payload/tests/busybox"
	chmod 755 "$BB"
fi
{
	echo "=== more tools $(date) ==="
	cat /dev/misc/sys_compat 2>&1
	echo "=== id pwd true false ==="
	$RUN $BB id; echo ID_RC=$?
	$RUN $BB pwd; echo PWD_RC=$?
	$RUN $BB true; echo TRUE_RC=$?
	$RUN $BB false; echo FALSE_RC=$?
	echo "=== printf dirname basename ==="
	$RUN $BB printf 'MOREOK\n'; echo PRINTF_RC=$?
	$RUN $BB dirname /boot/home/busybox; echo DIRNAME_RC=$?
	$RUN $BB basename /boot/home/busybox; echo BASENAME_RC=$?
	echo "=== od ==="
	echo abc | $RUN $BB od -An -tx1; echo OD_RC=$?
	echo "=== hello_min ==="
	$RUN /boot/home/hello_min; echo HELLO_RC=$?
	echo "=== status after ==="
	cat /dev/misc/sys_compat 2>&1
} > "$OUT" 2>&1
echo "=== more.out ==="
cat "$OUT"
curl -s -X POST --data-binary @"$OUT" "$HOST/results/more_out.txt" || true
echo RUN_MORE_DONE
