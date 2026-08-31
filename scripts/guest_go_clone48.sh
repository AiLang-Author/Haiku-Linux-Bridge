#!/bin/sh
# PR48: Linux exit(60) is thread_exit when the team still has threads.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
printf LEAVEABI > /dev/misc/sys_compat 2>/dev/null || true
SRC=/boot/home/src
mkdir -p "$SRC"
cd "$SRC"
curl -s -o sys_compat_dev.cpp "$HOST/src/sys_compat_dev_pr48.cpp"
curl -s -o syscall_hook.S "$HOST/src/syscall_hook_pr48.S"
for f in sys_compat_abi.h sys_compat_run.c Makefile.driver; do
	curl -s -o "$f" "$HOST/src/$f"
done
grep -n 'PR48' sys_compat_dev.cpp || echo 'NO_PR48'
grep -n 'exit60' syscall_hook.S || echo 'NO_EXIT60'
rm -rf objects.* *.o objects 2>/dev/null || true
make -f Makefile.driver clean || true
make -f Makefile.driver || { echo MAKE_FAILED; exit 1; }
make -f Makefile.driver driverinstall || { echo INSTALL_FAILED; exit 1; }
USERBIN=/boot/home/config/non-packaged/add-ons/kernel/drivers/bin/sys_compat
USERDEV=/boot/home/config/non-packaged/add-ons/kernel/drivers/dev/misc/sys_compat
BUILT=$(ls -t objects.*/sys_compat 2>/dev/null | head -1)
mkdir -p "$(dirname "$USERBIN")" "$(dirname "$USERDEV")"
if [ -n "$BUILT" ] && [ -f "$BUILT" ]; then
	cp -f "$BUILT" "$USERBIN"
fi
ln -sfn "$USERBIN" "$USERDEV"
rm -f /boot/system/non-packaged/add-ons/kernel/drivers/bin/sys_compat \
	/boot/system/non-packaged/add-ons/kernel/drivers/dev/misc/sys_compat 2>/dev/null || true
gcc -O2 sys_compat_run.c -o /boot/home/sys_compat_run
chmod 755 /boot/home/sys_compat_run
curl -s -o /boot/home/hello_fork "$HOST/payload/tests/hello_fork"
curl -s -o /boot/home/hello_clonevm "$HOST/payload/tests/hello_clonevm"
curl -s -o /boot/home/run_clonevm.sh "$HOST/scripts/guest_run_clonevm.sh"
chmod 755 /boot/home/hello_fork /boot/home/hello_clonevm /boot/home/run_clonevm.sh
echo GO_CLONE48_BUILT | tee /tmp/go_clone48_built.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_clone48_built.txt "$HOST/results/go_clone48_built.txt" || true
sh /boot/home/run_clonevm.sh
echo GO_CLONE48_DONE | tee /tmp/go_clone48_done.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_clone48_done.txt "$HOST/results/go_clone48_done.txt" || true
echo GO_CLONE48_DONE
