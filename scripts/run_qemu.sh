#!/usr/bin/env bash
# Script to run Haiku OS inside QEMU with sys_compat test module support
# License: Public Domain / CC0 1.0 Universal

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
DOWNLOAD_DIR="${BASE_DIR}/downloads"
ISO_IMAGE="${DOWNLOAD_DIR}/haiku-r1beta5-x86_64-anyboot.iso"
DISK_IMAGE="${BASE_DIR}/haiku_qemu_disk.qcow2"

RAM_SIZE="${RAM_SIZE:-3072M}"
CPU_CORES="${CPU_CORES:-4}"

echo "=================================================================="
echo " Launching QEMU for Haiku OS"
echo " Memory: ${RAM_SIZE} | Cores: ${CPU_CORES}"
echo "=================================================================="

if [ ! -f "${DISK_IMAGE}" ]; then
    echo "Creating QCow2 virtual disk drive (3GB)..."
    qemu-img create -f qcow2 "${DISK_IMAGE}" 3G
fi

ACCEL_FLAGS=""
if [ -e /dev/kvm ] && [ -w /dev/kvm ]; then
    echo "[+] KVM hardware acceleration detected and enabled."
    ACCEL_FLAGS="-enable-kvm -cpu host"
else
    echo "[!] KVM not accessible. Falling back to default TCG emulation (x86_64)."
    ACCEL_FLAGS="-cpu qemu64"
fi

PAYLOAD_DIR="${BASE_DIR}/payload"
mkdir -p "${PAYLOAD_DIR}/tests"
mkdir -p "${PAYLOAD_DIR}/sys_compat"

if [ -f "${BASE_DIR}/tests/hello_linux" ]; then
    echo "[+] Copying test binaries to virtual FAT payload directory..."
    cp -f "${BASE_DIR}/tests/"* "${PAYLOAD_DIR}/tests/" 2>/dev/null || true
    cp -f "${BASE_DIR}/src/"* "${PAYLOAD_DIR}/sys_compat/" 2>/dev/null || true
fi

DISPLAY_FLAGS=""
if [ -z "${DISPLAY:-}" ]; then
    echo "[!] No X11 DISPLAY detected. Running QEMU in headless VNC mode (127.0.0.1:5900)..."
    DISPLAY_FLAGS="-display vnc=127.0.0.1:0"
else
    DISPLAY_FLAGS="-vga std"
fi

QEMU_CMD="qemu-system-x86_64 \
    ${ACCEL_FLAGS} \
    ${DISPLAY_FLAGS} \
    -m ${RAM_SIZE} \
    -smp ${CPU_CORES} \
    -monitor unix:${BASE_DIR}/qemu_monitor.sock,server,nowait \
    -qmp unix:${BASE_DIR}/qemu_qmp.sock,server,nowait \
    -usb -device usb-tablet \
    -device e1000,netdev=net0 \
    -netdev user,id=net0,hostfwd=tcp::2222-:22,hostfwd=tcp::8080-:80 \
    -drive file=${DISK_IMAGE},format=qcow2,if=ide \
    -drive file=fat:rw:${PAYLOAD_DIR},format=raw \
    -serial file:${BASE_DIR}/haiku_serial.log \
    -boot order=c,menu=off"

echo "Booting directly from installed Haiku hard drive (${DISK_IMAGE})..."

echo "Executing command:"
echo "${QEMU_CMD}"
echo "------------------------------------------------------------------"

exec ${QEMU_CMD}
