#!/bin/sh
# Rebuild sys_compat_run only (trap already PR33). Then status.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
curl -s -o /boot/home/src/sys_compat_run.c "$HOST/src/sys_compat_run.c"
gcc -O2 /boot/home/src/sys_compat_run.c -o /boot/home/sys_compat_run
curl -s -o /boot/home/hello_exit "$HOST/payload/tests/hello_exit"
chmod 755 /boot/home/sys_compat_run /boot/home/hello_exit
curl -s -o /boot/home/run_status.sh "$HOST/scripts/guest_run_status.sh"
sh /boot/home/run_status.sh
echo REBUILD_RUN_DONE
