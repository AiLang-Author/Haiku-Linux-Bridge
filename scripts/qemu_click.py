#!/usr/bin/env python3
# Absolute mouse click in the guest via QMP (needs usb-tablet).
# Usage: qemu_click.py X Y [button=left]
# Coordinates are 0..32767 in both axes (QEMU abs tablet).
# License: Public Domain / CC0 1.0 Universal

import json
import socket
import sys
import time

QMP = "/home/bob/Haiku-Linux-bridge/qemu_qmp.sock"


def qmp():
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(5)
    s.connect(QMP)
    greeting = s.recv(4096)
    s.sendall(b'{"execute":"qmp_capabilities"}\n')
    s.recv(4096)
    return s


def send(s, obj):
    s.sendall((json.dumps(obj) + "\n").encode())
    return s.recv(8192)


def abs_move(s, x, y):
    # QEMU abs axis range is 0..32767
    send(s, {
        "execute": "input-send-event",
        "arguments": {
            "events": [
                {"type": "abs", "data": {"axis": "x", "value": int(x)}},
                {"type": "abs", "data": {"axis": "y", "value": int(y)}},
            ]
        }
    })


def btn(s, down, button="left"):
    send(s, {
        "execute": "input-send-event",
        "arguments": {
            "events": [
                {"type": "btn", "data": {"down": bool(down), "button": button}}
            ]
        }
    })


def click(x, y, button="left"):
    s = qmp()
    abs_move(s, x, y)
    time.sleep(0.05)
    btn(s, True, button)
    time.sleep(0.05)
    btn(s, False, button)
    s.close()


def px_to_abs(px, py, w=1280, h=800):
    return int(px * 32767 / (w - 1)), int(py * 32767 / (h - 1))


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("usage: qemu_click.py <pixel_x> <pixel_y> [left|right] [width] [height]")
        sys.exit(1)
    px, py = int(sys.argv[1]), int(sys.argv[2])
    button = sys.argv[3] if len(sys.argv) > 3 else "left"
    w = int(sys.argv[4]) if len(sys.argv) > 4 else 1280
    h = int(sys.argv[5]) if len(sys.argv) > 5 else 800
    ax, ay = px_to_abs(px, py, w, h)
    click(ax, ay, button)
    print(f"clicked pixel ({px},{py}) abs ({ax},{ay}) {button}")
