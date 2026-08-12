#!/usr/bin/env python3
# Automated Test Runner for sys_compat on Haiku QEMU VM
# License: Public Domain / CC0 1.0 Universal

import socket
import sys
import time

SOCK_PATH = "/home/bob/Haiku-Linux-bridge/qemu_monitor.sock"

def qemu_send(cmd):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(SOCK_PATH)
    s.recv(1024)
    s.sendall(f"{cmd}\n".encode('utf-8'))
    time.sleep(0.2)
    res = s.recv(4096).decode('utf-8', errors='ignore')
    s.close()
    return res

def type_string(text):
    for char in text:
        if char == ' ':
            qemu_send("sendkey spc")
        elif char == '/':
            qemu_send("sendkey slash")
        elif char == '-':
            qemu_send("sendkey minus")
        elif char == '.':
            qemu_send("sendkey dot")
        elif char == '_':
            qemu_send("sendkey shift-minus")
        elif char == '\n':
            qemu_send("sendkey ret")
        elif char.isupper():
            qemu_send(f"sendkey shift-{char.lower()}")
        else:
            qemu_send(f"sendkey {char}")
        time.sleep(0.05)

if __name__ == "__main__":
    print("[+] QEMU Control Interface Connected.")
    status = qemu_send("info status")
    print(f"[+] QEMU VM Status: {status.strip()}")
