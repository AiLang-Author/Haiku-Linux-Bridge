#!/usr/bin/env python3
# Clean Native Build & Launch Sequence for sys_compat_run on Haiku
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

    print("[+] Downloading zero-dependency sys_compat_run.c...")
    type_text("cd /boot/home\n")
    time.sleep(0.5)

    type_text("curl -s -o sys_compat_run.c http://10.0.2.2:8081/src/sys_compat_run.c\n")
    time.sleep(1.5)

    print("[+] Compiling sys_compat_run natively in Haiku with GCC...")
    type_text("gcc -O2 sys_compat_run.c -o sys_compat_run\n")
    time.sleep(3.0)

    type_text("chmod 755 sys_compat_run busybox\n")
    time.sleep(0.5)

    print("[+] Launching pristine Linux BusyBox with raw syscall TLS launcher...")
    type_text("./sys_compat_run ./busybox\n")
    time.sleep(2.0)

    print("[+] Build & execution sequence finished.")
