#!/bin/sh
# H56ch: CAD_ProfIR facade (sole SketchProfile.ProfIR import); pacman + cad_app.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
DEST=/boot/home/Ailang-Self-Hosting-
cd "$DEST" || exit 1
echo GO_H56CH_GO | tee /tmp/go_h56ch_go.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_h56ch_go.txt "$HOST/results/go_h56ch_go.txt" || true

curl -s --max-time 20 -o Librarys/Cad/Library.CAD_Sketch.ailang \
	"$HOST/payload/cad/Library.CAD_Sketch_h56ch.ailang"
curl -s --max-time 20 -o Librarys/Cad/Library.CAD_ProfIR.ailang \
	"$HOST/payload/cad/Library.CAD_ProfIR_h56ch.ailang"
grep -n 'CAD_ProfIR\|SketchProfile.ProfIR' Librarys/Cad/Library.CAD_Sketch.ailang Librarys/Cad/Library.CAD_ProfIR.ailang

echo "=== pacman ==="
/boot/home/sys_compat_run /boot/home/ailang.x CAD/demo_pacman_profile.ailang /boot/home/pacman_old.x
echo PACCC_RC=$?
ls -l /boot/home/pacman_old.x 2>/dev/null || echo NO_PAC
echo GO_H56CH_PAC | tee /tmp/go_h56ch_pac.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_h56ch_pac.txt "$HOST/results/go_h56ch_pac.txt" || true

echo "=== cad_app ==="
/boot/home/sys_compat_run /boot/home/ailang.x CAD/cad_app.ailang /boot/home/cad_app.x
echo CADCC_RC=$?
ls -l /boot/home/cad_app.x 2>/dev/null || echo NO_CAD
echo GO_H56CH_DONE | tee /tmp/go_h56ch_done.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_h56ch_done.txt "$HOST/results/go_h56ch_done.txt" || true
echo GO_H56CH_DONE
