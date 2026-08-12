#!/usr/bin/env python3
# Comprehensive All-Layers Haiku Linux Bridge Automation Test Script
# License: Public Domain / CC0 1.0 Universal

import socket
import sys
import time

SOCK_PATH = "/home/bob/Haiku-Linux-bridge/qemu_monitor.sock"
SERIAL_LOG = "/home/bob/Haiku-Linux-bridge/haiku_serial.log"

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
        elif char == '\n':
            send_key("ret")
        elif char.isupper():
            send_key(f"shift-{char.lower()}")
        else:
            send_key(f"{char}")
        time.sleep(0.04)

if __name__ == "__main__":
    print("[+] Connecting to Haiku QEMU session...")
    status = send_qemu_cmd("info status")
    print(f"[+] QEMU Status: {status.strip()}")

    print("[+] Focusing Haiku Terminal...")
    send_qemu_cmd("sendkey alt-ctrl-t")
    time.sleep(1.5)

    print("[+] Copying all test binaries to Haiku home...")
    type_text("cp /payload/tests/* /boot/home/\n")
    time.sleep(0.5)

    type_text("chmod +x /boot/home/test_vfs /boot/home/test_epoll /boot/home/test_signal /boot/home/test_ioctl\n")
    time.sleep(0.5)

    print("[+] Executing Layer 1 Synthetic VFS Test...")
    type_text("/boot/home/test_vfs\n")
    time.sleep(1.5)

    print("[+] Executing Layer 2 Real Epoll Test...")
    type_text("/boot/home/test_epoll\n")
    time.sleep(1.5)

    print("[+] Executing Layer 3 Signal Handling Test...")
    type_text("/boot/home/test_signal\n")
    time.sleep(1.5)

    print("[+] Executing Layer 4 Dynamic Linker Test...")
    type_text("/payload/lib64/ld-linux-x86-64.so.2 --library-path /payload/lib64 /boot/home/hello_linux\n")
    time.sleep(1.5)

    print("[+] All Layer Dependencies Execution Sequence Completed.")
