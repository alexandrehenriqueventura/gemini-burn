"""
Servidor HTTP ultraleve para a interface web e API do Gemini Burn.
Construído com a biblioteca padrão do Python (http.server e threading),
sem dependências externas pesadas.
"""

import os
import json
import time
import threading
from http.server import HTTPServer, BaseHTTPRequestHandler
from typing import Optional

from . import parser, tracker

TEMPLATES_DIR = os.path.join(os.path.dirname(__file__), "templates")
_WINDOW_CONTROLLER = {}

def set_window_controller(controller: dict):
    global _WINDOW_CONTROLLER
    _WINDOW_CONTROLLER = controller

class GeminiBurnHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        # Silencia logs barulhentos no console padrão para manter a saída limpa
        pass

    def send_json(self, data: dict, status: int = 200):
        body = json.dumps(data).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_GET(self):
        if self.path == "/" or self.path == "/index.html":
            html_path = os.path.join(TEMPLATES_DIR, "index.html")
            if os.path.exists(html_path):
                with open(html_path, "rb") as f:
                    content = f.read()
                self.send_response(200)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.send_header("Content-Length", str(len(content)))
                self.send_header("Cache-Control", "no-cache")
                self.end_headers()
                self.wfile.write(content)
            else:
                self.send_response(404)
                self.end_headers()
                self.wfile.write(b"HTML template not found")
        elif self.path == "/api/stats":
            metrics = parser.collect_metrics()
            self.send_json(metrics)
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        content_length = int(self.headers.get("Content-Length", 0))
        post_data = self.rfile.read(content_length) if content_length > 0 else b"{}"
        
        try:
            payload = json.loads(post_data.decode("utf-8"))
        except Exception:
            payload = {}

        if self.path == "/api/config":
            saved = parser.save_config(payload)
            self.send_json({"status": "ok", "config": saved})
        elif self.path == "/api/hide":
            if _WINDOW_CONTROLLER and "hide" in _WINDOW_CONTROLLER:
                _WINDOW_CONTROLLER["hide"]()
            self.send_json({"status": "hidden"})
        elif self.path == "/api/show":
            if _WINDOW_CONTROLLER and "show" in _WINDOW_CONTROLLER:
                _WINDOW_CONTROLLER["show"]()
            self.send_json({"status": "shown"})
        elif self.path == "/api/toggle":
            if _WINDOW_CONTROLLER and "toggle" in _WINDOW_CONTROLLER:
                _WINDOW_CONTROLLER["toggle"]()
            self.send_json({"status": "toggled"})
        elif self.path == "/api/track":
            # Endpoint para rastrear chamadas manuais/externas de API do Gemini
            model = payload.get("model", "gemini-1.5-flash")
            tok_in = int(payload.get("tokens_in", 0))
            tok_out = int(payload.get("tokens_out", 0))
            source = payload.get("source", "gemini_api")
            cost = float(payload.get("cost_usd", 0.0))
            tracker.record_call(model=model, tokens_in=tok_in, tokens_out=tok_out, source=source, cost_usd=cost)
            self.send_json({"status": "recorded", "model": model, "tokens": tok_in + tok_out})
        else:
            self.send_response(404)
            self.end_headers()


def _background_collector_loop(interval: float = 4.0):
    """Thread em background que monitora os logs do Antigravity e atualiza stats.json continuamente."""
    while True:
        try:
            parser.collect_metrics()
        except Exception:
            pass
        time.sleep(interval)

class ThreadedHTTPServer(HTTPServer):
    allow_reuse_address = True

def start_server(port: int = 5678, daemon: bool = True) -> ThreadedHTTPServer:
    # Executa uma coleta inicial de métricas imediatamente
    try:
        parser.collect_metrics()
    except Exception:
        pass

    # Inicia thread contínua de monitoramento automático em background
    collector_t = threading.Thread(target=_background_collector_loop, args=(4.0,), daemon=True)
    collector_t.start()

    server_address = ("127.0.0.1", port)
    httpd = ThreadedHTTPServer(server_address, GeminiBurnHandler)
    if daemon:
        t = threading.Thread(target=httpd.serve_forever, daemon=True)
        t.start()
        return httpd
    else:
        httpd.serve_forever()
        return httpd
