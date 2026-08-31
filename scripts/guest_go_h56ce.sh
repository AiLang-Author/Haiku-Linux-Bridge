#!/bin/sh
# H56ce: compile demo_pacman_profile with ailang.x and ailang_new.x (ProfIR).
# License: Public Domain / CC0 1.0 Universal
set -x
HOST="http://10.0.2.2:8083"
DEST=/boot/home/Ailang-Self-Hosting-
cd "$DEST" || exit 1
echo GO_H56CE_GO | tee /tmp/go_h56ce_go.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_h56ce_go.txt "$HOST/results/go_h56ce_go.txt" || true

echo "=== ailang.x (linux original) pacman ==="
/boot/home/sys_compat_run /boot/home/ailang.x CAD/demo_pacman_profile.ailang /boot/home/pacman_old.x
echo OLDCC_RC=$?
ls -l /boot/home/pacman_old.x 2>/dev/null || echo NO_OLD

echo "=== ailang_new.x (haiku selfcc) pacman ==="
/boot/home/sys_compat_run /boot/home/ailang_new.x CAD/demo_pacman_profile.ailang /boot/home/pacman_new.x
echo NEWCC_RC=$?
ls -l /boot/home/pacman_new.x 2>/dev/null || echo NO_NEW

echo GO_H56CE_DONE | tee /tmp/go_h56ce_done.txt
curl -s --max-time 8 -X POST --data-binary @/tmp/go_h56ce_done.txt "$HOST/results/go_h56ce_done.txt" || true
echo GO_H56CE_DONE
