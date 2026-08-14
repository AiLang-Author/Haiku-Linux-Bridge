#!/usr/bin/env python3
# Drive the Haiku QEMU guest to download the LTP subset over the network,
# run each binary through sys_compat_run, and POST results back to the host.
# License: Public Domain / CC0 1.0 Universal

import os
import socket
import sys
import time

SOCK_PATH = os.environ.get(
    "QEMU_MONITOR_SOCK", "/home/bob/Haiku-Linux-bridge/qemu_monitor.sock"
)
GUEST_HOST = os.environ.get("LTP_GUEST_HOST", "10.0.2.2")
GUEST_PORT = os.environ.get("LTP_NET_PORT", "8083")


def send_qemu_cmd(cmd):
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.connect(SOCK_PATH)
        s.recv(1024)
        s.sendall(f"{cmd}\n".encode("utf-8"))
        time.sleep(0.1)
        res = s.recv(4096).decode("utf-8", errors="ignore")
        s.close()
        return res
    except Exception as e:
        return f"Error: {e}"


def send_key(key):
    send_qemu_cmd(f"sendkey {key}")
    time.sleep(0.04)


def type_text(text):
    keymap = {
        " ": "spc",
        "/": "slash",
        "-": "minus",
        ".": "dot",
        "_": "shift-minus",
        ":": "shift-semicolon",
        "@": "shift-2",
        "*": "shift-8",
        "=": "equal",
        "+": "shift-equal",
        "?": "shift-slash",
        "&": "shift-7",
        "\n": "ret",
    }
    for char in text:
        if char in keymap:
            send_key(keymap[char])
        elif char.isupper():
            send_key(f"shift-{char.lower()}")
        else:
            send_key(char)
        time.sleep(0.04)


def main():
    if not os.path.exists(SOCK_PATH):
        print(f"[-] QEMU monitor socket missing: {SOCK_PATH}")
        print("    start the guest first:  ./scripts/run_qemu.sh")
        return 1

    print("[+] Connecting to QEMU monitor...")
    status = send_qemu_cmd("info status")
    print(f"[+] QEMU: {status.strip()}")
    if status.startswith("Error:"):
        return 1

    print("[+] Focusing Haiku Terminal (Alt-Ctrl-T)...")
    send_qemu_cmd("sendkey alt-ctrl-t")
    time.sleep(1.5)

    # Prefer the FAT payload copy; fall back to network fetch of the guest runner.
    print("[+] Fetching guest bootstrap (prebuilt Linux ELFs only)...")
    type_text("mountvolume -a\n")
    time.sleep(1.0)
    type_text(
        f"curl -s -o /boot/home/bootstrap.sh http://{GUEST_HOST}:{GUEST_PORT}/bootstrap.sh\n"
    )
    time.sleep(2.0)
    type_text("chmod 755 /boot/home/bootstrap.sh\n")
    time.sleep(0.4)

    print("[+] Running bootstrap: stock Linux binaries through sys_compat_run ...")
    type_text("sh /boot/home/bootstrap.sh\n")
    print("[+] Guest runner kicked off. Results POST to")
    print(f"    http://{GUEST_HOST}:{GUEST_PORT}/results/ltp_results.txt")
    print("    host file: /home/bob/Haiku-Linux-bridge/results/ltp/ltp_results.txt")
    print("[+] Leave QEMU running; the guest script uploads when finished.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
