#!/usr/bin/env python3
# QEMU Monitor Automation Helper for Haiku sys_compat
# License: Public Domain / CC0 1.0 Universal

import socket
import sys
import time

SOCK_PATH = "/home/bob/Haiku-Linux-bridge/qemu_monitor.sock"

def send_qemu_cmd(cmd):
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.connect(SOCK_PATH)
        s.recv(1024) # read greeting
        s.sendall(f"{cmd}\n".encode('utf-8'))
        time.sleep(0.5)
        resp = s.recv(4096).decode('utf-8', errors='ignore')
        s.close()
        return resp
    except Exception as e:
        return f"Error: {e}"

if __name__ == "__main__":
    command = sys.argv[1] if len(sys.argv) > 1 else "info status"
    print(send_qemu_cmd(command))
