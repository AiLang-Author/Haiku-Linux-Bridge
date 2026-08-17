#!/bin/sh
# PR3: setpgid stub + /proc/meminfo + wstat/mmap/pipe.
# License: Public Domain / CC0 1.0 Universal
set -x
hey -o application/x-vnd.Haiku-debug_server quit of Window "Crashed program" 2>/dev/null || true
hey -o debug_server quit of Window 0 2>/dev/null || true
HOST="http://10.0.2.2:8083"
OUT=/tmp/next.out
RUN=/boot/home/sys_compat_run
BB=/boot/home/busybox
if [ ! -x /boot/home/hello_mmapf ]; then
	curl -s -o /boot/home/hello_mmapf "$HOST/tests/hello_mmapf"
	chmod 755 /boot/home/hello_mmapf
fi
if [ ! -x /boot/home/hello_wstat ]; then
	curl -s -o /boot/home/hello_wstat "$HOST/tests/hello_wstat"
	chmod 755 /boot/home/hello_wstat
fi
if [ ! -x /boot/home/ltp/bin/uname01 ]; then
	mkdir -p /boot/home/ltp/bin
	curl -s -o /boot/home/ltp/bin/uname01 "$HOST/payload/ltp/bin/uname01"
	chmod 755 /boot/home/ltp/bin/uname01
fi
{
	echo "=== wstat ==="
	$RUN /boot/home/hello_wstat
	echo WSTAT_RC=$?
	echo "=== mmapf ==="
	$RUN /boot/home/hello_mmapf
	echo MMAPF_RC=$?
	echo "=== pipe ==="
	$RUN $BB sh -c 'echo HI | cat'
	echo PIPE_RC=$?
	echo "=== uname01 ==="
	$RUN /boot/home/ltp/bin/uname01
	echo UNAME_RC=$?
} > "$OUT" 2>&1
cat "$OUT"
curl -s -X POST --data-binary @"$OUT" "$HOST/results/next_out.txt" || true
echo RUN_NEXT_DONE
