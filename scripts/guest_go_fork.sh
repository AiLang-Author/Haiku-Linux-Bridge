#!/bin/sh
# Install try_fork diagnostic driver. No UserBootscript.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
printf LEAVEABI > /dev/misc/sys_compat 2>/dev/null || true
SRC=/boot/home/src
mkdir -p "$SRC"
cd "$SRC"
for f in sys_compat_dev.cpp syscall_hook.S sys_compat_abi.h sys_compat_run.c Makefile.driver; do
	curl -s -o "$f" "$HOST/src/$f"
done
curl -s -o /boot/home/hello_min "$HOST/payload/tests/hello_min"
curl -s -o /boot/home/hello_fork_probe "$HOST/tests/hello_fork_probe"
curl -s -o /boot/home/run_fork.sh "$HOST/scripts/guest_run_fork.sh"
chmod 755 /boot/home/hello_min /boot/home/hello_fork_probe /boot/home/run_fork.sh
make -f Makefile.driver clean || true
make -f Makefile.driver || { echo MAKE_FAILED; exit 1; }
make -f Makefile.driver driverinstall || { echo INSTALL_FAILED; exit 1; }
gcc -O2 sys_compat_run.c -o /boot/home/sys_compat_run
chmod 755 /boot/home/sys_compat_run
echo GO_FORK_DONE | tee /tmp/go_fork_done.txt
curl -s -X POST --data-binary @/tmp/go_fork_done.txt "$HOST/results/go_fork_done.txt" || true
echo GO_FORK_DONE
