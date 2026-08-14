#!/usr/bin/env python3
# Open Haiku Terminal via Tracker and type a short command.
# License: Public Domain / CC0 1.0 Universal

import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from qemu_click import click, px_to_abs
from qemu_keys import send_key, type_text, screendump


def click_px(x, y):
    ax, ay = px_to_abs(x, y)
    click(ax, ay)


def open_terminal():
    # Desktop home icon ~ (280, 40) at 1280x800.
    click_px(280, 40)
    time.sleep(1.2)
    send_key("alt-up", pause=0.2)
    time.sleep(0.8)
    type_text("system")
    send_key("ret", pause=0.2)
    time.sleep(1.0)
    type_text("apps")
    send_key("ret", pause=0.2)
    time.sleep(1.0)
    type_text("Terminal")
    send_key("ret", pause=0.2)
    time.sleep(2.0)
    # Click into the Terminal client area.
    click_px(400, 260)
    time.sleep(0.4)


if __name__ == "__main__":
    op = sys.argv[1] if len(sys.argv) > 1 else "term"
    if op == "term":
        open_terminal()
        print("opened terminal")
    elif op == "type":
        type_text(sys.argv[2])
        if not sys.argv[2].endswith("\n"):
            send_key("ret")
        print("typed")
    elif op == "shot":
        screendump(sys.argv[2])
        print("shot", sys.argv[2])
    elif op == "click":
        click_px(int(sys.argv[2]), int(sys.argv[3]))
        print("clicked", sys.argv[2], sys.argv[3])
    else:
        sys.exit("usage: guest_term.py term|type TEXT|shot PATH|click X Y")
