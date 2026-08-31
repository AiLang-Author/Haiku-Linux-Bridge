#!/bin/sh
# H56ls: dump SketchProfile tree + git HEAD after cad_app unknown ProfCompile.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
DEST=/boot/home/Ailang-Self-Hosting-
cd "$DEST" || exit 1
{
	echo "=== git ==="
	git log -1 --oneline
	git rev-parse HEAD
	echo "=== sketchprofile ==="
	ls -la Librarys/Cad/SketchProfile/
	ls -la Librarys/Cad/Library.CAD_SketchProfile.ailang Librarys/Cad/Library.CAD_Sketch.ailang
	echo "=== grep ProfCompile ==="
	grep -n ProfCompile Librarys/Cad/SketchProfile/Library.ProfIR.ailang | head
	grep -n 'LibraryImport.Cad.SketchProfile' Librarys/Cad/Library.CAD_SketchProfile.ailang
	echo "=== df ==="
	df -h
} > /tmp/h56ls.txt 2>&1
cat /tmp/h56ls.txt
curl -s --max-time 15 -X POST --data-binary @/tmp/h56ls.txt "$HOST/results/h56ls.txt" || true
echo GO_H56LS_DONE
curl -s --max-time 8 -X POST --data-binary @/tmp/h56ls.txt "$HOST/results/go_h56ls_done.txt" || true
