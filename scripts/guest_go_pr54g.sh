#!/bin/sh
# PR54g: 3.5GB arena (64MB/module Import_ReadFile); self-compile on Haiku.
# Driver stays PR54f recycle. Only rebuild sys_compat_run.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
hey -o debug_server quit of Window "Crashed program" 2>/dev/null || true
hey -o debug_server quit of Window 0 2>/dev/null || true
printf LEAVEABI > /dev/misc/sys_compat 2>/dev/null || true
SRC=/boot/home/src
mkdir -p "$SRC"
cd "$SRC"
curl -s -o sys_compat_run.c "$HOST/src/sys_compat_run_pr54g.c"
grep -n '3584u' sys_compat_run.c || echo 'NO_ARENA35'
gcc -O2 sys_compat_run.c -o /boot/home/sys_compat_run
chmod 755 /boot/home/sys_compat_run
cd /boot/home
echo GO_PR54G_BUILT | tee /tmp/go_pr54g_built.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_pr54g_built.txt "$HOST/results/go_pr54g_built.txt" || true
echo "=== PR54g 3.5GB arena + self-compile ailang_cli.ailang ==="
/boot/home/sys_compat_run /boot/home/ailang.x /boot/home/ailang_cli.ailang /boot/home/ailang_new.x
echo SELFCC_RC=$?
ls -l /boot/home/ailang_new.x 2>/dev/null || echo NO_AILANG_NEW
echo GO_PR54G_DONE | tee /tmp/go_pr54g_done.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_pr54g_done.txt "$HOST/results/go_pr54g_done.txt" || true
echo GO_PR54G_DONE
