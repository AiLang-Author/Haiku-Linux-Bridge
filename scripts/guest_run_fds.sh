#!/bin/sh
# Prove Linux open/lseek/openat/creat via hello_fds.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
OUT=/tmp/fds.out
printf 'ABCDEFGHIJ' > /tmp/opentest
rm -f /tmp/created
{
	echo "=== flags ==="
	if [ -x /tmp/dump_flags ]; then
		/tmp/dump_flags
	fi
	echo "=== status before ==="
	cat /dev/misc/sys_compat 2>&1 || echo "no device"
	echo "=== run ==="
	/boot/home/sys_compat_run /boot/home/hello_fds
	echo "DONE_RC=$?"
	echo "=== created ==="
	ls -l /tmp/created 2>&1
	cat /tmp/created 2>&1
	echo "=== status after ==="
	cat /dev/misc/sys_compat 2>&1 || echo "no device"
} > "$OUT" 2>&1
echo "=== fds.out ==="
cat "$OUT"
curl -s -X POST --data-binary @"$OUT" "$HOST/results/fds_out.txt" || true
echo RUN_FDS_DONE
