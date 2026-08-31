#!/bin/sh
# H56cd: pull updated Ailang, compile cad_app.x, relaunch Haiku host, --nohost.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
DEST=/boot/home/Ailang-Self-Hosting-
cd /boot/home
echo GO_H56CD_GO | tee /tmp/go_h56cd_go.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_h56cd_go.txt "$HOST/results/go_h56cd_go.txt" || true

export GIT_SSL_NO_VERIFY=1
cd "$DEST" || { echo NO_CLONE; exit 1; }
git -c http.sslVerify=false fetch --depth 1 origin master
git reset --hard origin/master
git log -1 --oneline
git rev-parse HEAD
echo GO_H56CD_PULL | tee /tmp/go_h56cd_pull.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_h56cd_pull.txt "$HOST/results/go_h56cd_pull.txt" || true

mkdir -p test-stl /tmp/cad_app
ls -l test-stl/test-dxf-files/cube.dxf CAD/cad_app.ailang /boot/home/ailang_new.x /boot/home/cad_shell_haiku

echo "=== compile cad_app.ailang ==="
/boot/home/sys_compat_run /boot/home/ailang_new.x CAD/cad_app.ailang /boot/home/cad_app.x
echo CADCC_RC=$?
ls -l /boot/home/cad_app.x 2>/dev/null || echo NO_CAD_APP
echo GO_H56CD_BUILT | tee /tmp/go_h56cd_built.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_h56cd_built.txt "$HOST/results/go_h56cd_built.txt" || true

echo "=== headless cube ==="
/boot/home/sys_compat_run /boot/home/cad_app.x --headless -i test-stl/test-dxf-files/cube.dxf -H 8 -o /tmp/cad_app/cube.bmp
echo HEADLESS_RC=$?
ls -l /tmp/cad_app/cube.bmp test-stl/cad_app.bmp test-stl/cad_app.stp 2>/dev/null
echo GO_H56CD_HEADLESS | tee /tmp/go_h56cd_headless.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_h56cd_headless.txt "$HOST/results/go_h56cd_headless.txt" || true

echo "=== relaunch native host + nohost kernel ==="
rm -f /tmp/cad_app/cmd.txt /tmp/cad_app/frame.raw /tmp/cad_app/gen.txt
/boot/home/cad_shell_haiku /tmp/cad_app &
echo HOSTPID=$!
sleep 1
/boot/home/sys_compat_run /boot/home/cad_app.x --nohost -i test-stl/test-dxf-files/cube.dxf -H 8 &
echo KERNPID=$!

i=0
while [ "$i" -lt 90 ]; do
	if [ -s /tmp/cad_app/frame.raw ] && [ -s /tmp/cad_app/gen.txt ]; then
		echo FRAME_READY
		break
	fi
	i=$((i + 1))
	sleep 1
done
ls -l /tmp/cad_app/frame.raw /tmp/cad_app/meta.bin /tmp/cad_app/gen.txt /tmp/cad_app/status.txt 2>/dev/null
cat /tmp/cad_app/gen.txt 2>/dev/null
cat /tmp/cad_app/status.txt 2>/dev/null

echo GO_H56CD_DONE | tee /tmp/go_h56cd_done.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_h56cd_done.txt "$HOST/results/go_h56cd_done.txt" || true
echo GO_H56CD_DONE
