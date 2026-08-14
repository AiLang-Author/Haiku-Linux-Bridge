#!/usr/bin/env python3
# HTTP server: push LTP binaries to the Haiku QEMU guest and collect results.
# Guest reaches the host at 10.0.2.2 (QEMU user-net gateway).
# License: Public Domain / CC0 1.0 Universal

from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
import os
import sys
from pathlib import Path

BASE_DIR = Path("/home/bob/Haiku-Linux-bridge")
RESULT_DIR = BASE_DIR / "results" / "ltp"
LISTEN_HOST = os.environ.get("LTP_NET_HOST", "0.0.0.0")
LISTEN_PORT = int(os.environ.get("LTP_NET_PORT", "8083"))


class LtpHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(BASE_DIR), **kwargs)

    def do_GET(self):
        if self.path in ("/", "/health"):
            body = b"ok ltp-net-server\n"
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        if self.path.startswith("/bootstrap.sh"):
            self.path = "/payload/ltp/bootstrap.sh"
        return super().do_GET()

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        data = self.rfile.read(length)
        name = os.path.basename(self.path.rstrip("/")) or "ltp_results.txt"
        if not name.endswith(".txt") and not name.endswith(".log"):
            name += ".txt"
        RESULT_DIR.mkdir(parents=True, exist_ok=True)
        dest = RESULT_DIR / name
        dest.write_bytes(data)
        print(f"[+] saved {dest} ({len(data)} bytes)")
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"OK\n")

    def log_message(self, fmt, *args):
        sys.stdout.write("[ltp-net] " + (fmt % args) + "\n")
        sys.stdout.flush()


def main():
    RESULT_DIR.mkdir(parents=True, exist_ok=True)
    server = ThreadingHTTPServer((LISTEN_HOST, LISTEN_PORT), LtpHandler)
    print(f"[+] LTP net server  http://{LISTEN_HOST}:{LISTEN_PORT}/")
    print(f"    serving {BASE_DIR}")
    print(f"    POST /results/<name> -> {RESULT_DIR}")
    print("    guest fetch: curl -s -o /boot/home/bootstrap.sh http://10.0.2.2:8083/bootstrap.sh")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[+] stopped")


if __name__ == "__main__":
    main()
