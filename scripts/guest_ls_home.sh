#!/bin/sh
# List /boot/home and POST it. License: Public Domain / CC0
set -x
HOST="http://10.0.2.2:8083"
ls -l /boot/home > /tmp/homels.txt
ls -l /boot/home/*.report >> /tmp/homels.txt 2>/dev/null || true
curl -s --max-time 8 -X POST --data-binary @/tmp/homels.txt "$HOST/results/homels.txt" || true
echo LS_HOME_DONE
