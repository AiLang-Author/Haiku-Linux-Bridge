#!/bin/sh
# Pull Haiku kernel/user syslog after a reset. License: CC0
set -x
HOST="http://10.0.2.2:8083"
echo "=== log dirs ==="
ls -la /var/log /boot/system/var/log /boot/home/config/var/log 2>&1 | head -80
echo "=== previous_syslog ==="
for f in /var/log/previous_syslog /boot/system/var/log/previous_syslog \
	/var/log/syslog /boot/system/var/log/syslog \
	/var/log/syslog.old /boot/system/var/log/syslog.old; do
	if [ -f "$f" ]; then
		echo "----- $f size=$(wc -c < "$f") -----"
		base=$(echo "$f" | tr / _)
		curl -s -X POST --data-binary @"$f" "$HOST/results/syslog$base" || true
	fi
done
# tail of live syslog for a quick look
echo "=== syslog tail ==="
tail -c 20000 /var/log/syslog 2>/dev/null || tail -c 20000 /boot/system/var/log/syslog 2>/dev/null || true
echo SYSLOG_DUMP_DONE
curl -s -X POST --data-binary "SYSLOG_DUMP_DONE" "$HOST/results/syslog_dump_done.txt" || true
