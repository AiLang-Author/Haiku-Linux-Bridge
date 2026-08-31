#!/bin/sh
# H56cg: prove guest CAD_Sketch patch + whether ProfIR path opens at all.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
DEST=/boot/home/Ailang-Self-Hosting-
cd "$DEST" || exit 1
{
	echo "=== CAD_Sketch head ==="
	ls -l Librarys/Cad/Library.CAD_Sketch.ailang
	sed -n '36,45p' Librarys/Cad/Library.CAD_Sketch.ailang
	echo "=== ProfIR file ==="
	ls -l Librarys/Cad/SketchProfile/Library.ProfIR.ailang
} > /tmp/h56cg.txt 2>&1
cat /tmp/h56cg.txt
curl -s --max-time 15 -X POST --data-binary @/tmp/h56cg.txt "$HOST/results/h56cg.txt" || true

# tiny program whose only CAD import is ProfIR
printf '%s\n' 'LibraryImport.Cad.SketchProfile.ProfIR' 'SubRoutine.Main { }' 'RunTask(Main)' > /tmp/hi_prof.ailang
echo "=== compile hi_prof ==="
/boot/home/sys_compat_run /boot/home/ailang.x /tmp/hi_prof.ailang /tmp/hi_prof.x
echo PROFCC_RC=$?
ls -l /tmp/hi_prof.x 2>/dev/null || echo NO_HIPROF

echo GO_H56CG_DONE
curl -s --max-time 8 -X POST --data-binary @/tmp/h56cg.txt "$HOST/results/go_h56cg_done.txt" || true
