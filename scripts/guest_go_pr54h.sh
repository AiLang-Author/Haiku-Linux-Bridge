#!/bin/sh
# PR54h: 4095MB arena (54 x 64MB import + compile maps).
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
printf LEAVEABI > /dev/misc/sys_compat 2>/dev/null || true
SRC=/boot/home/src
mkdir -p "$SRC"
cd "$SRC"
curl -s -o sys_compat_run.c "$HOST/src/sys_compat_run_pr54h.c"
grep -n '4095u' sys_compat_run.c || echo 'NO_ARENA4095'
gcc -O2 sys_compat_run.c -o /boot/home/sys_compat_run
chmod 755 /boot/home/sys_compat_run
cd /boot/home
echo GO_PR54H_BUILT | tee /tmp/go_pr54h_built.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_pr54h_built.txt "$HOST/results/go_pr54h_built.txt" || true
echo "=== PR54h 4095MB arena + self-compile ==="
/boot/home/sys_compat_run /boot/home/ailang.x /boot/home/ailang_cli.ailang /boot/home/ailang_new.x
echo SELFCC_RC=$?
ls -l /boot/home/ailang_new.x 2>/dev/null || echo NO_AILANG_NEW
echo GO_PR54H_DONE | tee /tmp/go_pr54h_done.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_pr54h_done.txt "$HOST/results/go_pr54h_done.txt" || true
echo GO_PR54H_DONE
