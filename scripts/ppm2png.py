#!/usr/bin/env python3
import struct, sys, zlib

def ppm_to_png(src, dst):
    with open(src, "rb") as f:
        magic = f.readline()
        dims = f.readline()
        while dims.startswith(b"#"):
            dims = f.readline()
        _maxv = f.readline()
        w, h = map(int, dims.split())
        rgb = f.read()
    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
    raw = b"".join(b"\x00" + rgb[y * w * 3:(y + 1) * w * 3] for y in range(h))
    with open(dst, "wb") as o:
        o.write(b"\x89PNG\r\n\x1a\n")
        o.write(chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)))
        o.write(chunk(b"IDAT", zlib.compress(raw, 9)))
        o.write(chunk(b"IEND", b""))
    print(f"{dst} {w}x{h}")

if __name__ == "__main__":
    ppm_to_png(sys.argv[1], sys.argv[2])
