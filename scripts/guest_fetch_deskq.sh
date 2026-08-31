#!/bin/sh
# POST Desktop + home debug reports. Unique name (Haiku curl cache).
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
ls -l /boot/home/Desktop > /tmp/deskls.txt
ls -l /boot/home/*.report /boot/home/Desktop/*.report >> /tmp/deskls.txt 2>/dev/null || true
curl -s --max-time 8 -X POST --data-binary @/tmp/deskls.txt "$HOST/results/deskls_q.txt" || true
n=1
for f in /boot/home/Desktop/*.report /boot/home/*.report; do
	if [ -f "$f" ]; then
		bn=$(basename "$f")
		echo "POST $bn"
		curl -s --max-time 8 -X POST --data-binary @"$f" "$HOST/results/deskq_${n}_${bn}" || true
		n=$((n+1))
	fi
done
echo FETCH_DESKQ_DONE | tee /tmp/fetch_deskq_done.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/fetch_deskq_done.txt "$HOST/results/fetch_deskq_done.txt" || true
echo FETCH_DESKQ_DONE
