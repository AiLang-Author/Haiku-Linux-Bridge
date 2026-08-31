#!/bin/sh
# PR54n: 5.5GB arena. Driver PR54k recycle already loaded.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
SRC=/boot/home/src
mkdir -p "$SRC"
cd "$SRC"
curl -s -o sys_compat_run.c "$HOST/src/sys_compat_run_pr54n.c"
grep -n '5600ull' sys_compat_run.c || echo 'NO_ARENA55'
gcc -O2 sys_compat_run.c -o /boot/home/sys_compat_run
chmod 755 /boot/home/sys_compat_run
cd /boot/home
echo GO_PR54N_BUILT | tee /tmp/go_pr54n_built.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_pr54n_built.txt "$HOST/results/go_pr54n_built.txt" || true
echo "=== PR54n 5.5GB arena self-compile ==="
/boot/home/sys_compat_run /boot/home/ailang.x /boot/home/ailang_cli.ailang /boot/home/ailang_new.x
echo SELFCC_RC=$?
ls -l /boot/home/ailang_new.x 2>/dev/null || echo NO_AILANG_NEW
echo GO_PR54N_DONE | tee /tmp/go_pr54n_done.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_pr54n_done.txt "$HOST/results/go_pr54n_done.txt" || true
echo GO_PR54N_DONE
