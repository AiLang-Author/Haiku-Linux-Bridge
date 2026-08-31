#!/bin/sh
# H56: native Haiku CAD host (app_server / libbe). Not Linux GUI.
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
cd /boot/home
echo GO_H56_GO | tee /tmp/go_h56_go.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_h56_go.txt "$HOST/results/go_h56_go.txt" || true

mkdir -p /boot/home/src /tmp/cad_app
curl -s --max-time 30 -o /boot/home/src/cad_shell_haiku.cxx "$HOST/payload/cad/cad_shell_haiku_h56.cxx"
grep -n 'cad_shell_haiku' /boot/home/src/cad_shell_haiku.cxx | head
g++ -O2 -o /boot/home/cad_shell_haiku /boot/home/src/cad_shell_haiku.cxx -lbe
echo HOSTCC_RC=$?
ls -l /boot/home/cad_shell_haiku
file /boot/home/cad_shell_haiku 2>/dev/null || true

echo GO_H56_BUILT | tee /tmp/go_h56_built.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_h56_built.txt "$HOST/results/go_h56_built.txt" || true

# Native GUI process — app_server, not sys_compat.
/boot/home/cad_shell_haiku /tmp/cad_app &
echo HOSTPID=$!
sleep 1
ps | grep cad_shell || true

echo GO_H56_DONE | tee /tmp/go_h56_done.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_h56_done.txt "$HOST/results/go_h56_done.txt" || true
echo GO_H56_DONE
