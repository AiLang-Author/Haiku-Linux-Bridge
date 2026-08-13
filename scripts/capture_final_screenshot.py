#!/usr/bin/env python3
# Capture screenshot5.png of zero-dependency sys_compat_run execution inside Haiku
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
        elif char == ':':
            send_key("shift-semicolon")
        elif char == '@':
            send_key("shift-2")
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

    print("[+] Capturing screenshot5.png via Haiku screenshot tool...")
    type_text("screenshot -f /boot/home/screenshot5.png\n")
    time.sleep(1.0)

    print("[+] Uploading screenshot5.png to host upload server (10.0.2.2:8082)...")
    type_text("curl -X POST --data-binary @/boot/home/screenshot5.png http://10.0.2.2:8082/screenshot5.png\n")
    time.sleep(1.5)

    print("[+] Screenshot 5 capture & upload completed.")
