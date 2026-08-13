#!/usr/bin/env python3
# Fetch screenshot2.png from Haiku OS to Host Linux
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

    print("[+] Copying screenshot2.png to payload volume...")
    type_text("cp /boot/home/screenshot2.png /payload/screenshot2.png 2>/dev/null || cp /boot/home/Desktop/screenshot2.png /payload/screenshot2.png 2>/dev/null || cp ~/screenshot2.png /payload/ 2>/dev/null\n")
    time.sleep(1.5)

    print("[+] Command sent to Haiku Terminal.")
