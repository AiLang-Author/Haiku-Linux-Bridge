#!/bin/sh
# MM1: vm_map_file mmap + pipe regression.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
OUT=/tmp/next.out
RUN=/boot/home/sys_compat_run
BB=/boot/home/busybox
if [ ! -x /boot/home/hello_mmapf ]; then
	curl -s -o /boot/home/hello_mmapf "$HOST/tests/hello_mmapf"
	chmod 755 /boot/home/hello_mmapf
fi
{
	echo "=== mmapf ==="
	$RUN /boot/home/hello_mmapf
	echo MMAPF_RC=$?
	echo "=== pipe ==="
	$RUN $BB sh -c 'echo HI | cat'
	echo PIPE_RC=$?
} > "$OUT" 2>&1
cat "$OUT"
curl -s -X POST --data-binary @"$OUT" "$HOST/results/next_out.txt" || true
echo RUN_NEXT_DONE
