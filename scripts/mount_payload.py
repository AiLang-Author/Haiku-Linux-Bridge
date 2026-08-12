#!/usr/bin/env python3
# Mount Payload Volume and Copy BusyBox inside Haiku
# License: Public Domain / CC0 1.0 Universal

import socket
import sys
import time

SOCK_PATH = "/home/bob/Haiku-Linux-bridge/qemu_monitor.sock"

def send_qemu_cmd(cmd):
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.connect(SOCK_PATH)
        s.recv(1024)
        s.sendall(f"{cmd}\n".encode('utf-8'))
        time.sleep(0.1)
        res = s.recv(4096).decode('utf-8', errors='ignore')
        s.close()
        return res
    except Exception as e:
        return f"Error: {e}"

def send_key(key):
    send_qemu_cmd(f"sendkey {key}")
    time.sleep(0.04)

def type_text(text):
    for char in text:
        if char == ' ':
            send_key("spc")
        elif char == '/':
            send_key("slash")
        elif char == '-':
            send_key("minus")
        elif char == '.':
            send_key("dot")
        elif char == '_':
            send_key("shift-minus")
        elif char == '*':
            send_key("shift-8")
        elif char == '\n':
            send_key("ret")
        elif char.isupper():
            send_key(f"shift-{char.lower()}")
        else:
            send_key(f"{char}")
        time.sleep(0.04)

if __name__ == "__main__":
    print("[+] Connecting to QEMU monitor socket...")
    send_qemu_cmd("info status")

    print("[+] Focusing Haiku Terminal...")
    send_qemu_cmd("sendkey alt-ctrl-t")
    time.sleep(1.5)

    print("[+] Mounting all disk volumes in Haiku (mountvolume -a)...")
    type_text("mountvolume -a\n")
    time.sleep(1.5)

    print("[+] Listing all mounted volumes in /...")
    type_text("ls -la /disks/\n")
    time.sleep(1.0)

    print("[+] Locating busybox on mounted volumes...")
    type_text("find / -name busybox 2>/dev/null\n")
    time.sleep(1.5)

    print("[+] Copying busybox from payload volume to /boot/home/busybox...")
    type_text("cp /payload/tests/busybox /boot/home/busybox 2>/dev/null || cp /disks/*/tests/busybox /boot/home/busybox 2>/dev/null\n")
    time.sleep(1.0)

    type_text("chmod +x /boot/home/busybox\n")
    time.sleep(0.5)

    type_text("/boot/home/busybox --help | head -n 10\n")
    time.sleep(1.0)

    print("[+] Payload volume mount sequence completed.")
