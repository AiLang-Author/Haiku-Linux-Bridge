#!/usr/bin/env python3
# Tiny QEMU monitor helper: send keys / take a screendump.
# License: Public Domain / CC0 1.0 Universal

import os
import socket
import sys
import time

SOCK_PATH = os.environ.get(
    "QEMU_MONITOR_SOCK", "/home/bob/Haiku-Linux-bridge/qemu_monitor.sock"
)


def send_cmd(cmd, wait=0.15):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(3.0)
    s.connect(SOCK_PATH)
    try:
        s.recv(1024)
    except socket.timeout:
        pass
    s.sendall((cmd + "\n").encode("utf-8"))
    time.sleep(wait)
    try:
        res = s.recv(8192).decode("utf-8", errors="ignore")
    except socket.timeout:
        res = ""
    s.close()
    return res


def send_key(key, pause=0.05):
    send_cmd(f"sendkey {key}", wait=pause)


def type_text(text):
    keymap = {
        " ": "spc",
        "/": "slash",
        "-": "minus",
        ".": "dot",
        ">": "shift-dot",
        "<": "shift-comma",
        "_": "shift-minus",
        ":": "shift-semicolon",
        "@": "shift-2",
        "*": "shift-8",
        "=": "equal",
        "+": "shift-equal",
        "?": "shift-slash",
        "&": "shift-7",
        "|": "shift-backslash",
        ";": "semicolon",
        '"': "shift-apostrophe",
        "'": "apostrophe",
        "\n": "ret",
        "\t": "tab",
    }
    for char in text:
        if char in keymap:
            send_key(keymap[char])
        elif char.isupper():
            send_key(f"shift-{char.lower()}")
        else:
            send_key(char)


def screendump(path):
    send_cmd(f"screendump {path}", wait=0.4)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(send_cmd("info status"))
        sys.exit(0)
    op = sys.argv[1]
    if op == "type":
        type_text(sys.argv[2])
    elif op == "key":
        send_key(sys.argv[2])
    elif op == "cmd":
        print(send_cmd(" ".join(sys.argv[2:])))
    elif op == "dump":
        screendump(sys.argv[2])
    else:
        print(send_cmd(" ".join(sys.argv[1:])))
