#!/usr/bin/env bash
# Dedicated Serial Debugging Runner for Haiku sys_compat in QEMU
# License: Public Domain / CC0 1.0 Universal

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
DOWNLOAD_DIR="${BASE_DIR}/downloads"
ISO_IMAGE="${DOWNLOAD_DIR}/haiku-r1beta5-x86_64-anyboot.iso"
DISK_IMAGE="${BASE_DIR}/haiku_qemu_disk.qcow2"
PAYLOAD_DIR="${BASE_DIR}/payload"
SERIAL_LOG="${BASE_DIR}/haiku_serial.log"

RAM_SIZE="${RAM_SIZE:-3072M}"
CPU_CORES="${CPU_CORES:-4}"

echo "=================================================================="
echo " Haiku sys_compat Serial Debugging Runner"
echo " Serial Log Output: ${SERIAL_LOG}"
echo "=================================================================="

# Ensure test payload is up to date
make -C "${BASE_DIR}/tests" >/dev/null

mkdir -p "${PAYLOAD_DIR}/tests"
mkdir -p "${PAYLOAD_DIR}/sys_compat"
cp -f "${BASE_DIR}/tests/"* "${PAYLOAD_DIR}/tests/" 2>/dev/null || true
cp -f "${BASE_DIR}/src/"* "${PAYLOAD_DIR}/sys_compat/" 2>/dev/null || true

ACCEL_FLAGS=""
if [ -e /dev/kvm ] && [ -w /dev/kvm ]; then
    ACCEL_FLAGS="-enable-kvm -cpu host"
else
    ACCEL_FLAGS="-cpu qemu64"
fi

if [ ! -f "${DISK_IMAGE}" ]; then
    qemu-img create -f qcow2 "${DISK_IMAGE}" 3G
fi

echo "[+] Launching QEMU with serial output capturing to ${SERIAL_LOG}..."

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
    -serial file:${SERIAL_LOG} \
    -monitor unix:${BASE_DIR}/qemu_monitor.sock,server,nowait \
    -device e1000,netdev=net0 \
    -netdev user,id=net0,hostfwd=tcp::2222-:22,hostfwd=tcp::8080-:80 \
    -drive file=${DISK_IMAGE},format=qcow2,if=ide \
    -drive file=fat:rw:${PAYLOAD_DIR},format=raw \
    -boot order=c,menu=on"

echo "[+] Booting directly from installed Haiku hard drive (${DISK_IMAGE})..."

echo "Executing:"
echo "${QEMU_CMD}"
echo "------------------------------------------------------------------"
echo "Tip: You can monitor kernel output live in another terminal via:"
echo "     tail -f ${SERIAL_LOG}"
echo "------------------------------------------------------------------"

exec ${QEMU_CMD}
