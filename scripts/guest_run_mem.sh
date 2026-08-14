#!/bin/sh
# Prove hello_min still works, then hello_mmap (brk/mmap arena).
# Does NOT run busybox (glibc TLS / crash dialogs).
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
OUT=/tmp/mem.out
{
	echo "=== status before ==="
	cat /dev/misc/sys_compat 2>&1 || echo "no device"
	echo "=== hello_min ==="
	/boot/home/sys_compat_run /boot/home/hello_min
	echo "HELLO_RC=$?"
	echo "=== status after hello ==="
	cat /dev/misc/sys_compat 2>&1 || echo "no device"
	echo "=== hello_mmap ==="
	/boot/home/sys_compat_run /boot/home/hello_mmap
	echo "MMAP_RC=$?"
	echo "=== status after mmap ==="
	cat /dev/misc/sys_compat 2>&1 || echo "no device"
} > "$OUT" 2>&1
echo "=== mem.out ==="
cat "$OUT"
curl -s -X POST --data-binary @"$OUT" "$HOST/results/mem_out.txt" || true
echo RUN_MEM_DONE
