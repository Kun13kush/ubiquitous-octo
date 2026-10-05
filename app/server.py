"""Small dependency-free assessment service; no customer data or secrets."""
import json
import os
import signal
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/health":
            status, body = 200, {"status": "ok"}
        elif self.path == "/version":
            status, body = 200, {"version": os.getenv("APP_VERSION", "local"), "environment": os.getenv("APP_ENV", "development")}
        else:
            status, body = 404, {"error": "not found"}
        payload = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, format, *args):
        print(json.dumps({"event": "http_request", "message": format % args}), flush=True)


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, lambda *_: exit(0))
    server = ThreadingHTTPServer(("0.0.0.0", int(os.getenv("PORT", "8080"))), Handler)
    print(json.dumps({"event": "started", "port": server.server_port}), flush=True)
    server.serve_forever()
