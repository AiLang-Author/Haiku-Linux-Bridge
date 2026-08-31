#!/bin/sh
# PR52: pthread_create flags (FS|FILES|SIGHAND|SYSVSEM); THREAD requires SIGHAND.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
hey -o debug_server quit of Window "Crashed program" 2>/dev/null || true
hey -o debug_server quit of Window 0 2>/dev/null || true
printf LEAVEABI > /dev/misc/sys_compat 2>/dev/null || true
SRC=/boot/home/src
mkdir -p "$SRC"
cd "$SRC"
curl -s -o sys_compat_dev.cpp "$HOST/src/sys_compat_dev_pr52.cpp"
curl -s -o syscall_hook.S "$HOST/src/syscall_hook_pr52.S"
for f in sys_compat_abi.h sys_compat_run.c Makefile.driver; do
	curl -s -o "$f" "$HOST/src/$f"
done
grep -n 'PR52' sys_compat_dev.cpp || echo 'NO_PR52'
grep -n 'LINUX_CLONE_SIGHAND' sys_compat_dev.cpp || echo 'NO_SIGHAND'
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
curl -s -o /boot/home/hello_clonetls "$HOST/payload/tests/hello_clonetls"
curl -s -o /boot/home/hello_clonethr "$HOST/payload/tests/hello_clonethr52"
curl -s -o /boot/home/hello_clonept "$HOST/payload/tests/hello_clonept"
curl -s -o /boot/home/run_clonept.sh "$HOST/scripts/guest_run_clonept.sh"
chmod 755 /boot/home/hello_fork /boot/home/hello_clonevm /boot/home/hello_clonetls /boot/home/hello_clonethr /boot/home/hello_clonept /boot/home/run_clonept.sh
echo GO_CLONE52_BUILT | tee /tmp/go_clone52_built.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_clone52_built.txt "$HOST/results/go_clone52_built.txt" || true
sh /boot/home/run_clonept.sh
echo GO_CLONE52_DONE | tee /tmp/go_clone52_done.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_clone52_done.txt "$HOST/results/go_clone52_done.txt" || true
echo GO_CLONE52_DONE
