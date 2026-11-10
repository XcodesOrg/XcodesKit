"""Serve the two archive fixtures for the CLI and Xcodes.app smoke tests."""

import argparse
import re
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("aea", type=Path, help="Xcode 27.3 beta AEA")
    parser.add_argument("xip", type=Path, help="Xcode 27.3 beta XIP")
    args = parser.parse_args()
    files = {"Xcode_27.3_beta.aea": args.aea, "Xcode_27.3_beta.xip": args.xip}
    if any(not file.is_file() for file in files.values()):
        parser.error("both archives must be local files")

    class Handler(BaseHTTPRequestHandler):
        def do_HEAD(self):
            self.serve_archive(send_body=False)

        def do_GET(self):
            self.serve_archive(send_body=True)

        def serve_archive(self, *, send_body):
            parts = urlsplit(self.path).path.split("/")
            if len(parts) != 3 or parts[1] not in {"app", "cli"} or parts[2] not in files:
                self.send_error(404)
                return
            with files[parts[2]].open("rb") as archive:
                size = files[parts[2]].stat().st_size
                start, end = 0, size - 1
                byte_range = self.headers.get("Range")
                if byte_range:
                    match = re.fullmatch(r"bytes=(\d+)-(\d*)", byte_range)
                    if not match:
                        self.send_error(416)
                        return
                    start = int(match[1])
                    end = min(int(match[2]), end) if match[2] else end
                    if start > end:
                        self.send_error(416)
                        return

                remaining = end - start + 1
                self.send_response(206 if byte_range else 200)
                self.send_header("Content-Type", "application/octet-stream")
                self.send_header("Content-Length", str(remaining))
                self.send_header("Accept-Ranges", "bytes")
                if byte_range:
                    self.send_header("Content-Range", f"bytes {start}-{end}/{size}")
                self.end_headers()
                if send_body:
                    archive.seek(start)
                    try:
                        while remaining:
                            chunk = archive.read(min(remaining, 1024 * 1024))
                            if not chunk:
                                break
                            self.wfile.write(chunk)
                            remaining -= len(chunk)
                    except (BrokenPipeError, ConnectionResetError):
                        pass

    with ThreadingHTTPServer(("127.0.0.1", 0), Handler) as server:
        print(f"http://127.0.0.1:{server.server_port}", flush=True)
        server.serve_forever()


if __name__ == "__main__":
    main()
