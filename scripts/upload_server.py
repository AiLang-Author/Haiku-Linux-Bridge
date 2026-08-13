#!/usr/bin/env python3
# Simple HTTP Upload Server on Port 8082
# License: Public Domain / CC0 1.0 Universal

from http.server import HTTPServer, BaseHTTPRequestHandler
import sys

class UploadHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get('Content-Length', 0))
        data = self.rfile.read(length)
        filename = self.path.lstrip('/')
        if not filename:
            filename = "uploaded.png"
        save_path = f"/home/bob/Haiku-Linux-bridge/{filename}"
        with open(save_path, "wb") as f:
            f.write(data)
        print(f"[+] Received and saved {save_path} ({len(data)} bytes)")
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"OK")

if __name__ == "__main__":
    server = HTTPServer(('0.0.0.0', 8082), UploadHandler)
    print("[+] HTTP Upload Server listening on port 8082...")
    server.serve_forever()
