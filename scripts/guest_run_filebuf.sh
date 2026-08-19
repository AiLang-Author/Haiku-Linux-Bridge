#!/bin/sh
# After PR38 rdx=0: FILE* applets on a Haiku redirect.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
RUN=/boot/home/sys_compat_run
BB=/boot/home/busybox
printf 'punch\n' > /tmp/punch.txt
{
	echo "=== date ==="
	$RUN $BB date -u
	echo DATE_RC=$?
	echo "=== md5 ==="
	$RUN $BB md5sum /tmp/punch.txt
	echo MD5_RC=$?
	echo "=== nproc ==="
	$RUN $BB nproc
	echo NPROC_RC=$?
	echo "=== false ==="
	$RUN $BB false
	echo FALSE_RC=$?
	echo "=== cmp ==="
	$RUN $BB cmp /tmp/punch.txt /boot/home/hello_wr
	echo CMP_RC=$?
} > /tmp/filebuf.out 2>&1
cat /tmp/filebuf.out
curl -s --max-time 8 -X POST --data-binary @/tmp/filebuf.out "$HOST/results/filebuf_out.txt" || true
echo RUN_FILEBUF_DONE
