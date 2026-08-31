#!/bin/sh
# POST newest debug reports from /boot/home to the host.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
ls -l /boot/home/*.report /boot/home/*.report.txt 2>/dev/null || true
n=1
for f in /boot/home/sys_compat_run*.report /boot/home/bash-*.report; do
	if [ -f "$f" ]; then
		bn=$(basename "$f")
		echo "POST $bn"
		curl -s --max-time 8 -X POST --data-binary @"$f" "$HOST/results/$bn" || true
		n=$((n+1))
	fi
done
echo FETCH_REPORT_DONE
