#!/bin/sh
# PR54i compile-only after reboot (new driver already on disk).
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
printf LEAVEABI > /dev/misc/sys_compat 2>/dev/null || true
cd /boot/home
echo GO_PR54ICC_BUILT | tee /tmp/go_pr54icc_built.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_pr54icc_built.txt "$HOST/results/go_pr54icc_built.txt" || true
echo "=== PR54i self-compile ==="
/boot/home/sys_compat_run /boot/home/ailang.x /boot/home/ailang_cli.ailang /boot/home/ailang_new.x
echo SELFCC_RC=$?
ls -l /boot/home/ailang_new.x 2>/dev/null || echo NO_AILANG_NEW
echo GO_PR54ICC_DONE | tee /tmp/go_pr54icc_done.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_pr54icc_done.txt "$HOST/results/go_pr54icc_done.txt" || true
echo GO_PR54ICC_DONE
