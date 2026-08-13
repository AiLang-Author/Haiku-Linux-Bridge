#!/usr/bin/env python3
# Build & Install sys_compat Kernel Add-on Natively inside Haiku OS
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

    print("[+] Fetching Haiku kernel add-on sources...")
    type_text("mkdir -p /boot/home/src /boot/system/non-packaged/add-ons/kernel/generic/\n")
    time.sleep(0.5)

    type_text("curl -s -o /boot/home/src/module.cpp http://10.0.2.2:8081/src/module.cpp\n")
    time.sleep(0.5)

    type_text("curl -s -o /boot/home/src/dispatch.cpp http://10.0.2.2:8081/src/dispatch.cpp\n")
    time.sleep(0.5)

    type_text("curl -s -o /boot/home/src/sys_mem.cpp http://10.0.2.2:8081/src/sys_mem.cpp\n")
    time.sleep(0.5)

    type_text("curl -s -o /boot/home/src/sys_file.cpp http://10.0.2.2:8081/src/sys_file.cpp\n")
    time.sleep(0.5)

    type_text("curl -s -o /boot/home/src/ioctl_bridge.cpp http://10.0.2.2:8081/src/ioctl_bridge.cpp\n")
    time.sleep(0.5)

    type_text("curl -s -o /boot/home/src/proc_vfs.cpp http://10.0.2.2:8081/src/proc_vfs.cpp\n")
    time.sleep(0.5)

    type_text("curl -s -o /boot/home/src/linux_syscalls.h http://10.0.2.2:8081/src/linux_syscalls.h\n")
    time.sleep(0.5)

    type_text("curl -s -o /boot/home/src/linux_sys_table.h http://10.0.2.2:8081/src/linux_sys_table.h\n")
    time.sleep(0.5)

    type_text("curl -s -o /boot/home/src/linux_errno.h http://10.0.2.2:8081/src/linux_errno.h\n")
    time.sleep(0.5)

    print("[+] Compiling sys_compat kernel add-on natively in Haiku...")
    type_text("g++ -O2 -nostdlib -shared /boot/home/src/*.cpp -o /boot/system/non-packaged/add-ons/kernel/generic/sys_compat 2>/dev/null || gcc -O2 -shared /boot/home/src/*.cpp -o /boot/system/non-packaged/add-ons/kernel/generic/sys_compat\n")
    time.sleep(4.0)

    print("[+] Executing BusyBox via sys_compat_run...")
    type_text("/boot/home/sys_compat_run /boot/home/busybox uname -a\n")
    time.sleep(2.0)

    print("[+] Kernel add-on build & execution sequence finished.")
