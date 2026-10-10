#!/usr/bin/env python3
"""Локальный сервер тренажёра: отдаёт страницу и хранит прогресс в progress.json
(+ ежедневные копии в папке progress-backups, последние 30 дней)."""
import datetime
import http.server
import json
import os
import shutil

PORT = 8765
ROOT = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(ROOT, 'progress.json')
BACKUPS = os.path.join(ROOT, 'progress-backups')
ALLOWED_ORIGINS = {f'http://localhost:{PORT}', f'http://127.0.0.1:{PORT}'}


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def log_message(self, *args):
        pass

    def end_headers(self):
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()

    def do_GET(self):
        if self.path.startswith('/api/progress'):
            body = open(DATA, 'rb').read() if os.path.exists(DATA) else b'null'
            self.send_response(200)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        super().do_GET()

    def do_POST(self):
        if self.path != '/api/save':
            self.send_error(404)
            return
        # Сохранять прогресс может только сама страница тренажёра, а не чужие сайты
        if self.headers.get('Origin') not in ALLOWED_ORIGINS:
            self.send_error(403)
            return
        size = int(self.headers.get('Content-Length', 0))
        if size <= 0 or size > 5_000_000:
            self.send_error(413)
            return
        raw = self.rfile.read(size)
        try:
            data = json.loads(raw)
            assert isinstance(data, dict) and isinstance(data.get('xp'), (int, float))
        except Exception:
            self.send_error(400)
            return
        tmp = DATA + '.tmp'
        with open(tmp, 'wb') as f:
            f.write(raw)
        os.replace(tmp, DATA)
        os.makedirs(BACKUPS, exist_ok=True)
        shutil.copyfile(DATA, os.path.join(BACKUPS, datetime.date.today().isoformat() + '.json'))
        for old in sorted(os.listdir(BACKUPS))[:-30]:
            os.remove(os.path.join(BACKUPS, old))
        self.send_response(204)
        self.end_headers()


if __name__ == '__main__':
    http.server.ThreadingHTTPServer(('127.0.0.1', PORT), Handler).serve_forever()
