#!/bin/sh
# Guest: Linux /dev/fb0 onto Haiku VESA. Run: sh /boot/home/run_fb.sh
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
RUN=/boot/home/sys_compat_run
curl -s -o /boot/home/hello_fb "$HOST/payload/tests/hello_fb"
chmod 755 /boot/home/hello_fb
{
	echo "=== fb ==="
	$RUN /boot/home/hello_fb
	echo FB_RC=$?
	echo "=== date still ==="
	$RUN /boot/home/busybox date -u
	echo DATE_RC=$?
} > /tmp/fb.out 2>&1
cat /tmp/fb.out
curl -s --max-time 8 -X POST --data-binary @/tmp/fb.out "$HOST/results/fb_out.txt" || true
echo RUN_FB_DONE
