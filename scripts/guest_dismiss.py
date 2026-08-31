#!/usr/bin/env python3
# Type `sh /boot/home/dc.sh` into the guest Terminal (short sendkey).
# Install first: curl dismiss scripts (guest_run_next.sh fetches them).
# License: Public Domain / CC0 1.0 Universal
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from qemu_click import click, px_to_abs
from qemu_keys import send_key


def click_px(x, y):
    ax, ay = px_to_abs(x, y)
    click(ax, ay)


def type_slow(text, pause=0.08):
    keymap = {
        " ": "spc",
        "/": "slash",
        "-": "minus",
        ".": "dot",
        "_": "shift-minus",
    }
    for ch in text:
        if ch in keymap:
            send_key(keymap[ch], pause=pause)
        else:
            send_key(ch, pause=pause)


def main():
    click_px(250, 220)
    time.sleep(0.3)
    # fetch + run once if dc.sh is missing
    cmd = sys.argv[1] if len(sys.argv) > 1 else "sh /boot/home/dc.sh 5"
    type_slow(cmd)
    send_key("ret", pause=0.2)
    print("TYPED", cmd)


if __name__ == "__main__":
    main()
