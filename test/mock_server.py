"""Records requests for test.sh and answers 200, or 500 for paths containing /broken."""
import json
import sys
import urllib.parse
from http.server import BaseHTTPRequestHandler, HTTPServer

LOG = sys.argv[2]


class Handler(BaseHTTPRequestHandler):
    def handle_any(self):
        length = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(length).decode() if length else ""
        with open(LOG, "a") as log:
            log.write(json.dumps({"method": self.command, "path": self.path, "form": urllib.parse.parse_qs(body)}) + "\n")
        status = 500 if "/broken" in self.path else 200
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(b'{"success": true}')

    do_GET = do_POST = handle_any

    def log_message(self, *args):
        pass


HTTPServer(("127.0.0.1", int(sys.argv[1])), Handler).serve_forever()
