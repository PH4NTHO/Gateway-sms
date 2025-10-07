#!/usr/bin/env python3
from http.server import BaseHTTPRequestHandler, HTTPServer
import json

PORT = 8080
API_TOKEN = "TESTE123456"

class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path != "/send":
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b'{"error":"not_found"}')
            return

        auth = self.headers.get("Authorization", "")
        if auth != f"Bearer {API_TOKEN}":
            self.send_response(401)
            self.end_headers()
            self.wfile.write(b'{"error":"unauthorized"}')
            return

        length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(length)
        try:
            data = json.loads(body)
            to = data.get("to")
            text = data.get("text")
            if not to or not text:
                raise ValueError
        except:
            self.send_response(400)
            self.end_headers()
            self.wfile.write(b'{"error":"invalid_body"}')
            return

        # Aqui você poderia integrar com um SMS real, por enquanto só responde OK
        print(f"Enviando SMS para {to}: {text}")

        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps({"status":"queued","to":to}).encode())

server = HTTPServer(("0.0.0.0", PORT), Handler)
print(f"API mínima rodando na porta {PORT}")
server.serve_forever()
