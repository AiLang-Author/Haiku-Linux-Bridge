#!/usr/bin/env python3
# Clone Haiku-Linux-Bridge from GitHub directly inside Haiku OS and build natively
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

    print("[+] Cloning Haiku-Linux-Bridge repository from GitHub directly inside Haiku...")
    type_text("cd /boot/home\n")
    time.sleep(0.5)

    type_text("rm -rf Haiku-Linux-Bridge\n")
    time.sleep(0.5)

    type_text("git clone https://github.com/AiLang-Author/Haiku-Linux-Bridge.git\n")
    time.sleep(3.0)

    type_text("cd Haiku-Linux-Bridge\n")
    time.sleep(0.5)

    print("[+] Compiling sys_compat_run adapter inside cloned repo...")
    type_text("gcc -O2 src/sys_compat_run.c -o sys_compat_run\n")
    time.sleep(2.0)

    type_text("make -C tests\n")
    time.sleep(2.0)

    print("[+] Executing hello_linux static binary via sys_compat_run...")
    type_text("./sys_compat_run ./tests/hello_linux\n")
    time.sleep(1.5)

    print("[+] Direct GitHub clone and build sequence completed.")
