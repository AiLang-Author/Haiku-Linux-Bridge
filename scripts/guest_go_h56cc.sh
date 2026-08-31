#!/bin/sh
# H56: git pull Ailang, compile cad_app.x, headless then --nohost for Haiku host.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
DEST=/boot/home/Ailang-Self-Hosting-
cd /boot/home
echo GO_H56CC_GO | tee /tmp/go_h56cc_go.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_h56cc_go.txt "$HOST/results/go_h56cc_go.txt" || true

export GIT_SSL_NO_VERIFY=1
if [ -d "$DEST/.git" ]; then
	cd "$DEST"
	git -c http.sslVerify=false pull --ff-only origin master || git -c http.sslVerify=false fetch --depth 1 origin && git reset --hard origin/master
	git log -1 --oneline
	git rev-parse --short HEAD
else
	echo NO_CLONE
	exit 1
fi

echo GO_H56CC_PULL | tee /tmp/go_h56cc_pull.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_h56cc_pull.txt "$HOST/results/go_h56cc_pull.txt" || true

cd "$DEST"
mkdir -p test-stl /tmp/cad_app
ls -l "test-stl/test-dxf-files/cube.dxf" "CAD/cad_app.ailang" /boot/home/ailang_new.x

echo "=== compile cad_app.ailang ==="
/boot/home/sys_compat_run /boot/home/ailang_new.x CAD/cad_app.ailang /boot/home/cad_app.x
echo CADCC_RC=$?
ls -l /boot/home/cad_app.x 2>/dev/null || echo NO_CAD_APP

echo GO_H56CC_BUILT | tee /tmp/go_h56cc_built.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_h56cc_built.txt "$HOST/results/go_h56cc_built.txt" || true

echo "=== headless cube ==="
cd "$DEST"
/boot/home/sys_compat_run /boot/home/cad_app.x --headless -i test-stl/test-dxf-files/cube.dxf -H 8 -o /tmp/cad_app/cube.bmp
echo HEADLESS_RC=$?
ls -l /tmp/cad_app/cube.bmp test-stl/cad_app.bmp test-stl/cad_app.stp 2>/dev/null

echo GO_H56CC_HEADLESS | tee /tmp/go_h56cc_headless.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_h56cc_headless.txt "$HOST/results/go_h56cc_headless.txt" || true

echo "=== nohost cube (live frame.raw) ==="
rm -f /tmp/cad_app/cmd.txt
/boot/home/sys_compat_run /boot/home/cad_app.x --nohost -i test-stl/test-dxf-files/cube.dxf -H 8
echo NOHOST_RC=$?
ls -l /tmp/cad_app/frame.raw /tmp/cad_app/meta.bin /tmp/cad_app/gen.txt 2>/dev/null

echo GO_H56CC_DONE | tee /tmp/go_h56cc_done.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_h56cc_done.txt "$HOST/results/go_h56cc_done.txt" || true
echo GO_H56CC_DONE
