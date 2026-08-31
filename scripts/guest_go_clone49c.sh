#!/bin/sh
# PR49c: kser PT/CT/TL and swapgs store of CLEARTID.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
hey -o debug_server quit of Window "Crashed program" 2>/dev/null || true
printf LEAVEABI > /dev/misc/sys_compat 2>/dev/null || true
SRC=/boot/home/src
mkdir -p "$SRC"
cd "$SRC"
curl -s -o sys_compat_dev.cpp "$HOST/src/sys_compat_dev_pr49c.cpp"
curl -s -o syscall_hook.S "$HOST/src/syscall_hook_pr49c.S"
for f in sys_compat_abi.h sys_compat_run.c Makefile.driver; do
	curl -s -o "$f" "$HOST/src/$f"
done
grep -n 'PR49c' sys_compat_dev.cpp || echo 'NO_PR49C'
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
curl -s -o /boot/home/hello_clonetls "$HOST/payload/tests/hello_clonetls"
curl -s -o /boot/home/run_clonetls.sh "$HOST/scripts/guest_run_clonetls.sh"
chmod 755 /boot/home/hello_clonetls /boot/home/run_clonetls.sh
echo GO_CLONE49C_BUILT | tee /tmp/go_clone49c_built.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_clone49c_built.txt "$HOST/results/go_clone49c_built.txt" || true
sh /boot/home/run_clonetls.sh
echo GO_CLONE49C_DONE | tee /tmp/go_clone49c_done.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_clone49c_done.txt "$HOST/results/go_clone49c_done.txt" || true
echo GO_CLONE49C_DONE
