#!/usr/bin/env python3
# Autonomous Haiku Module Installer and Test Runner
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

    print("[+] Bringing Haiku Terminal window to focus...")
    send_qemu_cmd("sendkey alt-ctrl-t")
    time.sleep(1.5)

    print("[+] Installing sys_compat kernel add-on...")
    type_text("mkdir -p /boot/system/non-packaged/add-ons/kernel/generic/\n")
    time.sleep(0.5)

    type_text("cp -rf /payload/sys_compat /boot/home/sys_compat_src\n")
    time.sleep(0.5)

    print("[+] Copying 64-bit Linux test executables...")
    type_text("cp /payload/tests/* /boot/home/\n")
    time.sleep(0.5)

    type_text("chmod +x /boot/home/hello_stat /boot/home/hello_dyn /boot/home/test_net /boot/home/test_file /boot/home/test_mem /boot/home/test_sys\n")
    time.sleep(0.5)

    print("[+] Executing 64-bit Linux binaries...")
    type_text("/boot/home/hello_stat\n")
    time.sleep(1)

    type_text("/boot/home/test_net\n")
    time.sleep(1)

    print("[+] Autonomous automation sequence finished.")
