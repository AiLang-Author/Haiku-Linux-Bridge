#!/usr/bin/env bash
# Boot Haiku R1/beta6 anyboot ISO to install onto the 20G qcow2.
# Old beta5 disk is attached as second IDE so /boot/home can be copied.
# License: Public Domain / CC0 1.0 Universal
set -euo pipefail
BASE="$(cd "$(dirname "$0")/.." && pwd)"
ISO="$BASE/downloads/haiku-r1beta6-x86_64-anyboot.iso"
NEW="$BASE/haiku_qemu_disk.qcow2"
OLD="$BASE/haiku_qemu_disk.beta5.qcow2"
export DISPLAY="${DISPLAY:-:0}"
exec qemu-system-x86_64 -enable-kvm -cpu host -vga std -m 6144M -smp 4 \
  -monitor unix:"$BASE/qemu_monitor.sock",server,nowait \
  -qmp unix:"$BASE/qemu_qmp.sock",server,nowait \
  -usb -device usb-tablet \
  -device e1000,netdev=net0 \
  -netdev user,id=net0,hostfwd=tcp::2222-:22,hostfwd=tcp::8080-:80 \
  -drive file="$NEW",format=qcow2,if=ide \
  -drive file="$OLD",format=qcow2,if=ide \
  -cdrom "$ISO" \
  -boot order=d,menu=off \
  -serial file:"$BASE/haiku_serial.log"
