#!/bin/sh
# H56cf: hoist ProfIR import onto CAD_Sketch facade; compile pacman then cad_app.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
DEST=/boot/home/Ailang-Self-Hosting-
cd "$DEST" || exit 1
echo GO_H56CF_GO | tee /tmp/go_h56cf_go.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_h56cf_go.txt "$HOST/results/go_h56cf_go.txt" || true

curl -s --max-time 20 -o Librarys/Cad/Library.CAD_Sketch.ailang \
	"$HOST/payload/cad/Library.CAD_Sketch_h56cf.ailang"
grep -n ProfIR Librarys/Cad/Library.CAD_Sketch.ailang

echo "=== pacman via ailang.x ==="
/boot/home/sys_compat_run /boot/home/ailang.x CAD/demo_pacman_profile.ailang /boot/home/pacman_old.x
echo OLDCC_RC=$?
ls -l /boot/home/pacman_old.x 2>/dev/null || echo NO_OLD

echo GO_H56CF_PAC | tee /tmp/go_h56cf_pac.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_h56cf_pac.txt "$HOST/results/go_h56cf_pac.txt" || true

echo "=== cad_app via ailang.x ==="
/boot/home/sys_compat_run /boot/home/ailang.x CAD/cad_app.ailang /boot/home/cad_app.x
echo CADCC_RC=$?
ls -l /boot/home/cad_app.x 2>/dev/null || echo NO_CAD_APP

echo GO_H56CF_DONE | tee /tmp/go_h56cf_done.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_h56cf_done.txt "$HOST/results/go_h56cf_done.txt" || true
echo GO_H56CF_DONE
