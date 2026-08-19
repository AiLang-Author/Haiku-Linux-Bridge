#!/bin/sh
# Guest: stdio vs clock vs date.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
RUN=/boot/home/sys_compat_run
BB=/boot/home/busybox
for f in hello_printf hello_clock; do
	curl -s -o /boot/home/$f "$HOST/payload/tests/$f"
	chmod 755 /boot/home/$f
done
{
	echo "=== printf ==="
	$RUN /boot/home/hello_printf
	echo PRINTF_RC=$?
	echo "=== clock ==="
	$RUN /boot/home/hello_clock
	echo CLOCK_RC=$?
	echo "=== bbprintf ==="
	$RUN $BB printf '%s\n' BBPRINTF_OK
	echo BBPRINTF_RC=$?
	echo "=== date ==="
	$RUN $BB date -u
	echo DATE_RC=$?
} > /tmp/stdio.out 2>&1
cat /tmp/stdio.out
curl -s --max-time 8 -X POST --data-binary @/tmp/stdio.out "$HOST/results/stdio_out.txt" || true
echo RUN_STDIO_DONE
