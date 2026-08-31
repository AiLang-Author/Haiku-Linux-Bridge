#!/bin/sh
# PR54f: recycle ANON mmap via free-list; compile ailang_cli.ailang on Haiku.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
hey -o debug_server quit of Window "Crashed program" 2>/dev/null || true
hey -o debug_server quit of Window 0 2>/dev/null || true
printf LEAVEABI > /dev/misc/sys_compat 2>/dev/null || true
SRC=/boot/home/src
mkdir -p "$SRC"
cd "$SRC"
curl -s -o sys_compat_dev.cpp "$HOST/src/sys_compat_dev_pr54f.cpp"
curl -s -o syscall_hook.S "$HOST/src/syscall_hook_pr54f.S"
curl -s -o sys_compat_run.c "$HOST/src/sys_compat_run_pr54f.c"
for f in sys_compat_abi.h Makefile.driver; do
	curl -s -o "$f" "$HOST/src/$f"
done
grep -n 'PR54f' sys_compat_dev.cpp || echo 'NO_PR54F'
grep -n 'anon_recycle' sys_compat_dev.cpp || echo 'NO_RECYCLE'
grep -n '2048u' sys_compat_run.c || echo 'NO_ARENA2G'
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
curl -s -o /boot/home/ailang.x "$HOST/payload/ailang/ailang.x"
curl -s -o /boot/home/compiler_src.tgz "$HOST/payload/ailang/compiler_src.tgz"
chmod 755 /boot/home/ailang.x
tar -tzf /boot/home/compiler_src.tgz | head -5
tar -xzf /boot/home/compiler_src.tgz
ls -l /boot/home/ailang_cli.ailang /boot/home/Librarys/Library.Arena.ailang
echo GO_PR54F_BUILT | tee /tmp/go_pr54f_built.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_pr54f_built.txt "$HOST/results/go_pr54f_built.txt" || true
echo "=== PR54f recycle mmap + self-compile ailang_cli.ailang ==="
/boot/home/sys_compat_run /boot/home/ailang.x /boot/home/ailang_cli.ailang /boot/home/ailang_new.x
echo SELFCC_RC=$?
ls -l /boot/home/ailang_new.x 2>/dev/null || echo NO_AILANG_NEW
echo GO_PR54F_DONE | tee /tmp/go_pr54f_done.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_pr54f_done.txt "$HOST/results/go_pr54f_done.txt" || true
echo GO_PR54F_DONE
