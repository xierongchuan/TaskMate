#!/usr/bin/env python3
"""
Webhook-сервер для автодеплоя TaskMate.
Слушает POST /deploy с проверкой GitHub signature.
Запуск: python3 webhook_server.py
"""

import hashlib
import hmac
import json
import os
import subprocess
import sys
from http.server import HTTPServer, BaseHTTPRequestHandler

PORT = 9500
SECRET = os.environ.get("WEBHOOK_SECRET", "")
DEPLOY_SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "deploy_server.sh")
BRANCH = "vfp"
LOG_FILE = "/var/log/taskmate-deploy.log"


def verify_signature(payload: bytes, signature: str) -> bool:
    if not SECRET:
        return True  # no secret configured — skip check
    expected = "sha256=" + hmac.new(SECRET.encode(), payload, hashlib.sha256).hexdigest()
    return hmac.compare_digest(expected, signature)


class WebhookHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path != "/deploy":
            self.send_response(404)
            self.end_headers()
            return

        content_length = int(self.headers.get("Content-Length", 0))
        payload = self.rfile.read(content_length)

        # Verify GitHub signature
        signature = self.headers.get("X-Hub-Signature-256", "")
        if SECRET and not verify_signature(payload, signature):
            self.send_response(403)
            self.end_headers()
            self.wfile.write(b"Invalid signature")
            return

        # Check branch
        try:
            data = json.loads(payload)
            ref = data.get("ref", "")
        except (json.JSONDecodeError, AttributeError):
            ref = ""

        if ref and ref != f"refs/heads/{BRANCH}":
            self.send_response(200)
            self.end_headers()
            self.wfile.write(f"Skipped: {ref} != refs/heads/{BRANCH}".encode())
            return

        # Run deploy in background
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"Deploy started")

        print(f"[webhook] Deploy triggered (ref={ref})", flush=True)
        with open(LOG_FILE, "a") as log:
            subprocess.Popen(
                ["bash", DEPLOY_SCRIPT],
                stdout=log,
                stderr=log,
                start_new_session=True,
            )

    def do_GET(self):
        if self.path == "/health":
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"ok")
            return
        self.send_response(404)
        self.end_headers()

    def log_message(self, format, *args):
        print(f"[webhook] {args[0]}", flush=True)


if __name__ == "__main__":
    print(f"[webhook] Listening on :{PORT}, branch={BRANCH}", flush=True)
    server = HTTPServer(("0.0.0.0", PORT), WebhookHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("[webhook] Shutting down")
        server.shutdown()
