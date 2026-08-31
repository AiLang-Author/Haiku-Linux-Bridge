#!/bin/sh
# PR54p compile-only after reboot (64MB import maps capped at 4MB).
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
cd /boot/home
echo GO_PR54PCC_GO | tee /tmp/go_pr54pcc_go.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_pr54pcc_go.txt "$HOST/results/go_pr54pcc_go.txt" || true
/boot/home/sys_compat_run /boot/home/ailang.x /boot/home/ailang_cli.ailang /boot/home/ailang_new.x
echo SELFCC_RC=$?
ls -l /boot/home/ailang_new.x 2>/dev/null || echo NO_AILANG_NEW
echo GO_PR54PCC_DONE | tee /tmp/go_pr54pcc_done.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_pr54pcc_done.txt "$HOST/results/go_pr54pcc_done.txt" || true
echo GO_PR54PCC_DONE
