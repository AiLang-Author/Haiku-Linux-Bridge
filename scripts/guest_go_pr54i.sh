#!/bin/sh
# PR54i: large ANON via create_area_etc; 768MB small carve; self-compile.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
printf LEAVEABI > /dev/misc/sys_compat 2>/dev/null || true
SRC=/boot/home/src
mkdir -p "$SRC"
cd "$SRC"
curl -s -o sys_compat_dev.cpp "$HOST/src/sys_compat_dev_pr54i.cpp"
curl -s -o syscall_hook.S "$HOST/src/syscall_hook_pr54i.S"
curl -s -o sys_compat_run.c "$HOST/src/sys_compat_run_pr54i.c"
for f in sys_compat_abi.h Makefile.driver; do
	curl -s -o "$f" "$HOST/src/$f"
done
grep -n 'PR54i' sys_compat_dev.cpp || echo 'NO_PR54I'
grep -n 'mmap_anon_haiku' sys_compat_dev.cpp || echo 'NO_HAIKU_ANON'
grep -n '768u' sys_compat_run.c || echo 'NO_ARENA768'
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
cd /boot/home
echo GO_PR54I_BUILT | tee /tmp/go_pr54i_built.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_pr54i_built.txt "$HOST/results/go_pr54i_built.txt" || true
echo GO_PR54I_BUILT
# Driver is still the old in-memory image until reboot. Do not compile yet.
