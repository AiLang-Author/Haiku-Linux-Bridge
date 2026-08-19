#!/bin/sh
# Rebuild sys_compat_run (PR38: rdx=0 after mark) and re-run stdio.
# Kernel addon still PR37 until reboot — loader xor is enough.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
SRC=/boot/home/src
mkdir -p "$SRC"
curl -s -o "$SRC/sys_compat_run.c" "$HOST/src/sys_compat_run.c"
curl -s -o "$SRC/sys_compat_abi.h" "$HOST/src/sys_compat_abi.h"
gcc -O2 "$SRC/sys_compat_run.c" -o /boot/home/sys_compat_run
chmod 755 /boot/home/sys_compat_run
grep -n 'xor %%edx' "$SRC/sys_compat_run.c" || echo 'NO_XOR_EDX'
RUN=/boot/home/sys_compat_run
BB=/boot/home/busybox
for f in hello_printf hello_clock hello_wr hello_exit; do
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
	echo "=== wr ==="
	$RUN /boot/home/hello_wr
	echo WR_RC=$?
	echo "=== bbprintf ==="
	$RUN $BB printf '%s\n' BBPRINTF_OK
	echo BBPRINTF_RC=$?
	echo "=== date ==="
	$RUN $BB date -u
	echo DATE_RC=$?
	echo "=== echo ==="
	$RUN $BB echo ECHO_OK
	echo ECHO_RC=$?
} > /tmp/stdio.out 2>&1
cat /tmp/stdio.out
curl -s --max-time 8 -X POST --data-binary @/tmp/stdio.out "$HOST/results/stdio_out.txt" || true
echo RUN_STDIO_DONE
